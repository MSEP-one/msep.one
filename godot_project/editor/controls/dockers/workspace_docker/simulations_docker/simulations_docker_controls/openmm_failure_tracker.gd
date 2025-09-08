class_name OpenMMFailureTracker extends Node

signal results_collected()

enum ErrorType {
	INVALID_VALENCE,
	UNKNOWN_VDW,
}


const _TREE_COLUMN_0 = 0


var _workspace_context: WorkspaceContext
var _alert_id_to_error_metadata: Dictionary[int, ErrorMetadata] = {} # Alert id : Metadata


func set_workspace_context(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context


func track_openmm_relax_request(in_request: RelaxRequest) -> void:
	in_request.retrying.connect(track_openmm_relax_request)
	assert(_workspace_context != null, "Attempted to track request without a WorkspaceContext assigned. Use set_workspace_context() first")
	await in_request.promise.wait_for_fulfill()
	in_request.retrying.disconnect(track_openmm_relax_request)
	if not in_request.promise.has_error():
		# wait for the animation of atoms flying to it's final position to finish
		var err_msg: String = await _workspace_context.atoms_relaxation_finished
		assert(err_msg.is_empty(), "Unnexpected error message '%s'" % err_msg)
		results_collected.emit()
		return
	_process_openmm_errors(in_request.promise, in_request.original_payload)


func track_openmm_simulation_request(in_simulation: SimulationData) -> void:
	assert(_workspace_context != null, "Attempted to track request without a WorkspaceContext assigned. Use set_workspace_context() first")
	await in_simulation.start_promise.wait_for_fulfill()
	if not in_simulation.start_promise.has_error():
		results_collected.emit()
		return
	_process_openmm_errors(in_simulation.start_promise, in_simulation.original_payload)


func process_relax_failure_alerts(in_request: RelaxRequest) -> void:
	_process_openmm_errors(in_request.promise, in_request.original_payload)


func _on_alert_selected(in_id: int) -> void:
	var meta: ErrorMetadata = _alert_id_to_error_metadata.get(in_id, null) as ErrorMetadata
	if meta == null:
		return
	meta.on_clicked(_workspace_context)


func _process_openmm_errors(in_promise: Promise, in_original_payload: OpenMMPayload) -> void:
	assert(in_promise.has_error(), "Relax Promise does not have errors")
	var error: String = _strip_bbcode(in_promise.get_error())
	var openff_to_zmq_atom_id: Dictionary = in_promise.get_meta(&"openff_to_zmq_atom_id", {})
	if error.findn("was not able to find parameters for the following valence terms") != -1:
		var parts: PackedStringArray = error.split("\n", false)
		parts.remove_at(0)
		for line: String in parts:
			if line.begins_with("- Topology indices"):
				_create_invalid_valence_item(in_original_payload, openff_to_zmq_atom_id, "Unable to find parameters for the following valence terms: " + line)
			elif line == "Traceback:":
				# End of OpenMM Errors, the rest is developers only useful information
				break
			else:
				assert(false, "Unhandled part: %s" % line)
				pass
	elif error.begins_with("float division by zero"):
		_workspace_context.push_error_alert(
				tr("A Mathematical operation prevented calculating molecule state (float division by zero)"))
	elif error.findn("has a net charge of") != -1:
		_workspace_context.push_error_alert(
				tr("Molecule has a net charge of an unexpected value"))
	elif error.begins_with("Too many rings open at once."):
		_workspace_context.push_error_alert(
				tr("Too many rings open at once. SMILES cannot be generated."))
	elif error.begins_with("Explicit valence for atom") and error.find(", is greater than permitted") != -1:
		for line: String in error.split("\n"):
			if not line.begins_with("Explicit valence for atom"):
				if line == "Traceback:":
					# End of OpenMM Errors, the rest is developers only useful information
					break
				else:
					continue
			_create_invalid_valence_item(in_original_payload, openff_to_zmq_atom_id, line, _extract_greater_valence_indices)
	elif error.begins_with("Invalid position for"):
		_workspace_context.push_error_alert(error)
	elif error.begins_with("TopologyKey with atom indices "):
		var header: String = error.split("\n")[0]
		_create_unknown_vdw_items(in_original_payload, openff_to_zmq_atom_id, header)
	elif error == OpenMM.OPENMM_CRASH_MESSAGE:
		pass
	else:
		assert(false, "Unhandled OpenMM Error: " + error)
		pass
	results_collected.emit()


func _strip_bbcode(in_text :String) -> String:
	var text: String = in_text.replace("\r\n", "\n")
	text = text.replacen("[b]", "")
	text = text.replacen("[/b]", "")
	return text


func _create_invalid_valence_item(in_original_payload: OpenMMPayload, in_openff_to_zmq_atom_id: Dictionary, in_line: String, in_extract_indices_callback: Callable = _extract_indices) -> void:
	var alert_id: int = _workspace_context.push_error_alert(in_line, _on_alert_selected)
	var openmm_atom_ids: PackedInt32Array = in_extract_indices_callback.call(in_line, in_openff_to_zmq_atom_id)
	assert(openmm_atom_ids.size() > 0)
	const FIRST_ATOM = 0
	const STRUCTURE_ID_DATA = 0
	const MSEP_ATOM_ID_DATA = 1
	var data_map: Dictionary = in_original_payload.request_atom_id_to_structure_and_atom_id_map
	# {	request_atom_id: int = [structure_int_guid: int, atom_id: int] }
	var structure_id: int = data_map[openmm_atom_ids[FIRST_ATOM]][STRUCTURE_ID_DATA]
	var msep_atom_ids: PackedInt32Array = []
	for openmm_id: int in openmm_atom_ids:
		if in_original_payload.passivate_molecules and openmm_id >= in_original_payload.atoms_count:
			# Error related to a ghost hydrogen added for passivation
			continue
		assert(openmm_id in data_map, "Unknown atom id %d" % openmm_id)
		var atom_data: Array = data_map[openmm_id]
		assert(structure_id == atom_data[STRUCTURE_ID_DATA])
		msep_atom_ids.push_back(atom_data[MSEP_ATOM_ID_DATA])
	
	_alert_id_to_error_metadata[alert_id] = InvalidValenceMetadata.new(structure_id, msep_atom_ids, [])


func _create_unknown_vdw_items(in_original_payload: OpenMMPayload, in_openff_to_zmq_atom_id: Dictionary, in_line: String, in_extract_indices_callback: Callable = _extract_indices) -> void:
	var openmm_atom_ids: PackedInt32Array = in_extract_indices_callback.call(in_line, in_openff_to_zmq_atom_id)
	assert(openmm_atom_ids.size() > 0)
	const FIRST_ATOM = 0
	const STRUCTURE_ID_DATA = 0
	const MSEP_ATOM_ID_DATA = 1
	var data_map: Dictionary[int, PackedInt32Array] = in_original_payload.request_atom_id_to_structure_and_atom_id_map
	# {	request_atom_id: int = [structure_int_guid: int, atom_id: int] }
	var structure_id: int = data_map[openmm_atom_ids[FIRST_ATOM]][STRUCTURE_ID_DATA]
	var workspaces: Array[Workspace] = MolecularEditorContext.find_workspaces_possessing_structure_id(structure_id)
	assert(workspaces.size() > 0)
	var workspace: Workspace = workspaces[0]
	if workspaces.size() > 1:
		# More than 1 workspace shares strusture ID, likely because the same file was open more than once.
		# Let's try to fallback to active workspace
		var active: Workspace = MolecularEditorContext.get_current_workspace()
		assert(active in workspaces)
		workspace = active
	var structure: AtomicStructure = workspace.get_structure_by_int_guid(structure_id)
	assert(structure, "Workspace contains structure with id %d, but seems to not be an AtomicStructure")
	var msep_atom_ids_per_element: Dictionary[int, PackedInt32Array]
	for openmm_id: int in openmm_atom_ids:
		if in_original_payload.passivate_molecules and openmm_id >= in_original_payload.atoms_count:
			# Error related to a ghost hydrogen added for passivation
			continue
		assert(openmm_id in data_map, "Unknown atom id %d" % openmm_id)
		var atom_data: Array = data_map[openmm_id]
		assert(structure_id == atom_data[STRUCTURE_ID_DATA])
		var msep_atom_id: int = atom_data[MSEP_ATOM_ID_DATA]
		var atomic_number: int = structure.atom_get_atomic_number(msep_atom_id)
		if not atomic_number in msep_atom_ids_per_element.keys():
			msep_atom_ids_per_element[atomic_number] = PackedInt32Array()
		msep_atom_ids_per_element[atomic_number].push_back(msep_atom_id)
	for atomic_number: int in msep_atom_ids_per_element.keys():
		var atom_ids: PackedInt32Array = msep_atom_ids_per_element[atomic_number]
		var symbol: String = PeriodicTable.get_by_atomic_number(atomic_number).symbol
		var count: int = atom_ids.size()
		var error_desc: String = "OpenFF has unknown Van der Waals parameters for %d particle(s) of element %s"
		error_desc = error_desc % [count, symbol]
		var alert_id: int = _workspace_context.push_error_alert(error_desc, _on_alert_selected)
		_alert_id_to_error_metadata[alert_id] = UnknownVdWParametterMetadata.new(structure_id, atom_ids)


func _extract_indices(in_line: String, in_openff_to_zmq_atom_id: Dictionary) -> PackedInt32Array:
	var result: PackedInt32Array = []
	var start: int = in_line.find("(") + 1
	var end: int = in_line.find(")")
	assert(end > start and start > 0, "could not extract atom indices from line '%s'" % in_line)
	var list: String = in_line.substr(start, end-start)
	for numb: float in list.split_floats(", ", false):
		var atom_id: int = in_openff_to_zmq_atom_id.get(int(numb),int(numb))
		result.push_back(atom_id)
	return result


func _extract_greater_valence_indices(in_line: String, in_openff_to_zmq_atom_id: Dictionary) -> PackedInt32Array:
	var result: PackedInt32Array = []
	var start: int = in_line.find("atom # ") + 7
	var end: int = in_line.find(" ", start)
	assert(end > start and start > 0, "could not extract atom indices from line '%s'" % in_line)
	var list: String = in_line.substr(start, end-start)
	for numb: float in list.split_floats(", ", false):
		var atom_id: int = in_openff_to_zmq_atom_id.get(int(numb),int(numb))
		result.push_back(atom_id)
	return result


class ErrorMetadata:
	var type: ErrorType
	var structure_int_guid: int
	var atom_ids: PackedInt32Array
	var bond_ids: PackedInt32Array
	
	func on_clicked(_out_workspace_context: WorkspaceContext) -> void:
		assert(false, "Override this method")
		# pass is needed because assert is stripped out on Release builds
		pass


class InvalidValenceMetadata extends ErrorMetadata:
	func _init(
			in_structure_id: int,
			in_atom_ids: PackedInt32Array,
			in_bond_ids: PackedInt32Array) -> void:
		type = ErrorType.INVALID_VALENCE
		structure_int_guid = in_structure_id
		atom_ids = in_atom_ids
		bond_ids = in_bond_ids
	
	func on_clicked(out_workspace_context: WorkspaceContext) -> void:
		var selection: PackedInt32Array = atom_ids
		
		var structure: NanoStructure = out_workspace_context.workspace.get_structure_by_int_guid(structure_int_guid)
		assert(structure != null)
		var structure_context: StructureContext = out_workspace_context.get_nano_structure_context(structure)
		if structure_context != out_workspace_context.get_current_structure_context():
			out_workspace_context.change_current_structure_context(structure_context)
		for context in out_workspace_context.get_structure_contexts_with_selection():
			context.clear_selection()
		
		structure_context.select_atoms_and_get_auto_selected_bonds(selection)

		var focus_aabb: AABB = WorkspaceUtils.get_selected_objects_aabb(out_workspace_context)
		WorkspaceUtils.focus_camera_on_aabb(out_workspace_context, focus_aabb)
		out_workspace_context.snapshot_moment("Select Atoms")

class UnknownVdWParametterMetadata extends ErrorMetadata:
	func _init(
			in_structure_id: int,
			in_atom_ids: PackedInt32Array) -> void:
		type = ErrorType.UNKNOWN_VDW
		structure_int_guid = in_structure_id
		atom_ids = in_atom_ids
	
	func on_clicked(out_workspace_context: WorkspaceContext) -> void:
		var selection: PackedInt32Array = atom_ids
		
		var structure: NanoStructure = out_workspace_context.workspace.get_structure_by_int_guid(structure_int_guid)
		assert(structure != null)
		var structure_context: StructureContext = out_workspace_context.get_nano_structure_context(structure)
		if structure_context != out_workspace_context.get_current_structure_context():
			out_workspace_context.change_current_structure_context(structure_context)
		for context in out_workspace_context.get_structure_contexts_with_selection():
			context.clear_selection()
		
		structure_context.select_atoms(selection)

		var focus_aabb: AABB = WorkspaceUtils.get_selected_objects_aabb(out_workspace_context)
		WorkspaceUtils.focus_camera_on_aabb(out_workspace_context, focus_aabb)
		out_workspace_context.snapshot_moment("Select Atoms")
