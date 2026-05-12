extends DynamicContextControl

const AlignRelativeTo = AlignSelectionParameters.AlignRelativeTo
const WorldPlane = AlignSelectionParameters.WorldPlane
const BoxFace = AlignSelectionParameters.BoxFace


var _relative_to_option_button: OptionButton
var _world_plane_container: HBoxContainer
var _plane_button_group: ButtonGroup
var _pick_plane_button: Button
var _align_rotation_button: Button
var _align_h_begin_button: Button
var _align_h_center_button: Button
var _align_h_end_button: Button
var _align_v_begin_button: Button
var _align_v_center_button: Button
var _align_v_end_button: Button


var _workspace_context: WorkspaceContext = null
var _align_selection_parameters: AlignSelectionParameters


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_ALIGN_SELECTION_PANEL) == false:
		return false
	_ensure_workspace_initialized(in_workspace_context)
	_update_ui()
	return _align_selection_parameters.can_align_selection()


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context != null:
		return
	_workspace_context = in_workspace_context
	_align_selection_parameters = in_workspace_context.align_selection_parameters
	_align_selection_parameters.align_relative_to_changed.connect(_on_align_relative_to_changed)
	visibility_changed.connect(_on_visibility_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_relative_to_option_button = %RelativeToOptionButton as OptionButton
		_world_plane_container = %WorldPlaneContainer as HBoxContainer
		_plane_button_group = (%XY as Button).button_group
		_pick_plane_button = %PickPlaneButton as Button
		_align_rotation_button = %AlignRotationButton as Button
		_align_h_begin_button = %AlignHBeginButton as Button
		_align_h_center_button = %AlignHCenterButton as Button
		_align_h_end_button = %AlignHEndButton as Button
		_align_v_begin_button = %AlignVBeginButton as Button
		_align_v_center_button = %AlignVCenterButton as Button
		_align_v_end_button = %AlignVEndButton as Button
		_relative_to_option_button.item_selected.connect(_on_relative_to_option_button_item_selected)
		_plane_button_group.pressed.connect(_on_plane_button_group_pressed)
		_pick_plane_button.pressed.connect(_on_pick_plane_button_pressed)
		_align_rotation_button.pressed.connect(_on_align_rotation_button_pressed)
		_align_h_begin_button.pressed.connect(_on_align_h_button_pressed.bind(HORIZONTAL_ALIGNMENT_LEFT))
		_align_h_center_button.pressed.connect(_on_align_h_button_pressed.bind(HORIZONTAL_ALIGNMENT_CENTER))
		_align_h_end_button.pressed.connect(_on_align_h_button_pressed.bind(HORIZONTAL_ALIGNMENT_RIGHT))
		_align_v_begin_button.pressed.connect(_on_align_v_button_pressed.bind(VERTICAL_ALIGNMENT_TOP))
		_align_v_center_button.pressed.connect(_on_align_v_button_pressed.bind(VERTICAL_ALIGNMENT_CENTER))
		_align_v_end_button.pressed.connect(_on_align_v_button_pressed.bind(VERTICAL_ALIGNMENT_BOTTOM))


func _on_align_relative_to_changed() -> void:
	_update_ui()


func _on_visibility_changed() -> void:
	_align_selection_parameters.set_alignment_tools_enabled(is_visible_in_tree())


func _update_ui() -> void:
	_world_plane_container.visible = _align_selection_parameters.get_align_relative_to() in [
		AlignRelativeTo.WORLD_PLANE,
		AlignRelativeTo.CAMERA_PLANE
	]
	_pick_plane_button.visible = _align_selection_parameters.get_align_relative_to() \
		== AlignRelativeTo.SPECIFIC_BOX_PLANE
	_align_rotation_button.disabled = not _align_selection_parameters.can_align_rotations()
	_align_h_begin_button.disabled = not _align_selection_parameters.can_align_positions()
	_align_h_center_button.disabled = not _align_selection_parameters.can_align_positions()
	_align_h_end_button.disabled = not _align_selection_parameters.can_align_positions()
	_align_v_begin_button.disabled = not _align_selection_parameters.can_align_positions()
	_align_v_center_button.disabled = not _align_selection_parameters.can_align_positions()
	_align_v_end_button.disabled = not _align_selection_parameters.can_align_positions()


func _on_relative_to_option_button_item_selected(in_index: int) -> void:
	_align_selection_parameters.set_align_relative_to(
		in_index as AlignRelativeTo
	)


func _on_plane_button_group_pressed(in_button: Button) -> void:
	_align_selection_parameters.set_align_to_what_plane(
		in_button.get_index() as WorldPlane
	)


func _on_pick_plane_button_pressed() -> void:
	_align_selection_parameters.start_picking_obb()


func _on_align_rotation_button_pressed() -> void:
	var align_basis: Basis
	var skip_id: int = Workspace.INVALID_OBJECT_INDEX
	var relative_to: AlignRelativeTo = _align_selection_parameters.get_align_relative_to()
	match relative_to:
		AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE:
			align_basis = Basis()
			if relative_to == AlignRelativeTo.CAMERA_PLANE:
				align_basis = _workspace_context.get_camera_global_transform().basis
			var plane: WorldPlane = _align_selection_parameters.get_align_to_what_plane()
			match plane:
				WorldPlane.XY:
					pass
				WorldPlane.XZ:
					align_basis = align_basis.rotated(align_basis[0], -PI * 0.5)
				WorldPlane.YZ:
					align_basis = align_basis.rotated(align_basis[1], PI * 0.5)
		AlignRelativeTo.BIGGEST_BOX_PLANE, AlignRelativeTo.SPECIFIC_BOX_PLANE:
			align_basis = _align_selection_parameters.get_align_obb_target().transform.basis
			var face: BoxFace = _align_selection_parameters.get_align_obb_face()
			match face:
				BoxFace.FRONT_BACK:
					pass
				BoxFace.TOP_BOTTOM:
					align_basis = align_basis.rotated(align_basis[0], -PI * 0.5)
				BoxFace.LEFT_RIGHT:
					align_basis = align_basis.rotated(align_basis[1], PI * 0.5)
			skip_id = _align_selection_parameters.get_align_obb_target_id()
	var something_changed: bool = false
	for context: StructureContext in _align_selection_parameters.get_alignable_structure_contexts():
		if context.get_int_guid() == skip_id:
			continue
		var nano_structure: NanoStructure = context.nano_structure
		var old_transform: Transform3D = context.get_selection_obb().transform
		var new_transform: Transform3D
		if nano_structure.has_transform():
			new_transform = Transform3D(align_basis, old_transform.origin)
		else:
			_align_transform(old_transform, align_basis)
		var delta_transform: Transform3D = old_transform.inverse() * new_transform
		
		var atoms_to_move: PackedInt32Array = []
		var previous_positions: PackedVector3Array = []
		var target_positions: PackedVector3Array = []
		var nmb_of_moved_atoms: int = 0
		for atom_id: int in context.get_selected_atoms():
			var old_pos: Vector3 = nano_structure.atom_get_position(atom_id)
			var new_pos: Vector3 = delta_transform * old_pos
			atoms_to_move.push_back(atom_id)
			target_positions.push_back(new_pos)
			previous_positions.push_back(old_pos)
			nmb_of_moved_atoms += 1
		
		var atoms_changed: bool = nmb_of_moved_atoms > 0
		var object_moved: bool = context.is_shape_selected() or context.is_motor_selected() or context.is_particle_emitter_selected()
		if atoms_changed or object_moved:
			if atoms_changed:
				nano_structure.start_edit()
				nano_structure.atoms_set_positions(atoms_to_move, target_positions)
				nano_structure.end_edit()
			if object_moved:
				nano_structure.set_transform(nano_structure.get_transform()* delta_transform)
			
			something_changed = true
	if something_changed:
		_workspace_context.snapshot_moment("Align Selection Rotation")


func _align_transform(in_transform: Transform3D, in_align_basis: Basis) -> Transform3D:
	for i in 3:
		var most_aligned_dir: int = -1
		var best_alignment: float = -1.0
		for j in 3:
			var dir: Vector3 = in_transform.basis[i]
			if abs(dir.dot(in_align_basis[j])) > best_alignment:
				best_alignment = abs(dir.dot(in_align_basis[j]))
				most_aligned_dir = j
		in_transform.basis[i] = sign(in_transform.basis[i]) * in_align_basis[most_aligned_dir]
	return in_transform;


func _on_align_h_button_pressed(in_alignment: HorizontalAlignment) -> void:
	push_warning("TODO: _on_align_h_button_pressed(%d)" % in_alignment)


func _on_align_v_button_pressed(in_alignment: VerticalAlignment) -> void:
	push_warning("TODO: _on_align_v_button_pressed(%d)" % in_alignment)
