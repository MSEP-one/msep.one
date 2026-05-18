extends DynamicContextControl

const AlignRelativeTo = AlignSelectionParameters.AlignRelativeTo
const WorldPlane = AlignSelectionParameters.WorldPlane
const BoxFace = AlignSelectionParameters.BoxFace

enum Alignment {
	IGNORE = -1,
	BEGIN,
	CENTER,
	END,
}


var _relative_to_option_button: OptionButton
var _world_plane_container: HBoxContainer
var _plane_button_group: ButtonGroup
var _specific_box_container: HBoxContainer
var _prev_face_button: Button
var _pick_plane_button: Button
var _next_face_button: Button
var _align_rotation_button: Button
var _align_camera_button: Button
var _align_position_buttons: Array[Button]

var _workspace_context: WorkspaceContext = null
var _align_selection_parameters: AlignSelectionParameters


func should_show(in_workspace_context: WorkspaceContext)-> bool:
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
		
		_specific_box_container = %SpecificBoxContainer as HBoxContainer
		_prev_face_button = %PrevFaceButton as Button
		_pick_plane_button = %PickPlaneButton as Button
		_next_face_button = %NextFaceButton as Button
		
		_relative_to_option_button.item_selected.connect(_on_relative_to_option_button_item_selected)
		_plane_button_group.pressed.connect(_on_plane_button_group_pressed)
		_pick_plane_button.pressed.connect(_on_pick_plane_button_pressed)
		_prev_face_button.pressed.connect(_on_prev_face_button_pressed)
		_next_face_button.pressed.connect(_on_next_face_button_pressed)
		
		_align_rotation_button = %AlignRotationButton as Button
		_align_rotation_button.pressed.connect(_on_align_rotation_button_pressed)
		
		_align_camera_button = %AlignCameraButton as Button
		_align_camera_button.pressed.connect(_on_align_camera_button_pressed)
		
		var align_h_begin_v_begin_button := %AlignHBeginVBeginButton as Button
		var align_v_begin_button := %AlignVBeginButton as Button
		var align_h_end_v_begin_button := %AlignHEndVBeginButton as Button
		var align_h_begin_button := %AlignHBeginButton as Button
		var align_center_button := %AlignCenterButton as Button
		var align_h_end_button := %AlignHEndButton as Button
		var align_h_begin_v_end_button := %AlignHBeginVEndButton as Button
		var align_v_end_button := %AlignVEndButton as Button
		var align_h_end_v_end_button := %AlignHEndVEndButton as Button
		var align_top_button := %AlignTopButton as Button
		var align_left_button := %AlignLeftButton as Button
		var align_right_button := %AlignRightButton as Button
		var align_bottom_button := %AlignBottomButton as Button
		var align_v_center_button := %AlignVCenterButton as Button
		var align_h_center_button := %AlignHCenterButton as Button

		_align_position_buttons = [
			align_h_begin_v_begin_button,
			align_v_begin_button,
			align_h_end_v_begin_button,
			align_h_begin_button,
			align_center_button,
			align_h_end_button,
			align_h_begin_v_end_button,
			align_v_end_button,
			align_h_end_v_end_button,
			align_top_button,
			align_left_button,
			align_right_button,
			align_bottom_button,
			align_v_center_button,
			align_h_center_button,
		]
		align_h_begin_v_begin_button.pressed.connect(_on_align_button_pressed.bind(Alignment.BEGIN, Alignment.BEGIN))
		align_v_begin_button.pressed.connect(_on_align_button_pressed.bind(Alignment.CENTER, Alignment.BEGIN))
		align_h_end_v_begin_button.pressed.connect(_on_align_button_pressed.bind(Alignment.END, Alignment.BEGIN))
		align_h_begin_button.pressed.connect(_on_align_button_pressed.bind(Alignment.BEGIN, Alignment.CENTER))
		align_center_button.pressed.connect(_on_align_button_pressed.bind(Alignment.CENTER, Alignment.CENTER))
		align_h_end_button.pressed.connect(_on_align_button_pressed.bind(Alignment.END, Alignment.CENTER))
		align_h_begin_v_end_button.pressed.connect(_on_align_button_pressed.bind(Alignment.BEGIN, Alignment.END))
		align_v_end_button.pressed.connect(_on_align_button_pressed.bind(Alignment.CENTER, Alignment.END))
		align_h_end_v_end_button.pressed.connect(_on_align_button_pressed.bind(Alignment.END, Alignment.END))
		align_top_button.pressed.connect(_on_align_button_pressed.bind(Alignment.IGNORE, Alignment.BEGIN))
		align_left_button.pressed.connect(_on_align_button_pressed.bind(Alignment.BEGIN, Alignment.IGNORE))
		align_right_button.pressed.connect(_on_align_button_pressed.bind(Alignment.END, Alignment.IGNORE))
		align_bottom_button.pressed.connect(_on_align_button_pressed.bind(Alignment.IGNORE, Alignment.END))
		align_v_center_button.pressed.connect(_on_align_button_pressed.bind(Alignment.IGNORE, Alignment.CENTER))
		align_h_center_button.pressed.connect(_on_align_button_pressed.bind(Alignment.CENTER, Alignment.IGNORE))


func _on_align_relative_to_changed() -> void:
	_update_ui()


func _on_visibility_changed() -> void:
	_align_selection_parameters.set_alignment_tools_enabled(is_visible_in_tree())


func _update_ui() -> void:
	_world_plane_container.visible = _align_selection_parameters.get_align_relative_to() in [
		AlignRelativeTo.WORLD_PLANE,
		AlignRelativeTo.CAMERA_PLANE
	]
	_specific_box_container.visible = _align_selection_parameters.get_align_relative_to() \
		== AlignRelativeTo.SPECIFIC_BOX_PLANE
	_align_rotation_button.disabled = not _align_selection_parameters.can_align_rotations()
	_align_camera_button.disabled = _align_selection_parameters.get_align_relative_to() == AlignRelativeTo.CAMERA_PLANE
	for button in _align_position_buttons:
		button.disabled = not _align_selection_parameters.can_align_positions()


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


func _on_prev_face_button_pressed() -> void:
	_advance_specific_box_face(-1)


func _on_next_face_button_pressed() -> void:
	_advance_specific_box_face(+1)


func _advance_specific_box_face(dir: int) -> void:
	assert(_align_selection_parameters.get_align_relative_to() == AlignRelativeTo.SPECIFIC_BOX_PLANE)
	var alignable_objects: Array[StructureContext] = _align_selection_parameters.get_alignable_structure_contexts()
	
	if alignable_objects.size() == 0:
		return
	var current_object_id: int = _align_selection_parameters.get_align_obb_target_id()
	var current_context: StructureContext = null
	for ctx: StructureContext in alignable_objects:
		if ctx.get_int_guid() == current_object_id:
			current_context = ctx
			break
	if current_context == null:
		_align_selection_parameters.set_specific_obb_and_face(alignable_objects[0], BoxFace.FRONT_BACK)
		return
	var current_face: int = _align_selection_parameters.get_align_obb_face() as int
	var select_face: int = current_face + dir
	if select_face < 0 or select_face > 2:
		# advance/wrap face
		select_face = (select_face + 3) % 3
		var obj_index: int = alignable_objects.find(current_context)
		# advance/wrap object
		obj_index = (obj_index + alignable_objects.size() + dir) % alignable_objects.size()
		current_context = alignable_objects[obj_index]
	_align_selection_parameters.set_specific_obb_and_face(current_context, select_face as BoxFace)

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
			new_transform = _align_transform(old_transform, align_basis)
		var delta_transform: Transform3D = old_transform.inverse() * new_transform
		
		var atoms_to_move: PackedInt32Array = []
		var previous_positions: PackedVector3Array = []
		var target_positions: PackedVector3Array = []
		var nmb_of_moved_atoms: int = 0
		for atom_id: int in context.get_selected_atoms():
			var old_pos: Vector3 = nano_structure.atom_get_position(atom_id)
			var new_pos: Vector3 = new_transform * (old_transform.inverse() * old_pos)
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


func _on_align_camera_button_pressed() -> void:
	var align_basis: Basis
	var relative_to: AlignRelativeTo = _align_selection_parameters.get_align_relative_to()
	match relative_to:
		AlignRelativeTo.WORLD_PLANE:
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
		AlignRelativeTo.CAMERA_PLANE:
			assert(false, "Cannot align camera to camera's plane")
			return
	var orientation_widget: Control = (
		_workspace_context.get_editor_viewport()
		.get_orientation_widget()
		.get_node_or_null("DrawOrientationWidget")
	)
	orientation_widget.snap_to_rotation(align_basis.get_euler())


func _align_transform(in_transform: Transform3D, in_align_basis: Basis) -> Transform3D:
	for i in 3:
		var most_aligned_dir: int = -1
		var best_alignment: float = -1.0
		for j in 3:
			var dir: Vector3 = in_transform.basis[i]
			if abs(dir.dot(in_align_basis[j])) > best_alignment:
				best_alignment = abs(dir.dot(in_align_basis[j]))
				most_aligned_dir = j
		in_transform.basis[i] = in_align_basis[most_aligned_dir]
	return in_transform.orthonormalized();


func _on_align_button_pressed(in_h_alignment: Alignment, in_v_alignment: Alignment) -> void:
	var skip_id: int = Workspace.INVALID_OBJECT_INDEX
	var relative_to: AlignRelativeTo = _align_selection_parameters.get_align_relative_to()
	assert(not relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE],
		"Cannot align position to global planes, they dont have boundaries")
	var reference_obb: OBB = _align_selection_parameters.get_align_obb_target()
	var align_transform: Transform3D
	var face: BoxFace = _align_selection_parameters.get_align_obb_face()
	align_transform = _align_selection_parameters.get_align_obb_target().transform
	match face:
		BoxFace.FRONT_BACK:
			pass
		BoxFace.TOP_BOTTOM:
			align_transform = align_transform.rotated_local(align_transform.basis[0], -PI * 0.5)
		BoxFace.LEFT_RIGHT:
			align_transform = align_transform.rotated_local(align_transform.basis[1], PI * 0.5)

	var reference_point: Vector3 # in local space, relative to plane
	match in_h_alignment:
		Alignment.BEGIN:
			reference_point.x = -reference_obb.box.size.x * 0.5
		Alignment.CENTER:
			reference_point.x = 0
		Alignment.END:
			reference_point.x = reference_obb.box.size.x * 0.5
	match in_v_alignment:
		Alignment.BEGIN:
			reference_point.y = reference_obb.box.size.y * 0.5
		Alignment.CENTER:
			reference_point.y = 0
		Alignment.END:
			reference_point.y = -reference_obb.box.size.y * 0.5
	skip_id = _align_selection_parameters.get_align_obb_target_id()
	var something_changed: bool = false
	for context: StructureContext in _align_selection_parameters.get_alignable_structure_contexts():
		if context.get_int_guid() == skip_id:
			continue
		var nano_structure: NanoStructure = context.nano_structure
		var old_transform: Transform3D = context.get_selection_obb().transform
		var box_pos: Vector3 = old_transform.origin
		var box_size: Vector3 = context.get_selection_obb().box.size
		var obj_reference_pos: Vector3
		var box_extents: Array[Vector3] = [
			old_transform * Vector3(-box_size.x * 0.5, 0, 0),
			old_transform * Vector3(box_size.x * 0.5, 0, 0),
			old_transform * Vector3(0, box_size.y * 0.5, 0),
			old_transform * Vector3(0, -box_size.y * 0.5, 0),
			old_transform * Vector3(0, 0, box_size.z * 0.5),
			old_transform * Vector3(0, 0, -box_size.z * 0.5),
		]
		var relative_extents: Array[Vector3] = []
		for extent: Vector3 in box_extents:
			var local_to_ref: Vector3 = align_transform.inverse() * extent
			relative_extents.append(local_to_ref)
		var leftmost_point := Vector3.INF
		var rightmost_point := -Vector3.INF
		var topmost_point := -Vector3.INF
		var bottommost_point := Vector3.INF
		for relative_point: Vector3 in relative_extents:
			if relative_point.x < leftmost_point.x:
				leftmost_point = relative_point
			if relative_point.x > rightmost_point.x:
				rightmost_point = relative_point
			if relative_point.y > topmost_point.y:
				topmost_point = relative_point
			if relative_point.y < bottommost_point.y:
				bottommost_point = relative_point
		match in_h_alignment:
			Alignment.BEGIN:
				obj_reference_pos.x = leftmost_point.x
			Alignment.CENTER:
				obj_reference_pos.x = (align_transform.inverse() * box_pos).x
			Alignment.END:
				obj_reference_pos.x = rightmost_point.x
		match in_v_alignment:
			Alignment.BEGIN:
				obj_reference_pos.y = topmost_point.y
			Alignment.CENTER:
				obj_reference_pos.y = (align_transform.inverse() * box_pos).y
			Alignment.END:
				obj_reference_pos.y = bottommost_point.y
		var plane_offset := Vector3(
			reference_point.x - obj_reference_pos.x,
			reference_point.y - obj_reference_pos.y,
			0.0
		)
		var world_offset: Vector3 = align_transform.basis * plane_offset
		
		var new_transform: Transform3D = old_transform.translated(world_offset)
		var delta_transform: Transform3D = (old_transform.inverse() * new_transform).orthonormalized()
		
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
		_workspace_context.snapshot_moment("Align Selection Position")
