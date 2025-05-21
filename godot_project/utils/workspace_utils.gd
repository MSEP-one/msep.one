class_name WorkspaceUtils


const OpenmmWarningDialog = preload("res://autoloads/openmm/alert_controls/openmm_alert_dialog.tscn")


static func invert_selection(out_workspace_context: WorkspaceContext) -> void:
	_invert_selection(out_workspace_context)


static func select_all(out_workspace_context: WorkspaceContext) -> void:
	_select_all(out_workspace_context)


static func deselect_all(out_workspace_context: WorkspaceContext) -> void:
	_deselect_all(out_workspace_context)


static func select_by_type(out_workspace_context: WorkspaceContext, types: PackedInt32Array) -> void:
	_select_by_type(out_workspace_context, types)


static func select_connected(out_workspace_context: WorkspaceContext, in_show_hidden_objects: bool = false) -> void:
	_select_connected(out_workspace_context, in_show_hidden_objects)


static func grow_selection(out_workspace_context: WorkspaceContext) -> void:
	_grow_selection(out_workspace_context)


static func shrink_selection(out_workspace_context: WorkspaceContext) -> void:
	_shrink_selection(out_workspace_context)


static func move_selection_to_new_structure(out_workspace_context: WorkspaceContext, in_parent_structure_id: int, in_new_group_name: String) -> void:
	_move_selection_to_new_structure(out_workspace_context, in_parent_structure_id, in_new_group_name)


static func move_selection_to_existing_structure(out_workspace_context: WorkspaceContext, in_target_structure_id: int) -> void:
	_move_selection_to_existing_structure(out_workspace_context, in_target_structure_id)


static func set_selected_atoms_locked(out_workspace_context: WorkspaceContext, in_atoms_are_locked: bool) -> void:
	_set_selected_atoms_locked(out_workspace_context, in_atoms_are_locked)

static func get_visible_objects_aabb(out_workspace_context: WorkspaceContext) -> AABB:
	return _get_visible_objects_aabb(out_workspace_context)


static func get_selected_objects_aabb(out_workspace_context: WorkspaceContext) -> AABB:
	return _get_selected_objects_aabb(out_workspace_context)


static func focus_camera_on_aabb(out_workspace_context: WorkspaceContext, in_focus_aabb: AABB) -> void:
	_focus_camera_on_aabb(out_workspace_context, in_focus_aabb)


static func move_camera_outside_of_aabb(out_workspace_context: WorkspaceContext, aabb: AABB) -> void:
	_move_camera_outside_of_aabb(out_workspace_context, aabb)


static func unpack_mol_file_and_get_path(fragment_path: String) -> String:
	return _unpack_mol_file_and_get_path(fragment_path)


static func import_file(out_workspace_context: WorkspaceContext, path: String,
						generate_bonds: bool, add_hydrogens: bool, remove_waters: bool,
						placement: ImportFileDialog.Placement, create_new_group: bool = true,
						snapshot_name: String = "Import File") -> void:
	if _is_msep_workspace(path):
		_import_msep_workspace(out_workspace_context, path, placement, snapshot_name)
		return
	if _is_xyz_file(path):
		_import_xyz_file(out_workspace_context, path, placement, create_new_group, generate_bonds, snapshot_name)
		return
	if _is_invalid_mol_file(path):
		Editor_Utils.get_editor().prompt_error_msg(
			("Cannot load file '%s'\n" % path) +
			"mol file was saved with V3000 specification, which is unsupported."
		)
		return
	var import_file_result: OpenMMClass.ImportFileResult
	import_file_result = await _import_file(out_workspace_context, path, generate_bonds, add_hydrogens, remove_waters)
	if import_file_result == null:
		# Failed to import file. Error is handled internally
		return
	if create_new_group:
		_load_import_file_result_to_new_group(out_workspace_context, import_file_result, placement, snapshot_name)
	else:
		_load_import_file_result(out_workspace_context, import_file_result, placement, snapshot_name)


static func get_nano_structure_from_file(workspace_context: WorkspaceContext, path: String,
				generate_bonds: bool, add_hydrogens: bool, remove_waters: bool) -> NanoStructure:
	var import_file_result: OpenMMClass.ImportFileResult
	import_file_result = await _import_file(workspace_context, path, generate_bonds, add_hydrogens, remove_waters)
	return _import_file_result_to_structure(import_file_result)


static func open_screen_capture_dialog(in_workspace_context: WorkspaceContext) -> void:
	_open_screen_capture_dialog(in_workspace_context)


static func open_camera_position_dialog() -> void:
	Editor_Utils.get_editor().camera_position_dialog.popup_centered()


static func open_quick_search_dialog(in_workspace_context: WorkspaceContext) -> void:
	_open_quick_search_dialog(in_workspace_context)


static func apply_simulation_state(
		out_workspace_context: WorkspaceContext,
		in_payload: OpenMMPayload,
		in_positions: PackedVector3Array) -> void:
	_apply_simulation_state(out_workspace_context, in_payload, in_positions)


static func can_relax(in_workspace_context: WorkspaceContext, in_selection_only: bool) -> bool:
	if in_selection_only:
		return _can_relax_selection(in_workspace_context)
	return _can_relax_all(in_workspace_context)


static func can_move_selection_to_another_group(in_workspace_context: WorkspaceContext) -> bool:
	return _can_move_selection_to_another_group(in_workspace_context)


static func has_invalid_tetrahedral_structure(in_workspace_context: WorkspaceContext, in_selection_only: bool) -> bool:
	assert(can_relax(in_workspace_context, in_selection_only))
	return _has_bad_tetrahedral_angle(in_workspace_context, in_selection_only)


static func structure_context_has_drastically_invalid_tetrahedral_structure(in_structure_context: StructureContext, in_atoms: PackedInt32Array) -> bool:
	if not in_structure_context.nano_structure is AtomicStructure:
		return false
	return _structure_context_has_drastically_invalid_tetrahedral_structure(in_structure_context, in_atoms)


static func _has_bad_tetrahedral_angle(in_workspace_context: WorkspaceContext, in_selection_only: bool) -> bool:
	var structure_contexts: Array[StructureContext] = in_workspace_context.get_visible_structure_contexts()
	for structure_ctx: StructureContext in structure_contexts:
		var structure: AtomicStructure = structure_ctx.nano_structure as AtomicStructure
		if not is_instance_valid(structure):
			# not atomic structure, is a virtual object
			continue
		var atom_ids: PackedInt32Array = []
		if in_selection_only:
			atom_ids = structure_ctx.get_selected_atoms()
		else:
			atom_ids = structure.get_valid_atoms()
		if _structure_context_has_drastically_invalid_tetrahedral_structure(structure_ctx, atom_ids):
			return true
	return false


static func _structure_context_has_drastically_invalid_tetrahedral_structure(
		in_structure_context: StructureContext, in_atoms: PackedInt32Array) -> bool:
	var structure: NanoStructure = in_structure_context.nano_structure
	for atom_id: int in in_atoms:
		var bond_ids: PackedInt32Array = structure.atom_get_bonds(atom_id)
		if bond_ids.size() != 4:
			continue
		var atom_pos: Vector3 = structure.atom_get_position(atom_id)
		var other_atom_positions: PackedVector3Array = []
		for bond_id: int in bond_ids:
			var other_atom_id: int = structure.atom_get_bond_target(atom_id, bond_id)
			other_atom_positions.push_back(structure.atom_get_position(other_atom_id))
		# Make a plane with 3 of the known atoms
		var plane := Plane(other_atom_positions[0], other_atom_positions[1], other_atom_positions[2])
		if plane.has_point(other_atom_positions[3]):
			# All atoms are in the same plane
			return true
		var dir_to_plane: Vector3 = _find_plane_normal_away_from_atom(plane, atom_pos, other_atom_positions[3])
		var dir_to_last: Vector3 = atom_pos.direction_to(other_atom_positions[3])
		const EXPECTED_DOT_PRODUCT = -0.8
		var dot: float =  dir_to_plane.dot(dir_to_last)
		if dot > EXPECTED_DOT_PRODUCT:
			# A tetrahedrum is a 3 sided piramid. taken any of it's sides composed by 3 of 4 of it's
			# vertexes, the last one is meant to be pointing in the oposite direction to the normal of this plane
			return true
	return false


static func collect_drastically_invalid_tetrahedral_structure(
		in_visible_strucutre_contexts: Array[StructureContext],
		in_selection_only: bool) -> Array[Dictionary]:
	var out_bad_tetrahedral_groups: Array[Dictionary] = [
	#	{
	#		structure_context = StructureContext
	#		atoms_ids = PackedInt32Array[mid_atom, ...],
	#		bond_ids = PackedInt32Array[...],
	#	}, ...
	]
	for structure_ctx: StructureContext in in_visible_strucutre_contexts:
		var structure: AtomicStructure = structure_ctx.nano_structure as AtomicStructure
		if not is_instance_valid(structure):
			# not atomic structure, is a virtual object
			continue
		var atom_ids: PackedInt32Array = []
		if in_selection_only:
			atom_ids = structure_ctx.get_selected_atoms()
		else:
			atom_ids = structure.get_valid_atoms()
		_collect_drastically_invalid_tetrahedral_structure(structure_ctx, atom_ids, out_bad_tetrahedral_groups)
	return out_bad_tetrahedral_groups


static func _collect_drastically_invalid_tetrahedral_structure(
		in_structure_context: StructureContext, in_atoms: PackedInt32Array,
		out_bad_tetrahedral_groups: Array[Dictionary]) -> void:
	var structure: NanoStructure = in_structure_context.nano_structure
	var atom_group_is_invalid: bool = false
	for atom_id: int in in_atoms:
		var bond_ids: PackedInt32Array = structure.atom_get_bonds(atom_id)
		if bond_ids.size() != 4:
			continue
		atom_group_is_invalid = false
		var atom_pos: Vector3 = structure.atom_get_position(atom_id)
		var atom_ids: PackedInt32Array = [atom_id]
		var other_atom_positions: PackedVector3Array = []
		for bond_id: int in bond_ids:
			var other_atom_id: int = structure.atom_get_bond_target(atom_id, bond_id)
			atom_ids.push_back(other_atom_id)
			other_atom_positions.push_back(structure.atom_get_position(other_atom_id))
		# Make a plane with 3 of the known atoms
		var plane := Plane(other_atom_positions[0], other_atom_positions[1], other_atom_positions[2])
		if plane.has_point(other_atom_positions[3]):
			# All atoms are in the same plane
			atom_group_is_invalid = true
		else:
			var dir_to_plane: Vector3 = _find_plane_normal_away_from_atom(plane, atom_pos, other_atom_positions[3])
			var dir_to_last: Vector3 = atom_pos.direction_to(other_atom_positions[3])
			const EXPECTED_DOT_PRODUCT = -0.8
			var dot: float =  dir_to_plane.dot(dir_to_last)
			if dot > EXPECTED_DOT_PRODUCT:
				atom_group_is_invalid = true
		if atom_group_is_invalid:
			out_bad_tetrahedral_groups.push_back({
				structure_context = in_structure_context,
				atoms_ids = atom_ids,
				bond_ids = bond_ids,
			})


static func _find_plane_normal_away_from_atom(in_plane: Plane, in_atom_pos: Vector3, in_other_atom_pos: Vector3) -> Vector3:
	var atom_projected: Vector3 = in_plane.project(in_atom_pos)
	if atom_projected == in_atom_pos:
		# atom is basically overlapping the plane, so let's return the oposite direction
		# to the other atom to be safe
		return -in_atom_pos.direction_to(in_other_atom_pos)
	return in_atom_pos.direction_to(atom_projected)


static func collect_invalid_bond_angles(in_visible_strucutre_contexts: Array[StructureContext],
		in_selection_only: bool) -> Array[Dictionary]:
	var out_invalid_angle_atom_groups: Array[Dictionary] = [
	#	{
	#		type = StringName [ &"sp1" | &"sp2" | &"sp3" ]
	#		structure_context = StructureContext
	#		atoms_ids = PackedInt32Array[mid_atom, ...],
	#		bond_ids = PackedInt32Array[...],
	#	}, ...
	]
	for context: StructureContext in in_visible_strucutre_contexts:
		if context.nano_structure is AtomicStructure:
			_collect_invalid_bond_angles_atom_groups(context, in_selection_only, out_invalid_angle_atom_groups)
	return out_invalid_angle_atom_groups


static func _collect_invalid_bond_angles_atom_groups(
		in_structure_context: StructureContext, in_selection_only: bool,
		out_invalid_angle_atom_groups: Array[Dictionary]) -> void:
	var structure: NanoStructure = in_structure_context.nano_structure
	var atom_ids: PackedInt32Array = []
	const GROUP_TYPES_FROM_BOND_COUNT: Dictionary = {
		2 : &"sp1",
		3 : &"sp2",
		4 : &"sp3",
	}
	const MIN_ACCEPTABLE_ANGLE: Dictionary = {
		sp1 = 55.0,
		sp2 = 55.0,
		sp3 = 55.0,
	}
	const MAX_ACCEPTABLE_ANGLE: Dictionary = {
		sp1 = 170.0,
		sp2 = 170.0,
		sp3 = 170.0,
	}
	if in_selection_only:
		atom_ids = in_structure_context.get_selected_atoms()
	else:
		atom_ids = structure.get_valid_atoms()
	for atom_id: int in atom_ids:
		var bond_ids: PackedInt32Array = structure.atom_get_bonds(atom_id)
		if not bond_ids.size() in GROUP_TYPES_FROM_BOND_COUNT.keys():
			continue
		var group_type: StringName = GROUP_TYPES_FROM_BOND_COUNT[bond_ids.size()]
		var min_acceptable_angle: float = MIN_ACCEPTABLE_ANGLE[group_type]
		var max_acceptable_angle: float = MAX_ACCEPTABLE_ANGLE[group_type]
		var atoms_ids: PackedInt32Array = [atom_id]
		var bond_vectors: PackedVector3Array = []
		var bond_begin: Vector3 = structure.atom_get_position(atom_id)
		for bond_id: int in bond_ids:
			var other_atom_id: int = structure.atom_get_bond_target(atom_id, bond_id)
			var bond_end: Vector3 = structure.atom_get_position(other_atom_id)
			bond_vectors.push_back(bond_end - bond_begin)
			atoms_ids.push_back(other_atom_id)
		var found: bool = false
		for i: int in bond_ids.size() - 1:
			for j: int in range(i+1, bond_ids.size()):
				var angle_deg: float = rad_to_deg(bond_vectors[i].angle_to(bond_vectors[j]))
				if angle_deg < min_acceptable_angle or angle_deg > max_acceptable_angle:
					# at least one angle out of range
					found = true
					break
			if found:
				break
		if found:
			var group: Dictionary = {
				type = group_type,
				structure_context = in_structure_context,
				atoms_ids = atoms_ids,
				bond_ids = bond_ids,
			}
			out_invalid_angle_atom_groups.push_back(group)
	return


static func relax(out_workspace_context: WorkspaceContext, in_temperature_in_kelvins: float,
			in_selection_only: bool,in_include_springs: bool, in_lock_atoms: bool,
			in_passivate_molecules: bool) -> RelaxRequest:
	return _relax(out_workspace_context, in_temperature_in_kelvins, in_selection_only, in_include_springs,
		in_lock_atoms, in_passivate_molecules, true)


static func forward_event(out_workspace_context: WorkspaceContext, event: InputEvent) -> void:
	_forward_event(out_workspace_context, event)


static func hide_selected_objects(out_workspace_context: WorkspaceContext) -> void:
	var structures_with_selection: Array[StructureContext] = out_workspace_context.get_structure_contexts_with_selection()
	if structures_with_selection.is_empty():
		return
	
	for structure_context: StructureContext in structures_with_selection:
		if structure_context.is_shape_selected():
			structure_context.set_shape_selected(false)
			structure_context.nano_structure.set_visible(false)
		elif structure_context.is_motor_selected():
			structure_context.set_motor_selected(false)
			structure_context.nano_structure.set_visible(false)
		elif structure_context.is_anchor_selected():
			var workspace: Workspace = out_workspace_context.workspace
			var nano_anchor: NanoVirtualAnchor = structure_context.nano_structure as NanoVirtualAnchor
			var related_structures: PackedInt32Array = nano_anchor.get_related_structures()
			for spring_structure_id: int in related_structures:
				var springs_to_hide: PackedInt32Array = nano_anchor.get_related_springs(spring_structure_id)
				var atomic_structure: AtomicStructure = workspace.get_structure_by_int_guid(spring_structure_id)
				atomic_structure.set_springs_visibility(springs_to_hide, false)
			structure_context.set_anchor_selected(false)
			structure_context.nano_structure.set_visible(false)
		elif structure_context.nano_structure is AtomicStructure:
			var selected_atoms: PackedInt32Array = structure_context.get_selected_atoms()
			var selected_bonds: PackedInt32Array = structure_context.get_selected_bonds()
			var selected_springs: PackedInt32Array = structure_context.get_selected_springs()
			structure_context.clear_selection()
			structure_context.set_atoms_visibility(selected_atoms, false)
			structure_context.set_bonds_visibility(selected_bonds, false)
			structure_context.set_springs_visibility(selected_springs, false)
	
	out_workspace_context.notify_object_visibility_changed()
	out_workspace_context.snapshot_moment("Hide Selected Objects")


static func show_hidden_objects(out_workspace_context: WorkspaceContext) -> void:
	var hidden_structures: Array[StructureContext] = out_workspace_context.get_structure_contexts_with_hidden_objects()
	if hidden_structures.is_empty():
		return
	
	for structure_context: StructureContext in hidden_structures:
		var nano_structure: NanoStructure = structure_context.nano_structure
		if nano_structure.is_virtual_object():
			structure_context.nano_structure.set_visible(true)
		else:
			var hidden_atoms: PackedInt32Array = structure_context.get_hidden_atoms()
			var hidden_bonds: PackedInt32Array = structure_context.get_hidden_bonds()
			var hidden_springs: PackedInt32Array = structure_context.get_hidden_springs()
			structure_context.set_atoms_visibility(hidden_atoms, true)
			structure_context.set_bonds_visibility(hidden_bonds, true)
			structure_context.set_springs_visibility(hidden_springs, true)
	
	out_workspace_context.notify_object_visibility_changed()
	out_workspace_context.snapshot_moment("Show Hidden Objects")


static func _invert_selection(out_workspace_context: WorkspaceContext) -> void:
	for structure_context: StructureContext in out_workspace_context.get_editable_structure_contexts():
		structure_context.invert_selection()
	out_workspace_context.snapshot_moment("Invert Selection")


static func _select_all(out_workspace_context: WorkspaceContext) -> void:
	for structure_context: StructureContext in out_workspace_context.get_editable_structure_contexts():
		structure_context.select_all()
	out_workspace_context.snapshot_moment("Select All")


static func _deselect_all(out_workspace_context: WorkspaceContext) -> void:
	var all_structures: Array[StructureContext] = out_workspace_context.get_visible_structure_contexts()
	var changed: bool = false
	for current_structure in all_structures:
		if current_structure.has_selection():
			current_structure.clear_selection()
			changed = true
	if changed:
		out_workspace_context.snapshot_moment("Deselect All")


static func _select_by_type(out_workspace_context: WorkspaceContext, types: PackedInt32Array) -> void:
	
	# Make hydrogens visible if trying to select them but are currently hidden.
	if types.has(PeriodicTable.ATOMIC_NUMBER_HYDROGEN) and not out_workspace_context.are_hydrogens_visualized():
		out_workspace_context.enable_hydrogens_visualization()
	
	for struct_context: StructureContext in out_workspace_context.get_editable_structure_contexts():
		struct_context.select_by_type(types)
	out_workspace_context.snapshot_moment("Select Atoms by Type")


static func _select_connected(out_workspace_context: WorkspaceContext, in_show_hidden_objects: bool) -> void:
	var all_structures: Array[StructureContext] = out_workspace_context.get_structure_contexts_with_selection()
	for struct_context in all_structures:
		struct_context.select_connected(in_show_hidden_objects)
	out_workspace_context.snapshot_moment("Select Connected Atoms")


static func _grow_selection(out_workspace_context: WorkspaceContext) -> void:
	var all_structures: Array[StructureContext] = out_workspace_context.get_structure_contexts_with_selection()
	for struct_context in all_structures:
		struct_context.grow_selection()
	out_workspace_context.snapshot_moment("Grow Selection")


static func _shrink_selection(out_workspace_context: WorkspaceContext) -> void:
	var all_structures: Array[StructureContext] = out_workspace_context.get_structure_contexts_with_selection()
	for struct_context in all_structures:
		struct_context.shrink_selection()
	out_workspace_context.snapshot_moment("Shrink Selection")


static func _move_selection_to_new_structure(out_workspace_context: WorkspaceContext, in_parent_structure_id: int, in_new_group_name: String) -> void:
	assert(_can_move_selection_to_another_group(out_workspace_context), "Moving atoms and bonds from one group to another requires molecules to be entirely selected")
	assert(in_parent_structure_id == 0 or out_workspace_context.workspace.has_structure_with_int_guid(in_parent_structure_id),
		"Invalid parent ID")
	assert(not in_new_group_name.is_empty(), "Invalid empty group name")
	var parent_structure: NanoStructure = null
	if in_parent_structure_id != 0:
		parent_structure = out_workspace_context.workspace.get_structure_by_int_guid(in_parent_structure_id)
	var structure := AtomicStructure.create()
	structure.set_structure_name(in_new_group_name)
	var out_did_create_undo_action: Dictionary = {
		value = false # Using a dictionary to capture it by reference in the callable
	}
	out_workspace_context.workspace.add_structure(structure, parent_structure)
	var structure_context: StructureContext = out_workspace_context.get_nano_structure_context(structure)
	_start_editing_if_needed(out_did_create_undo_action, structure_context)
	const DONT_COMMIT_WHEN_DONE = false
	# In order to maintain the right order of execusion, we need to remove the structure from workspace after
	# The selection snapshot is applied, in order to do this we pass `commit_when_done=false`
	# so we can add remove_structure as undo_method before commiting
	_move_selection_to_existing_structure(out_workspace_context, structure.int_guid, out_did_create_undo_action, DONT_COMMIT_WHEN_DONE)
	out_workspace_context.snapshot_moment("Move selection to new group")


static func _move_selection_to_existing_structure(
			out_workspace_context: WorkspaceContext,
			in_target_structure_id: int,
			out_did_create_undo_action: Dictionary = {
				value = false # Using a dictionary to capture it by reference in the callable
			},
			commit_when_done: bool = true) -> void:
	assert(_can_move_selection_to_another_group(out_workspace_context), "Moving atoms and bonds from one group to another requires molecules to be entirely seected")
	var workspace: Workspace = out_workspace_context.workspace
	assert(out_workspace_context.workspace.has_structure_with_int_guid(in_target_structure_id), "Invalid structure ID")
	var target_structure: AtomicStructure = out_workspace_context.workspace.get_structure_by_int_guid(in_target_structure_id) as AtomicStructure
	assert(is_instance_valid(target_structure), "Workspace has id, but structure instance is invalid")
	var target_structure_context: StructureContext = out_workspace_context.get_nano_structure_context(target_structure)
	var new_atoms_to_select_when_done: PackedInt32Array = []
	var selected_structure_contexts: Array[StructureContext] = out_workspace_context.get_selected_structure_contexts_child_of_current_structure()
	if out_workspace_context.get_current_structure_context() != null and out_workspace_context.get_current_structure_context().has_selection():
		# Add currently active object to the mix of contexts:
		selected_structure_contexts.append(out_workspace_context.get_current_structure_context())
	for structure_context: StructureContext in selected_structure_contexts:
		if structure_context.nano_structure == target_structure:
			# contents don't need to change
			continue
		elif structure_context != out_workspace_context.get_current_structure_context():
			_start_editing_if_needed(out_did_create_undo_action, target_structure_context)
			var previous_parent: NanoStructure = workspace.get_parent_structure(structure_context.nano_structure)
			if previous_parent == target_structure:
				# no need to reparent
				continue
			workspace.reparent_structure(structure_context.nano_structure, target_structure)
		else:
			_start_editing_if_needed(out_did_create_undo_action, target_structure_context)
			var old_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
			var source_structure_atoms_ids: PackedInt32Array = structure_context.get_selected_atoms()
			var source_structure_bonds_ids: PackedInt32Array = structure_context.get_selected_bonds()
			var source_structure_springs_ids: PackedInt32Array = PackedInt32Array()
			var old_color_overrides: Dictionary = old_structure.get_color_overrides()
			var new_color_overrides: Dictionary = {
			#	color<Color> = atoms_to_apply<PackedInt32Array>
			}
			
			for atom_id: int in source_structure_atoms_ids:
				source_structure_springs_ids.append_array(old_structure.atom_get_springs(atom_id))
			
			var destination_structure_atoms_ids: PackedInt32Array = []
			var destination_structure_bonds_ids: PackedInt32Array = []
			var destination_structure_springs_ids: PackedInt32Array = []
			var source_to_dest_atoms_ids: Dictionary = {
#				src_atom_id<int> = dst_atom_id<int>
			}
			structure_context.clear_selection()
			old_structure.start_edit()
			# 1. Copy atoms from src to dst
			for old_atom_id: int in source_structure_atoms_ids:
				var atomic_number: int = old_structure.atom_get_atomic_number(old_atom_id)
				var position: Vector3 = old_structure.atom_get_position(old_atom_id)
				var new_atom_args := AtomicStructure.AddAtomParameters.new(atomic_number, position)
				var new_atom_id: int = target_structure.add_atom(new_atom_args)
				if old_color_overrides.has(old_atom_id):
					var color: Color = old_color_overrides[old_atom_id]
					if not new_color_overrides.has(color):
						new_color_overrides[color] = PackedInt32Array()
					new_color_overrides[color].append(new_atom_id)
				destination_structure_atoms_ids.push_back(new_atom_id)
				source_to_dest_atoms_ids[old_atom_id] = new_atom_id
			# 1.1 Apply collected color overrides
			for color: Color in new_color_overrides.keys():
				var atoms_for_color: PackedInt32Array = new_color_overrides[color]
				target_structure.set_color_override(atoms_for_color, color)
			# 2. Copy bonds from src to dst
			for old_bond_id: int in source_structure_bonds_ids:
				var old_bond_data: Vector3i = old_structure.get_bond(old_bond_id)
				var new_bond_id: int = target_structure.add_bond(
					source_to_dest_atoms_ids[old_bond_data.x], # atom_id_1
					source_to_dest_atoms_ids[old_bond_data.y], # atom_id_2
					old_bond_data.z                            # bond_order
				)
				destination_structure_bonds_ids.push_back(new_bond_id)
			
			# 3. Copy springs from src to dst
			for old_spring_id: int in source_structure_springs_ids:
				var anchor_id: int = old_structure.spring_get_anchor_id(old_spring_id)
				var old_atom_id: int = old_structure.spring_get_atom_id(old_spring_id)
				var new_atom_id: int = source_to_dest_atoms_ids[old_atom_id]
				var spring_constant_force: float = old_structure.spring_get_constant_force(old_spring_id)
				var is_equilibrium_length_automatic: bool = old_structure.spring_get_equilibrium_length_is_auto(old_spring_id)
				var equilibrium_manual_length: float = old_structure.spring_get_equilibrium_manual_length(old_spring_id)
				var new_spring_id: int = target_structure.spring_create(anchor_id, new_atom_id, spring_constant_force,
						is_equilibrium_length_automatic, equilibrium_manual_length)
				destination_structure_springs_ids.append(new_spring_id)
			
			# 4. invalidate bonds in src
			for old_bond_id: int in source_structure_bonds_ids:
				old_structure.remove_bond(old_bond_id)
			# 5. invalidate atoms in src
			for old_atom_id: int in source_structure_atoms_ids:
				old_structure.remove_atom(old_atom_id)
			# 6. invalidate springs in src
			#    Make all selected springs visible before invalidating them
			old_structure.set_springs_visibility(source_structure_springs_ids, true)
			for old_spring_id: int in source_structure_springs_ids:
				old_structure.spring_invalidate(old_spring_id)
			new_atoms_to_select_when_done.append_array(destination_structure_atoms_ids)
			old_structure.end_edit()
	
	if out_did_create_undo_action.value:
		# Ready to commit changes
		target_structure_context.nano_structure.end_edit()
		unselect_inactive_structure_contexts(out_workspace_context)
		if target_structure_context.is_editable():
			target_structure_context.select_atoms_and_get_auto_selected_bonds(new_atoms_to_select_when_done)
		else:
			target_structure_context.clear_selection(true)
		if commit_when_done:
			out_workspace_context.snapshot_moment("Move selection to existing structure")


static func _start_editing_if_needed(
			out_did_create_undo_action: Dictionary,
			in_target_structure_context: StructureContext) -> void:
	if out_did_create_undo_action.value:
		return
	out_did_create_undo_action.value = true
	in_target_structure_context.nano_structure.start_edit()


static func unselect_inactive_structure_contexts(out_workspace_context: WorkspaceContext) -> void:
	var edited_structure_contexts: Array[StructureContext] = out_workspace_context.get_editable_structure_contexts()
	var visible_structure_contexts: Array[StructureContext] = out_workspace_context.get_visible_structure_contexts(true)
	for context: StructureContext in visible_structure_contexts:
		if not context in edited_structure_contexts:
			context.clear_selection(false)


static func _set_selected_atoms_locked(out_workspace_context: WorkspaceContext, in_atoms_are_locked: bool) -> void:
	var selected_contexts: Array[StructureContext] = out_workspace_context.get_structure_contexts_with_selection()
	for context: StructureContext in selected_contexts:
		var selected_atoms: PackedInt32Array = context.get_selected_atoms()
		if selected_atoms.is_empty():
			continue # this will skip non AtomicStructure objects
		var atomic_structure: AtomicStructure = context.nano_structure as AtomicStructure
		atomic_structure.start_edit()
		atomic_structure.atoms_set_locked(selected_atoms, in_atoms_are_locked)
		atomic_structure.end_edit()
		
	var snapshot_name: String = "Lock Atoms" if in_atoms_are_locked else "Unlock Atoms"
	out_workspace_context.snapshot_moment(snapshot_name)


static func _get_visible_objects_aabb(out_workspace_context: WorkspaceContext) -> AABB:
	assert (out_workspace_context)
	var visible_objects_aabbs: Array[AABB] = []
	var visible_structure_contexts: Array[StructureContext] = out_workspace_context.get_visible_structure_contexts()
	for context in visible_structure_contexts:
		var aabb: AABB = context.nano_structure.get_aabb().abs()
		if aabb == AABB():
			# structure is empty
			continue
		visible_objects_aabbs.push_back(context.nano_structure.get_aabb().abs())
	assert(visible_objects_aabbs.size() > 0)
	
	var aabb: AABB = visible_objects_aabbs.pop_back()
	while visible_objects_aabbs.size():
		aabb = aabb.merge(visible_objects_aabbs.pop_back())
	return aabb


static func _get_selected_objects_aabb(out_workspace_context: WorkspaceContext) -> AABB:
	var selected_objects_aabbs: Array[AABB] = []
	var selected_structure_contexts: Array[StructureContext] = out_workspace_context.get_structure_contexts_with_selection()
	assert(selected_structure_contexts.size() > 0)
	for context in selected_structure_contexts:
		selected_objects_aabbs.push_back(context.get_selection_aabb().abs())
		
	var aabb: AABB = selected_objects_aabbs.pop_back()
	while selected_objects_aabbs.size():
		aabb = aabb.merge(selected_objects_aabbs.pop_back())
	return aabb


static func _move_camera_outside_of_aabb(out_workspace_context: WorkspaceContext, aabb: AABB) -> void:
	var camera: Camera3D = out_workspace_context.get_camera()
	var move_offset: float = aabb.get_longest_axis_size()
	while aabb.has_point(camera.global_position):
		camera.global_position += camera.global_basis.z * move_offset


static func _unpack_mol_file_and_get_path(fragment_path: String) -> String:
	assert(fragment_path.begins_with("res://"), "Unexpected file path")
	var unpacked_path: String = fragment_path.replace("res://", "user://")
	if FileAccess.file_exists(unpacked_path):
		# Check if has changed
		var local_fragment_md5: String = FileAccess.get_md5(fragment_path)
		var user_fragment_md5: String = FileAccess.get_md5(unpacked_path)
		if local_fragment_md5 == user_fragment_md5:
			# file is up to date
			return unpacked_path
	var dir_path: String = ProjectSettings.globalize_path(unpacked_path).get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file: FileAccess = FileAccess.open(unpacked_path, FileAccess.WRITE)
	assert(file != null, "Could not initialize FileAccess on path " + unpacked_path)
	file.store_buffer(FileAccess.get_file_as_bytes(fragment_path))
	file.close()
	return unpacked_path


static func _focus_camera_on_aabb(out_workspace_context: WorkspaceContext, in_focus_aabb: AABB) -> void:
	assert(out_workspace_context)
	var camera: Camera3D = out_workspace_context.get_camera()
	var camera_rotation := Quaternion(camera.global_transform.basis)
	var camera_backward: Vector3 = camera_rotation * Vector3.BACK
	
	var viewport: WorkspaceEditorViewport = out_workspace_context.get_editor_viewport()
	var focus_rect := Rect2(Vector2.ZERO, viewport.size)
	var viewport_center: Vector2 = focus_rect.get_center()
	var focus_center: Vector2 = viewport_center
	var working_area_rect_control: Control = \
			out_workspace_context.workspace_main_view.get_working_area_rect_control()
	if working_area_rect_control:
		focus_rect = working_area_rect_control.get_global_rect()
		focus_center = focus_rect.get_center()
	elif viewport.workspace_tools_container:
		focus_rect = viewport.workspace_tools_container.get_global_rect()
		focus_center = focus_rect.get_center()
	
	var min_look_distance: float = out_workspace_context.create_object_parameters.drop_distance \
			+ in_focus_aabb.get_longest_axis_size() / 2
	var look_at: Vector3 = in_focus_aabb.get_center()
	var camera_aabb: AABB = Transform3D(camera.basis) * in_focus_aabb
	var look_distance: float = max(camera_aabb.size.x, in_focus_aabb.size.y) / (2.0 * tan(deg_to_rad(camera.fov) / 2.0))
	look_distance /= min(focus_rect.size.x / viewport.size.x, focus_rect.size.y / viewport.size.y)
	look_distance = max(look_distance, min_look_distance)
	var look_from: Vector3 = look_at + camera_backward * look_distance
	
	const MAX_ORTHOGRAPHIC_ZOOM: float = 0.9 # Prevent zooming too close from a single selected atom
	var initial_camera_size: float = camera.size
	var new_camera_size: float = max(in_focus_aabb.get_longest_axis_size(), MAX_ORTHOGRAPHIC_ZOOM)
	# To calculate the offset properly on orthographic camera needs to temporarly set the camera size to it's final value
	camera.size = new_camera_size
	var viewport_center_at: Vector3 = camera.project_position(viewport_center, look_distance)
	var focus_area_center_at: Vector3 = camera.project_position(focus_center, look_distance)
	var offset: Vector3 = viewport_center_at - focus_area_center_at
	# offset has been calculated, restore initial camera zoom
	camera.size = initial_camera_size
	var new_camera_transform := Transform3D(Basis(camera_rotation), look_from + offset)

	var focus_tween: Tween = camera.create_tween()
	focus_tween.set_parallel(true)
	focus_tween.tween_property(camera, NodePath(&"global_transform"), new_camera_transform, 0.3)
	focus_tween.tween_property(camera, NodePath(&"size"), new_camera_size, 0.3)
	focus_tween.play()


static func _is_invalid_mol_file(in_path: String) -> bool:
	if in_path.begins_with("res://") or in_path.get_extension().to_lower() != "mol":
		# If builtin or not a mol file assume valid
		return false
	var path: String = ProjectSettings.globalize_path(in_path)
	var file := FileAccess.open(path, FileAccess.READ)
	var line: String = file.get_line()
	while not line.begins_with("M  "):
		if line.findn("v3000") != -1:
			# invalid V3000 mol file
			return true
		line = file.get_line()
	return false


static func _is_xyz_file(in_path: String) -> bool:
	return in_path.get_extension() == "xyz"


static func _is_msep_workspace(in_path: String) -> bool:
	return in_path.get_extension() == "msep1"


## Imports an MSEP workspace from disk, inside the current workspace.
## The structure hierarchy from the imported file is preserved and added under
## the current active group.
static func _import_msep_workspace(out_workspace_context: WorkspaceContext, path: String,
						placement: ImportFileDialog.Placement, snapshot_name: String) -> void:
	var imported_workspace: Workspace = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not imported_workspace:
		Editor_Utils.get_editor().prompt_error_msg("Cannot load file: " + path)
		return
	
	# Clear selection in other contexts
	out_workspace_context.clear_all_selection()
	
	# Rename the imported main structure for better clarity.
	var imported_main_structure: NanoStructure = imported_workspace.get_main_structure()
	if imported_main_structure.get_structure_name() == "Workspace":
		imported_main_structure.set_structure_name(path.get_file().get_basename().capitalize())
	
	# Add all structures to the workspace based on the placement options
	var aabb := AABB()
	for structure: NanoStructure in imported_workspace.get_structures():
		aabb = aabb.merge(structure.get_aabb())
	var placement_xform: Transform3D = _get_placement_transform(out_workspace_context, aabb, placement)
	var new_structures: Array[NanoStructure]
	new_structures = out_workspace_context.workspace.append_workspace(imported_workspace, placement_xform)
	
	# Select newly added
	for structure: NanoStructure in new_structures:
		var structure_context: StructureContext = out_workspace_context.get_nano_structure_context(structure)
		structure_context.select_all()
	
	# Focus on the imported structures 
	if placement != ImportFileDialog.Placement.IN_FRONT_OF_CAMERA:
		WorkspaceUtils.focus_camera_on_aabb(out_workspace_context, aabb)
	
	# Undo redo
	out_workspace_context.snapshot_moment(snapshot_name)


static func _import_xyz_file(out_workspace_context: WorkspaceContext, path: String,
		placement: ImportFileDialog.Placement, create_new_group: bool, generate_bonds: bool, snapshot_name: String) -> void:
	out_workspace_context.start_async_work("Importing XYZ file")
	out_workspace_context.clear_all_selection()
	
	# Actual loading happens in external/xyz_format_loader.gd
	var xyz_structure: NanoMolecularStructure = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not xyz_structure:
		Editor_Utils.get_editor().prompt_error_msg("Cannot load file: " + path)
		return
	
	# Add structure to current workspace
	var aabb := xyz_structure.get_aabb()
	var placement_xform: Transform3D = _get_placement_transform(out_workspace_context, aabb, placement)
	var context: StructureContext = out_workspace_context.get_current_structure_context()
	var active_structure: NanoMolecularStructure = context.nano_structure
	if create_new_group:
		xyz_structure.start_edit()
		for atom_id: int in xyz_structure.get_valid_atoms():
			var new_position: Vector3 = placement_xform * xyz_structure.atom_get_position(atom_id)
			xyz_structure.atom_set_position(atom_id, new_position)
		xyz_structure.end_edit()
		xyz_structure.set_structure_name(path.get_file().get_basename().capitalize())
		out_workspace_context.workspace.add_structure(xyz_structure, active_structure)
		context = out_workspace_context.get_nano_structure_context(xyz_structure)
		context.select_all()
	else:
		var merge_result: AtomicStructure.MergeStructureResult = active_structure.merge_structure(
			xyz_structure, placement_xform, out_workspace_context.workspace)
		context.select_atoms(merge_result.new_atoms)
	
	if generate_bonds:
		# Only generate bonds for the selected atoms (the ones from the xyz file),
		# not the whole structure. This is relevant if create_new_group is false.
		await AutoBonder.generate_bonds_for_structure(context, true)
	
	if placement != ImportFileDialog.Placement.IN_FRONT_OF_CAMERA:
		WorkspaceUtils.focus_camera_on_aabb(out_workspace_context, aabb)
	
	out_workspace_context.snapshot_moment(snapshot_name)
	out_workspace_context.end_async_work()


static var _import_thread: Thread = null
static func _import_file(out_workspace_context: WorkspaceContext, path: String,
						generate_bonds: bool, add_hydrogens: bool, remove_waters: bool) -> OpenMMClass.ImportFileResult:
	var promise: Promise = OpenMM.request_import(path, generate_bonds, add_hydrogens, remove_waters)
	
	var friendly_name: String = path.get_file().get_basename().capitalize()
	out_workspace_context.start_async_work(out_workspace_context.tr(&"Importing {0}").format([friendly_name]))
	await promise.wait_for_fulfill()
	if promise.has_error() && path.get_extension().to_lower() == "pdb":
			print_debug("OpenMM Server failed to load PDB file, will fallback to builtin method")
			var failed_result: OpenMMClass.ImportFileResult = promise.get_result() as OpenMMClass.ImportFileResult
			promise = _fallback_pdb_load(failed_result.original_payload)
			await promise.wait_for_fulfill()
			if _import_thread != null:
				_import_thread.wait_to_finish()
				_import_thread = null
	out_workspace_context.end_async_work()
	if promise.has_error():
		var alert_dialog : AcceptDialog = OpenmmWarningDialog.instantiate()
		alert_dialog.set_short_message(out_workspace_context.tr(&"Unable to import the selected File. Maybe the content is invalid."))
		alert_dialog.set_detailed_message(promise.get_error())
		Engine.get_main_loop().root.add_child(alert_dialog)
		return
	var import_file_result: OpenMMClass.ImportFileResult = promise.get_result() as OpenMMClass.ImportFileResult
	return import_file_result


static func _load_import_file_result_to_new_group(out_workspace_context: WorkspaceContext,
							in_import_file_result: OpenMMClass.ImportFileResult,
							placement: ImportFileDialog.Placement,
							snapshot_name: String) -> void:
	var new_structure: NanoStructure = AtomicStructure.create()
	var placement_xform: Transform3D = _get_placement_transform(out_workspace_context, in_import_file_result.aabb, placement)
	var file_path: String = in_import_file_result.original_payload.file_path
	new_structure.set_structure_name(file_path.get_file().get_basename())
	
	# Add atoms and bonds
	new_structure.start_edit()
	for a_idx: int in in_import_file_result.atoms_count:
		var atomic_number: int = in_import_file_result.atomic_numbers[a_idx]
		assert(atomic_number > 0 and atomic_number <= 118, "Invalid atomic number: %d" % atomic_number)
		var pos: Vector3 = placement_xform * in_import_file_result.positions[a_idx]
		var add_params := NanoMolecularStructure.AddAtomParameters.new(atomic_number, pos)
		new_structure.add_atom(add_params)
	for b_idx: int in in_import_file_result.bonds_count:
		var bond: Vector3i = in_import_file_result.bonds[b_idx]
		new_structure.add_bond(bond[0], bond[1], bond[2])
	new_structure.end_edit()
	
	# Clear selection in other contexts
	var other_contexts: Array[StructureContext] = out_workspace_context.get_structure_contexts_with_selection()
	for context: StructureContext in other_contexts:
		context.clear_selection()
	
	# Add new structure and select all
	var current_structure: NanoStructure = out_workspace_context.get_current_structure_context().nano_structure
	out_workspace_context.workspace.add_structure(new_structure, current_structure)
	var new_structure_context: StructureContext = out_workspace_context.get_nano_structure_context(new_structure)
	new_structure_context.select_all()
	
	# Focus on newly imported file
	var selection_aabb: AABB = out_workspace_context.get_selection_aabb()
	if placement != ImportFileDialog.Placement.IN_FRONT_OF_CAMERA:
		WorkspaceUtils.focus_camera_on_aabb(out_workspace_context, selection_aabb)
	out_workspace_context.snapshot_moment(snapshot_name)


static func _load_import_file_result(out_workspace_context: WorkspaceContext,
							in_import_file_result: OpenMMClass.ImportFileResult,
							placement: ImportFileDialog.Placement,
							snapshot_name: String) -> void:
	var structure_context: StructureContext = out_workspace_context.get_current_structure_context()
	var structure: NanoStructure = out_workspace_context.get_current_structure_context().nano_structure
	
	var placement_xform: Transform3D = _get_placement_transform(out_workspace_context, in_import_file_result.aabb, placement)
	structure.start_edit()
	var original_to_structure_atom_map: Dictionary = {}
	var new_atoms := PackedInt32Array()
	var new_bonds := PackedInt32Array()
	for a_idx in range(in_import_file_result.atoms_count):
		var atomic_number: int = in_import_file_result.atomic_numbers[a_idx]
		assert(atomic_number > 0 and atomic_number <= 118, "Invalid atomic number: %d" % atomic_number)
		var pos: Vector3 = placement_xform * in_import_file_result.positions[a_idx]
		var add_params := AtomicStructure.AddAtomParameters.new(atomic_number, pos)
		var new_atom_id: int = structure.add_atom(add_params)
		original_to_structure_atom_map[a_idx] = new_atom_id
		new_atoms.push_back(new_atom_id)
	# 3. Add all bonds
	for b_idx in range(in_import_file_result.bonds_count):
		var bond: Vector3i = in_import_file_result.bonds[b_idx]
		var atom1: int = bond[0]
		var atom2: int = bond[1]
		var new_atom_a: int = original_to_structure_atom_map[atom1]
		var new_atom_b: int = original_to_structure_atom_map[atom2]
		var order: int = bond[2]
		var bond_id: int = structure.atom_find_bond_between(new_atom_a, new_atom_b)
		if bond_id < 0:
			bond_id = structure.add_bond(new_atom_a, new_atom_b, order)
			new_bonds.push_back(bond_id)
	structure.end_edit()
	
	structure_context.set_atom_selection(new_atoms)
	structure_context.set_bond_selection(new_bonds)
	structure_context.set_shape_selected(false)
	
	if placement != ImportFileDialog.Placement.IN_FRONT_OF_CAMERA:
		var selection_aabb: AABB = out_workspace_context.get_selection_aabb()
		WorkspaceUtils.focus_camera_on_aabb(out_workspace_context, selection_aabb)
	
	# 4. register Undo/Redo actions
	var other_contexts: Array[StructureContext] = \
			out_workspace_context.get_visible_structure_contexts(true)
	for context in other_contexts:
		if context == structure_context:
			continue
		context.clear_selection()
	
	out_workspace_context.snapshot_moment(snapshot_name)


static func _import_file_result_to_structure(in_import_file_result: OpenMMClass.ImportFileResult) -> NanoStructure:
	var structure: AtomicStructure = AtomicStructure.create()
	structure.start_edit()
	var placement_xform: Transform3D = _get_placement_transform(null, in_import_file_result.aabb, ImportFileDialog.Placement.CENTER_ON_ORIGIN)
	
	for a_idx in in_import_file_result.atoms_count:
		var atomic_number: int = in_import_file_result.atomic_numbers[a_idx]
		assert(atomic_number > 0 and atomic_number <= 118, "Invalid atomic number: %d" % atomic_number)
		var pos: Vector3 = placement_xform * in_import_file_result.positions[a_idx]
		var add_params := AtomicStructure.AddAtomParameters.new(atomic_number, pos)
		structure.add_atom(add_params)
	
	for b_idx in in_import_file_result.bonds_count:
		var bond: Vector3i = in_import_file_result.bonds[b_idx]
		var atom1: int = bond[0]
		var atom2: int = bond[1]
		var order: int = bond[2]
		var bond_id: int = structure.atom_find_bond_between(atom1, atom2)
		if bond_id < 0:
			bond_id = structure.add_bond(atom1, atom2, order)
		
	structure.end_edit()
	return structure


static func _get_placement_transform(out_workspace_context: WorkspaceContext, original_aabb: AABB, in_placement: ImportFileDialog.Placement) -> Transform3D:
	match in_placement:
		ImportFileDialog.Placement.KEEP_ORIGINAL:
			return Transform3D()
		ImportFileDialog.Placement.IN_FRONT_OF_CAMERA:
			var camera: Camera3D = out_workspace_context.get_camera()
			var camera_transform: Transform3D = camera.global_transform
			var camera_rotation: Quaternion = Quaternion(camera_transform.basis)
			var camera_fwd: Vector3 = camera_rotation * Vector3.FORWARD
			var protein_depth_in_nanometers: float = original_aabb.size.z
			var new_protein_origin: Vector3 = camera.global_position
			var drop_distance: float = out_workspace_context.create_object_parameters.drop_distance + protein_depth_in_nanometers/2
			new_protein_origin += camera_fwd * drop_distance
			return Transform3D(Basis(camera_rotation), new_protein_origin)
		ImportFileDialog.Placement.CENTER_ON_ORIGIN:
			return Transform3D(Basis(), -original_aabb.position)
		_:
			assert(false, "Invalid or unknown placement value")
			return Transform3D()


static func _fallback_pdb_load(out_payload: OpenMMClass.ImportFilePayload) -> Promise:
	var promise := Promise.new()
	ProteinDataBaseFormatLoader.autogenerate_bonds = out_payload.generate_bonds
	if RingActionImportFile._LOAD_FILE_IN_THREAD:
		var thread_lambda: Callable = func() -> void:
			# static functions dont seem to work properly to start a thread, instead we use a lambda
			WorkspaceUtils._fallback_load_pdb_in_thread(out_payload, promise)
		_import_thread = Thread.new()
		_import_thread.start(thread_lambda)
	else:
		_fallback_load_pdb_in_thread(out_payload, promise)
	return promise

static func _fallback_load_pdb_in_thread(out_payload: OpenMMClass.ImportFilePayload, promise: Promise) -> void:
	var result := OpenMMClass.ImportFileResult.new(out_payload, [], [], [])
	var protein: ProteinDB = load(out_payload.file_path) as ProteinDB
	if !is_instance_valid(protein):
		promise.fail.call_deferred("Failed to import pdb file " + out_payload.file_path, result)
		return
	if protein.get_atoms_count() == 0:
		promise.fail.call_deferred("PDB File is empty, nothing to import", result)
		return
	
	# 2. Add all atoms
	result.atoms_count = protein.get_atoms_count()
	var pdb_to_import_result_id: Dictionary = {} # [int, int]
	for a_id in protein.get_atoms_ids():
		var pdb_atom: PdbAtom = protein.get_atom(a_id)
		var atomic_number: int = PeriodicTable.get_by_symbol(pdb_atom.element_name.capitalize()).number
		assert(atomic_number != -1,
				"Could not find atomic_number for atom with element %s" % pdb_atom.element_name)
		var pos_in_armstrongs: Vector3 = pdb_atom.position
		pos_in_armstrongs = pos_in_armstrongs
		var pos: Vector3 = pos_in_armstrongs * RingActionImportFile._ARMSTRONGS_TO_NANOMETERS
		pdb_to_import_result_id[a_id] = result.atomic_numbers.size()
		result.atomic_numbers.push_back(atomic_number)
		result.positions.push_back(pos)
	
	# 3. Add all bonds
	var bonds_already_added: Dictionary = {}
	for a_id in protein.get_atoms_ids():
		var pdb_atom: PdbAtom = protein.get_atom(a_id)
		for connection: PdbAtom.Connection in pdb_atom.connections:
			var b_id: int = connection.atom_id
			
			# Avoid adding the same bonds twice.
			# Bond id is defined as [smallest_atom_id, largest_atom_id]
			var bond_id: Vector2i = Vector2i(min(a_id, b_id), max(a_id, b_id))
			if bonds_already_added.has(bond_id):
				continue
			bonds_already_added[bond_id] = true
			
			# PDB file atom ids are 1 based, import result is 0 based, so we need to shift the connection ids
			var new_atom_id_a: int = pdb_to_import_result_id[a_id]
			var new_atom_id_b: int = pdb_to_import_result_id[b_id]
			result.bonds.append(Vector3i(new_atom_id_a, new_atom_id_b, 2 if connection.double_connection else 1))
			result.bonds_count += 1
	promise.fulfill.call_deferred(result)


static func _open_screen_capture_dialog(in_workspace_context: WorkspaceContext) -> void:
	assert(in_workspace_context)
	var workspace_main_view: WorkspaceMainView = in_workspace_context.workspace_main_view
	workspace_main_view.screen_capture_dialog.popup_centered_ratio(0.5)


static func _open_quick_search_dialog(in_workspace_context: WorkspaceContext) -> void:
	assert(in_workspace_context)
	var workspace_main_view: WorkspaceMainView = in_workspace_context.workspace_main_view
	workspace_main_view.quick_search_dialog.popup_centered_ratio(0.4)


static func _apply_simulation_state(
		out_workspace_context: WorkspaceContext,
		in_payload: OpenMMPayload,
		in_positions: PackedVector3Array) -> void:
	if out_workspace_context == null:
		return
	var editing_structures: Array[NanoStructure] = []
	for i in range(in_positions.size()):
		var structure_atom_pair: Array = in_payload.request_atom_id_to_structure_and_atom_id_map[i]
		var structure: NanoStructure = out_workspace_context.workspace.get_structure_by_int_guid(structure_atom_pair[0])
		var atom_id: int = structure_atom_pair[1]
		var pos: Vector3 = in_positions[i]
		if is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z):
			push_error("Invalid pos for ", structure.get_structure_name(), "@", atom_id, "->", pos)
			continue
		assert(structure != null)
		
		if !structure in editing_structures:
			editing_structures.push_back(structure)
			structure.start_edit()
		structure.atom_set_position(atom_id, pos)
	for nano_structure in editing_structures:
		nano_structure.end_edit()


static func _can_relax_selection(in_workspace_context: WorkspaceContext) -> bool:
	var selected_structures: Array[StructureContext] = \
			in_workspace_context.get_atomic_structure_contexts_with_selection()
	if selected_structures.is_empty():
		return false
	for context in selected_structures:
		var selected_atoms: PackedInt32Array = context.get_selected_atoms()
		if not selected_atoms.is_empty():
			return true
	return false


static func _can_relax_all(in_workspace_context: WorkspaceContext) -> bool:
	var visible_structures: Array[StructureContext] = \
			in_workspace_context.get_visible_structure_contexts()
	for context in visible_structures:
		if not context.nano_structure is AtomicStructure:
			continue
		if context.nano_structure.get_valid_atoms_count() > 0:
			# At least 1 visible atom
			return true
	return false


static func _can_move_selection_to_another_group(in_workspace_context: WorkspaceContext) -> bool:
	var selected_structures: Array[StructureContext] = \
			in_workspace_context.get_structure_contexts_with_selection()
	if selected_structures.is_empty():
		return false
	for context in selected_structures:
		var structure: NanoStructure = context.nano_structure
		var selected_atoms: PackedInt32Array = context.get_selected_atoms()
		var selected_bonds: PackedInt32Array = context.get_selected_bonds()
		# 1. Check if all bonds connected to selected atoms are also selected
		for atom_id in selected_atoms:
			var atom_bonds: PackedInt32Array = structure.atom_get_bonds(atom_id)
			if atom_bonds.is_empty():
				# Atom is unbound, We allow it
				continue
			for atom_bond_id in atom_bonds:
				if not atom_bond_id in selected_bonds:
					# At least one bond is not selected
					# This means molecule is not fully selected
					return false
		# 2. Check if all atoms connected to selected bonds are also selected
		for bond_id in selected_bonds:
			var bond_data: Vector3i = structure.get_bond(bond_id)
			if not bond_data.x in selected_atoms or not bond_data.y in selected_atoms:
				# At least one atom is not selected
				# This means molecule is not fully selected
				return false
	return true

static func _relax(
		out_workspace_context: WorkspaceContext,
		in_temperature_in_kelvins: float,
		in_selection_only: bool,
		in_include_springs: bool,
		in_lock_atoms: bool,
		in_passivate_molecules: bool,
		in_animate: bool) -> RelaxRequest:
	var request: RelaxRequest = OpenMM.request_relax(out_workspace_context,
			in_temperature_in_kelvins, in_selection_only, in_include_springs, in_lock_atoms, in_passivate_molecules)
	_process_relax_request(request, out_workspace_context, in_animate)
	return request


static func _retry_relax(
		out_workspace_context: WorkspaceContext,
		out_relax_request: RelaxRequest) -> RelaxRequest:
	out_workspace_context.clear_alerts()
	# 1. revert atoms to their original position
	_do_tween_atom_positions(0.0, out_workspace_context, out_relax_request.original_payload,
			out_relax_request.original_payload.raw_initial_positions)
	# 2. repeat relax request
	var temperature_in_kelvins: float = out_relax_request.temperature_in_kelvins
	var selection_only: bool = out_relax_request.selection_only
	var include_springs: bool = out_relax_request.include_springs
	var lock_atoms: bool = out_relax_request.lock_atoms
	var passivate_molecules: bool = out_relax_request.passivate_molecules
	var request: RelaxRequest = OpenMM.request_relax(out_workspace_context, temperature_in_kelvins, selection_only, include_springs, lock_atoms, passivate_molecules)
	out_relax_request.retried = true
	out_relax_request.notify_retry(request)
	_process_relax_request(request, out_workspace_context, true)
	return request


static func _process_relax_request(
		out_request: RelaxRequest,
		out_workspace_context: WorkspaceContext,
		in_animate: bool = false) -> void:
	out_workspace_context.start_async_work(out_workspace_context.tr("Minimizing potential energy ..."))
	await out_request.promise.wait_for_fulfill()
	out_workspace_context.end_async_work()
	var relax_result: OpenMMClass.RelaxResult = out_request.promise.get_result() as OpenMMClass.RelaxResult
	var failed: bool = out_request.promise.has_error()
	if failed:
		var error: String = out_request.promise.get_error()
		if error != "Cancelled":
			var alert_dialog : AcceptDialog = OpenmmWarningDialog.instantiate()
			alert_dialog.set_detailed_message(error)
			Engine.get_main_loop().root.add_child(alert_dialog)
		out_workspace_context.notify_atoms_relaxation_finished(error)
		return
	var payload: OpenMMPayload = relax_result.original_payload
	var tween_duration: float = 0.0
	if in_animate:
		tween_duration = ProjectSettings.get_setting(&"msep/simulation/relaxation_animation_time", 0.5)
		out_workspace_context.pause_inputs(tween_duration)
		var tween: Tween = Engine.get_main_loop().create_tween()
		out_workspace_context.notify_atoms_relaxation_started()
		var result_positions: PackedVector3Array = relax_result.positions.duplicate()
		tween.tween_method(
			# method:
			WorkspaceUtils._do_tween_atom_positions.bind(out_workspace_context, payload, result_positions),
			0.0, # from (in_lerp)
			1.0, # to (in_lerp)
			tween_duration
		).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
		var _on_relaxation_tween_finished: Callable = func() -> void:
			_validate_relax_result(out_workspace_context, out_request)
			out_workspace_context.snapshot_moment("Relaxation Done")
			out_workspace_context.notify_atoms_relaxation_finished(out_request.promise.get_error())
		tween.finished.connect(_on_relaxation_tween_finished)
	else:
		_do_tween_atom_positions(1.0, out_workspace_context, payload, relax_result.positions)
		_validate_relax_result(out_workspace_context, out_request)
		out_workspace_context.notify_atoms_relaxation_finished(out_request.promise.get_error())


static func _do_tween_atom_positions(
			in_lerp: float,
			out_workspace_context: WorkspaceContext,
			in_payload: OpenMMPayload,
			in_target_positions: PackedVector3Array) -> void:
	var editing_structures: Array[NanoStructure] = []
	for i in range(in_target_positions.size()):
		var structure_atom_pair: Array = in_payload.request_atom_id_to_structure_and_atom_id_map[i]
		var structure: NanoStructure = out_workspace_context.workspace.get_structure_by_int_guid(structure_atom_pair[0])
		var atom_id: int = structure_atom_pair[1]
		var start_pos: Vector3 = in_payload.raw_initial_positions[i]
		var end_pos: Vector3 = in_target_positions[i]
		var pos: Vector3 = lerp(start_pos, end_pos, in_lerp)
		assert(structure != null)
		
		if !structure in editing_structures:
			editing_structures.push_back(structure)
			structure.start_edit()
		structure.atom_set_position(atom_id, pos)
	for nano_structure in editing_structures:
		nano_structure.end_edit()


static func _validate_relax_result(out_workspace_context: WorkspaceContext, in_relax_request: RelaxRequest) -> void:
	in_relax_request.bad_tetrahedral_bonds_detected = has_invalid_tetrahedral_structure(out_workspace_context, in_relax_request.selection_only)
	if out_workspace_context.ignored_warnings.invalid_relaxed_tetrahedral_structure:
		# Warning was disabled, skip
		return
	if not in_relax_request.bad_tetrahedral_bonds_detected:
		# Relax is valid, skip
		return
	var warning_promise: Promise = out_workspace_context.show_warning_dialog(
			out_workspace_context.tr("Simulation resulted in incorrect tetrahedral bond angles."),
			"", out_workspace_context.tr("Ignore"),
			&"invalid_relaxed_tetrahedral_structure")
	await warning_promise.wait_for_fulfill()
	if warning_promise.get_result() as bool:
		_retry_relax(out_workspace_context, in_relax_request)
	else:
		in_relax_request.notify_retry_discarded()


static func _forward_event(out_workspace_context: WorkspaceContext, event: InputEvent) -> void:
	var main_view: WorkspaceMainView = out_workspace_context.workspace_main_view
	var viewport: WorkspaceEditorViewport = main_view.editor_viewport_container.editor_viewport
	viewport.set_input_forwarding_enabled(true)
	viewport.forward_viewport_input(event)
