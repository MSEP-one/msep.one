extends InputHandlerCreateObjectBase


const MAX_MERGE_DISTANCE_SQUARED: float = 0.06 * 0.06
const AtomCandidate = AtomAutoposePreview.AtomCandidate


var _candidates_dirty: bool = true
var _element_selected: int = -1
var _candidates: Array[AtomCandidate] = []

# region virtual

## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return false


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(in_structure_context: StructureContext) -> bool:
	if in_structure_context.workspace_context.create_object_parameters.get_create_mode_type() \
				!= CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS:
		return false
	if in_structure_context.workspace_context.is_creating_object():
		# Make sure we abort creating shapes, motors, small molecules, etc
		in_structure_context.workspace_context.abort_creating_object()
	return in_structure_context.nano_structure is AtomicStructure


func handle_inputs_end() -> void:
	_hide_preview()


func handle_inputs_resume() -> void:
	if not _is_shortcut_pressed() or not _should_show():
		return
	if _candidates_dirty:
		_update_candidates()
	var rendering: Rendering = _get_rendering()
	rendering.atom_autopose_preview_show()


func handle_input_omission() -> void:
	_hide_preview()


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	in_context.current_structure_context_changed.connect(_on_current_structure_context_changed)
	in_context.create_object_parameters.new_atom_element_changed.connect(_on_new_atom_element_changed)
	in_context.create_object_parameters.new_bond_order_changed.connect(_on_new_bond_order_changed)
	in_context.create_object_parameters.create_distance_method_changed.connect(_on_create_distance_method_changed)
	in_context.create_object_parameters.creation_distance_from_camera_factor_changed.connect(_on_creation_distance_from_camera_factor_changed)
	_element_selected = in_context.create_object_parameters.get_new_atom_element()
	_get_rendering().atom_autopose_preview_set_atomic_number(_element_selected)
	var bond_order: int = in_context.create_object_parameters.get_new_bond_order()
	_get_rendering().atom_autopose_preview_set_bond_order(bond_order)
	# WorkspaceContext signals
	in_context.history_changed.connect(_on_workspace_context_history_changed)
	


func _on_current_structure_context_changed(in_context: StructureContext) -> void:
	if in_context == null or in_context.nano_structure == null:
		_hide_preview()


## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, out_context: StructureContext) -> bool:
	var rendering: Rendering = out_context.workspace_context.get_rendering()
	var is_shortcut_pressed: bool = _check_input_event_can_bind(in_input_event)
	if not is_shortcut_pressed and not _should_show():
		rendering.atom_autopose_preview_hide()
		return false
	
	if is_shortcut_pressed:
		_ensure_create_mode()
	
	update_preview_position()
	rendering.atom_autopose_preview_show()

	if not (in_input_event is InputEventMouseButton and 
			in_input_event.pressed and
			in_input_event.button_index == MOUSE_BUTTON_LEFT):
		return false
	
	var preview_atomic_number: int = get_workspace_context().create_object_parameters.get_new_atom_element()
	var cannot_create_because_hydrogen: bool = not out_context.nano_structure.are_hydrogens_visible() \
			and preview_atomic_number == PeriodicTable.ATOMIC_NUMBER_HYDROGEN
	if cannot_create_because_hydrogen:
		return true
	
	var hovered_candidate: AtomCandidate = rendering.atom_autopose_get_hovered_candidate_or_null()
	if hovered_candidate == null:
		return false
	
	var atom_pos: Vector3 = hovered_candidate.atom_position
	var element_to_create: int = _element_selected
	const CARBON: int = 6
	const NITROGEN: int = 7
	const OXIGEN: int = 8
	match hovered_candidate.atom_ids.size():
		1: # Whatever user selected
			element_to_create = _element_selected
		2: # Merging 2 candidates, use Oxygen
			element_to_create = OXIGEN
		3: # Merging 3 candidates, use Nitrogen
			element_to_create = NITROGEN
		4, _: # Merging 4 or more candidates, use Carbon
			element_to_create = CARBON
	var params := AtomicStructure.AddAtomParameters.new(element_to_create, atom_pos)
	var new_bond_order: int = out_context.workspace_context.create_object_parameters.get_new_bond_order()
	if hovered_candidate.atom_ids.size() > 1:
		# It's a merge candidate, use bond order 1
		new_bond_order = 1
	var _result: Dictionary = _do_create_atom_and_bonds(out_context, params, hovered_candidate.atom_ids, new_bond_order)
	_ensure_create_mode()
	_workspace_context.snapshot_moment("Add Atom")
	return true


func is_exclusive_input_consumer() -> bool:
	if _is_shortcut_pressed():
		return true
	var rendering: Rendering = get_workspace_context().get_rendering()
	return rendering.atom_autopose_get_hovered_candidate_or_null() != null


func set_preview_position(_in_position: Vector3) -> void:
	if _candidates_dirty:
		_update_candidates()
		_candidates_dirty = false


func _update_candidates() -> void:
	_candidates.clear()
	var selected_contexts: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
	for context: StructureContext in selected_contexts:
		var selected_atoms: PackedInt32Array = context.get_selected_atoms()
		var structure_candidates: Array[AtomCandidate] = []
		if selected_atoms.size() > 0:
			for atom_id in selected_atoms:
				var candidates_positions: PackedVector3Array = _generate_candidates_for_atom(context, atom_id)
				for pos: Vector3 in candidates_positions:
					var candidate := AtomCandidate.new()
					candidate.structrure_id = context.nano_structure.int_guid
					candidate.atom_ids = [atom_id]
					candidate.atom_position = pos
					structure_candidates.push_back(candidate)
			# Merge close atoms
			var visited: Array[int] = []
			for i: int in structure_candidates.size() - 1:
				if i in visited:
					continue
				var average_positions: Array[Vector3] = [structure_candidates[i].atom_position]
				for j: int in range(i+1, structure_candidates.size()):
					if structure_candidates[i].atom_position.distance_squared_to(
								structure_candidates[j].atom_position) < MAX_MERGE_DISTANCE_SQUARED:
						var other_atom_id: int = structure_candidates[j].atom_ids[0]
						structure_candidates[i].atom_ids.push_back(other_atom_id)
						average_positions.push_back(structure_candidates[j].atom_position)
						visited.push_back(j)
				if average_positions.size() > 1:
					var average := Vector3.ZERO
					for pos in average_positions:
						average += pos
					average /= average_positions.size()
					structure_candidates[i].atom_position = average
			visited.sort()
			# Remove candidates that was "merged"
			while visited.size():
				var merged_candidate_idx: int = visited.pop_back()
				structure_candidates.remove_at(merged_candidate_idx)
			_candidates.append_array(structure_candidates)
	_get_rendering().atom_autopose_preview_set_candidates(_candidates)


func _generate_candidates_for_atom(in_context: StructureContext, in_atom_id: int) -> PackedVector3Array:
	assert(in_context, "Invalid structure context")
	var nano_structure: NanoStructure = in_context.nano_structure
	assert(nano_structure, "Invalid structure")
	
	var candidate_positions: PackedVector3Array = []
	var atomic_number: int = nano_structure.atom_get_atomic_number(in_atom_id)
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
	var charge: int = _get_charge(nano_structure, in_atom_id)
	var stable_charge: int = _get_stable_charge(element_data)
	var delta_electrons: int = charge - stable_charge
	if delta_electrons > 0 and element_data.symbol in HAtomsEmptyValenceDirections.TABLE_OF_VALENCES.keys():
		# Add candidates
		var atom_position: Vector3 = nano_structure.atom_get_position(in_atom_id)
		var current_atom := HAtomsEmptyValenceDirections.Atom.new(atom_position, element_data.symbol)
		var known_bonds: PackedInt32Array = nano_structure.atom_get_bonds(in_atom_id)
		current_atom.valence = delta_electrons + known_bonds.size()
		var directions: PackedVector3Array = []
		match current_atom.valence:
			4:
				current_atom.geometry = HAtomsEmptyValenceDirections.Geometries.TETRA
			3:
				current_atom.geometry = HAtomsEmptyValenceDirections.Geometries.SP2
			_:
				current_atom.geometry = HAtomsEmptyValenceDirections.Geometries.SP1
		match known_bonds.size():
			0:
				directions = HAtomsEmptyValenceDirections.fill_valence_from_0(current_atom)
			1:
				var other_atom_id_1: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[0])
				var other_atom_pos_1: Vector3 = nano_structure.atom_get_position(other_atom_id_1)
				var known_1 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_1, "dummy")
				var torsion_candidate: HAtomsEmptyValenceDirections.Atom = _find_torsion_candidate(nano_structure,in_atom_id, [other_atom_id_1])
				directions = HAtomsEmptyValenceDirections.fill_valence_from_1(current_atom, known_1, torsion_candidate)
			2:
				var other_atom_id_1: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[0])
				var other_atom_pos_1: Vector3 = nano_structure.atom_get_position(other_atom_id_1)
				var known_1 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_1, "dummy")
				var other_atom_id_2: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[1])
				var other_atom_pos_2: Vector3 = nano_structure.atom_get_position(other_atom_id_2)
				var known_2 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_2, "dummy")
				var torsion_candidate: HAtomsEmptyValenceDirections.Atom = _find_torsion_candidate(nano_structure,in_atom_id, [other_atom_id_1, other_atom_id_2])
				directions = HAtomsEmptyValenceDirections.fill_valence_from_2(current_atom, known_1, known_2, torsion_candidate)
			3:
				var other_atom_id_1: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[0])
				var other_atom_pos_1: Vector3 = nano_structure.atom_get_position(other_atom_id_1)
				var known_1 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_1, "dummy")
				var other_atom_id_2: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[1])
				var other_atom_pos_2: Vector3 = nano_structure.atom_get_position(other_atom_id_2)
				var known_2 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_2, "dummy")
				var other_atom_id_3: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[2])
				var other_atom_pos_3: Vector3 = nano_structure.atom_get_position(other_atom_id_3)
				var known_3 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_3, "dummy")
				directions = HAtomsEmptyValenceDirections.fill_valence_from_3(current_atom, known_1, known_2, known_3)
		for dir in directions:
			var equilibrium_distance: float = _get_equilibrium_distance(atomic_number, _element_selected)
			var candidate_pos: Vector3 = atom_position + dir * equilibrium_distance
			candidate_positions.push_back(candidate_pos)
	return candidate_positions


func _get_charge(in_nano_structure: NanoStructure, in_atom_id: int) -> int:
	var charge: int = 0
	var bonds: PackedInt32Array = in_nano_structure.atom_get_bonds(in_atom_id)
	for bond_id in bonds:
		var order: int = in_nano_structure.get_bond(bond_id).z
		assert(order > 0, "In valid bond order")
		charge -= order
	return charge


func _get_stable_charge(in_element_data: ElementData) -> int:
	var valence: int = in_element_data.valence
	if in_element_data.number <= 5:
		# Special case for elements close to Helium
		return -(2 - valence)
	if valence <= 0:
		# FIXME: missing valence value
		return 0
	if valence < 4:
		return valence
	return valence - 8


func _find_torsion_candidate(nano_structure: NanoStructure, in_atom_id: int, other_atom_ids: PackedInt32Array) -> HAtomsEmptyValenceDirections.Atom:
	for other_atom_id in other_atom_ids:
		var bond_ids_of_other: PackedInt32Array = nano_structure.atom_get_bonds(other_atom_id)
		for bond in bond_ids_of_other:
			var candidate_id: int = nano_structure.atom_get_bond_target(other_atom_id, bond)
			if candidate_id != in_atom_id:
				var candidate_position: Vector3 = nano_structure.atom_get_position(candidate_id)
				var torsion_candidate := HAtomsEmptyValenceDirections.Atom.new(candidate_position, "dummy")
				return torsion_candidate
	return null


func _get_equilibrium_distance(in_atomic_number_a: int, in_atomic_number_b: int) -> float:
	var data_a: ElementData = PeriodicTable.get_by_atomic_number(in_atomic_number_a)
	var data_b: ElementData = data_a if in_atomic_number_a == in_atomic_number_b else \
								PeriodicTable.get_by_atomic_number(in_atomic_number_b)
	var equilibrium_distance: float = (data_a.contact_radius + data_b.contact_radius) * 0.5
	return equilibrium_distance


func _do_create_atom_and_bonds(out_context: StructureContext, in_atom_params: AtomicStructure.AddAtomParameters,
			in_bind_to_ids: PackedInt32Array, in_new_bond_order: int) -> Dictionary:
	out_context.nano_structure.start_edit()
	var new_atom_id: int = out_context.nano_structure.add_atom(in_atom_params)
	var new_bond_ids: PackedInt32Array = []
	for atom_to_bind: int in in_bind_to_ids:
		var new_bond_id: int = out_context.nano_structure.add_bond(atom_to_bind, new_atom_id, in_new_bond_order)
		new_bond_ids.push_back(new_bond_id)
	out_context.nano_structure.end_edit()
	out_context.select_atoms([new_atom_id])
	out_context.select_bonds(new_bond_ids)
	EditorSfx.create_object()
	return {"new_atom_id": new_atom_id, "new_bond_ids": new_bond_ids}


func _clear_selection_on_other_structures(out_context: StructureContext) -> void:
	for context in get_workspace_context().get_structure_contexts_with_selection():
		if context != out_context:
			context.clear_selection()


func _ensure_create_mode() -> void:
	var workspace_context: WorkspaceContext = get_workspace_context()
	workspace_context.create_object_parameters.set_create_mode_enabled(true)
	if workspace_context.create_object_parameters.get_create_mode_type() in [
				CreateObjectParameters.CreateModeType.CREATE_SHAPES,
				CreateObjectParameters.CreateModeType.CREATE_FRAGMENT
			]:
		workspace_context.create_object_parameters.set_create_mode_type(
			CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS)
		MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)


## Returns true if create mode is ON and the auto posing visualization is enabled.
## This setting is controlled from the visibility panel in the workspace docker.
func _should_show() -> bool:
	var parameters: CreateObjectParameters = _workspace_context.create_object_parameters
	if not parameters.get_create_mode_enabled():
		return false
	if parameters.get_create_mode_type() != CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS:
		return false
	return _workspace_context.workspace.representation_settings.get_display_auto_posing()


func _is_shortcut_pressed() -> bool:
	return (
		Input.is_key_pressed(KEY_ALT) and
		not Input.is_key_pressed(KEY_SHIFT) and
		not Input.is_key_pressed(KEY_CTRL) and
		not Input.is_key_pressed(KEY_META)
	)


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.ADD_ATOM_INPUT_HANDLER_PRIORITY


#region internal

func _on_new_atom_element_changed(in_element: int) -> void:
	_element_selected = in_element
	_get_rendering().atom_autopose_preview_set_atomic_number(in_element)


func _on_new_bond_order_changed(in_order: int) -> void:
	_get_rendering().atom_autopose_preview_set_bond_order(in_order)


func _on_create_distance_method_changed(_in_new_method: int) -> void:
	pass


func _on_creation_distance_from_camera_factor_changed(_in_distance_factor: float) -> void:
	pass


func _on_workspace_context_history_changed() -> void:
	_candidates_dirty = true


func _check_input_event_can_bind(in_event: InputEvent) -> bool:
	if not in_event is InputEventWithModifiers:
		return false
	var alt_pressed: bool = in_event.alt_pressed
	var ctrl_pressed: bool = in_event.ctrl_pressed
	var shift_pressed: bool = in_event.shift_pressed
	# Meta key does not work like the rest of the modifiers, so we fallback to Input API
	var meta_pressed: bool = Input.is_key_pressed(KEY_META)
	if in_event is InputEventKey:
		# Key inputs for an XXX button (in example shift) will have the ev.XXX_pressed property
		# set to false instead of whatever `ev.pressed` is, because of that we need aditional checks
		# for InputEventKey
		if in_event.keycode == KEY_ALT:
			alt_pressed = in_event.pressed
		if in_event.keycode == KEY_CTRL:
			ctrl_pressed = in_event.pressed
		if in_event.keycode == KEY_SHIFT:
			shift_pressed = in_event.pressed
		if in_event.keycode == KEY_META:
			meta_pressed = in_event.pressed
	return alt_pressed and not (shift_pressed || ctrl_pressed || meta_pressed)


func _hide_preview() -> void:
	_get_rendering().atom_autopose_preview_hide()


func _get_rendering() -> Rendering:
	return get_workspace_context().get_rendering()



	
