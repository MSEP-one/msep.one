extends DynamicContextControl

const AlignSelectionGroupingPolicy = AlignSelectionParameters.AlignSelectionGroupingPolicy
const AlignRelativeTo = AlignSelectionParameters.AlignRelativeTo
const WorldPlane = AlignSelectionParameters.WorldPlane
const BoxFace = AlignSelectionParameters.BoxFace

enum Alignment {
	IGNORE = -1,
	BEGIN,
	CENTER,
	END,
}

var _alignable_boxes_tree: Tree
var _relative_to_option_button: OptionButton
var _world_plane_container: HBoxContainer
var _plane_button_group: ButtonGroup
var _specific_box_container: HBoxContainer
var _prev_face_button: Button
var _next_face_button: Button
var _grouping_policy_option_button: OptionButton
var _align_rotation_button: Button
var _align_camera_button: Button
var _align_position_buttons: Array[Button]

var _workspace_context: WorkspaceContext = null
var _align_selection_parameters: AlignSelectionParameters


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(in_workspace_context)
	if _align_selection_parameters.can_align_selection():
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
		_alignable_boxes_tree = %AlignableBoxesTree as Tree
		_relative_to_option_button = %RelativeToOptionButton as OptionButton
		_world_plane_container = %WorldPlaneContainer as HBoxContainer
		_plane_button_group = (%XY as Button).button_group
		
		_specific_box_container = %SpecificBoxContainer as HBoxContainer
		_prev_face_button = %PrevFaceButton as Button
		_next_face_button = %NextFaceButton as Button
		
		_alignable_boxes_tree.button_clicked.connect(_on_alignable_boxes_tree_button_clicked)
		_alignable_boxes_tree.item_activated.connect(_alignable_boxes_tree_item_activated)
		_relative_to_option_button.item_selected.connect(_on_relative_to_option_button_item_selected)
		_plane_button_group.pressed.connect(_on_plane_button_group_pressed)
		_prev_face_button.pressed.connect(_on_prev_face_button_pressed)
		_next_face_button.pressed.connect(_on_next_face_button_pressed)
		
		_grouping_policy_option_button = %GroupingPolicyOptionButton as OptionButton
		_grouping_policy_option_button.item_selected.connect(_on_grouping_policy_option_button_item_selected)
		
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
	_update_tree()
	_world_plane_container.visible = _align_selection_parameters.get_align_relative_to() in [
		AlignRelativeTo.WORLD_PLANE,
		AlignRelativeTo.CAMERA_PLANE
	]
	_specific_box_container.visible = _align_selection_parameters.get_align_relative_to() \
		== AlignRelativeTo.SPECIFIC_BOX_PLANE
	_align_rotation_button.disabled = not _align_selection_parameters.can_align_rotations()
	var can_align_camera: bool = true
	if _align_selection_parameters.get_align_relative_to() == AlignRelativeTo.CAMERA_PLANE:
		can_align_camera = false
	elif _align_selection_parameters.get_align_relative_to() == AlignRelativeTo.SPECIFIC_BOX_PLANE:
		var reference_box: AlignableOBB = _align_selection_parameters.get_align_obb_target()
		if reference_box == null or reference_box.selected_face == BoxFace.UNDEFINED:
			can_align_camera = false
	_align_camera_button.disabled = not can_align_camera
	for button in _align_position_buttons:
		button.disabled = not _align_selection_parameters.can_align_positions()


var _last_alignable_boxes: Array[AlignableOBB] = []
func _update_tree() -> void:
	var alignable_boxes: Array[AlignableOBB] = _align_selection_parameters.get_alignable_boxes()
	if alignable_boxes == _last_alignable_boxes:
		_refresh_tree_items()
		# No need to update
		return
	_last_alignable_boxes = alignable_boxes
	var current_box: AlignableOBB = _align_selection_parameters.get_align_obb_target()
	_alignable_boxes_tree.clear()
	_alignable_boxes_tree.hide_root = true
	var root: TreeItem = _alignable_boxes_tree.create_item()
	for box: AlignableOBB in alignable_boxes:
		var is_current: bool = box == current_box
		var item: TreeItem = _alignable_boxes_tree.create_item(root)
		const COL_0 = 0
		item.set_metadata(COL_0, box)
		item.set_text(COL_0, box.description)
		if is_current:
			const COLOR_SELECTED := Color.YELLOW
			item.set_custom_color(COL_0, COLOR_SELECTED)
		var selected_face: BoxFace = box.align_to_face if is_current else box.selected_face
		item.add_button(COL_0, _get_box_face_icon(selected_face),
			-1, false, tr(&"Select next face"))


func _refresh_tree_items() -> void:
	const COL_0 = 0
	const BUTTON_IDX = 0
	var current_box: AlignableOBB = _align_selection_parameters.get_align_obb_target()
	for item: TreeItem in _alignable_boxes_tree.get_root().get_children():
		var item_box: AlignableOBB = item.get_metadata(COL_0) as AlignableOBB
		assert(item_box)
		if item_box == current_box and current_box != null:
			item.set_custom_color(COL_0, Color.YELLOW)
			item.set_button(COL_0, BUTTON_IDX, _get_box_face_icon(item_box.align_to_face))
		else:
			item.clear_custom_color(COL_0)
			item.set_button(COL_0, BUTTON_IDX, _get_box_face_icon(item_box.selected_face))


func _on_alignable_boxes_tree_button_clicked(item: TreeItem, _column: int, id: int, mouse_button_index: int) -> void:
	const COL_0 = 0
	var alignable_box: AlignableOBB = item.get_metadata(COL_0) as AlignableOBB
	assert(alignable_box)
	var advance_dir: int = 0
	match mouse_button_index:
		MOUSE_BUTTON_LEFT:
			advance_dir = +1
		MOUSE_BUTTON_RIGHT:
			advance_dir = -1
	if advance_dir == 0:
		return
	var is_current: bool = item.get_custom_color(COL_0) == Color.YELLOW
	if is_current:
		alignable_box.advance_align_to_face(advance_dir)
	else:
		alignable_box.advance_selected_face(advance_dir)
	var selected_face: BoxFace = alignable_box.align_to_face if is_current else alignable_box.selected_face
	item.set_button(COL_0, id, _get_box_face_icon(selected_face))
	# Force redraw preview
	_align_selection_parameters.align_relative_to_changed.emit()


func _alignable_boxes_tree_item_activated() -> void:
	if _align_selection_parameters.get_align_relative_to() != AlignRelativeTo.SPECIFIC_BOX_PLANE:
		_relative_to_option_button.select(int(AlignRelativeTo.SPECIFIC_BOX_PLANE))
		_relative_to_option_button.item_selected.emit(int(AlignRelativeTo.SPECIFIC_BOX_PLANE))
	var selected_item: TreeItem = _alignable_boxes_tree.get_selected()
	if selected_item == null:
		return
	const COL_0 = 0
	var box: AlignableOBB = selected_item.get_metadata(COL_0)
	if box != null:
		_align_selection_parameters.set_specific_obb(box)


func _get_box_face_icon(selected_face: BoxFace) -> Texture2D:
	const ICONS: Dictionary[BoxFace, Texture2D] = {
		BoxFace.UNDEFINED : preload("uid://dr6k8q285dgls"),
		BoxFace.FRONT_BACK : preload("uid://d16yxekfb4k3h"),
		BoxFace.TOP_BOTTOM : preload("uid://de1hnqihu4ugw"),
		BoxFace.LEFT_RIGHT : preload("uid://c01w40g4dq4eg"),
	}
	return ICONS[selected_face]


func _on_relative_to_option_button_item_selected(in_index: int) -> void:
	_align_selection_parameters.set_align_relative_to(
		in_index as AlignRelativeTo
	)


func _on_plane_button_group_pressed(in_button: Button) -> void:
	_align_selection_parameters.set_align_to_what_plane(
		in_button.get_index() as WorldPlane
	)


func _on_prev_face_button_pressed() -> void:
	_advance_specific_box(-1)


func _on_next_face_button_pressed() -> void:
	_advance_specific_box(+1)


func _on_grouping_policy_option_button_item_selected(index: int) -> void:
	_align_selection_parameters.set_align_selection_grouping_policy(index as AlignSelectionGroupingPolicy)


func _advance_specific_box(dir: int) -> void:
	assert(_align_selection_parameters.get_align_relative_to() == AlignRelativeTo.SPECIFIC_BOX_PLANE)
	var alignable_boxes: Array[AlignableOBB] = _align_selection_parameters.get_alignable_boxes()
	
	if alignable_boxes.size() == 0:
		return
	var current_box: OBB = _align_selection_parameters.get_align_obb_target()
	if current_box == null:
		_align_selection_parameters.set_specific_obb_and_face(alignable_boxes[0], BoxFace.FRONT_BACK)
		return
	var box_index: int = alignable_boxes.find(current_box)
	box_index = (box_index + alignable_boxes.size() + dir) % alignable_boxes.size()
	current_box = alignable_boxes[box_index]
	_align_selection_parameters.set_specific_obb(current_box)


func _on_align_rotation_button_pressed() -> void:
	var align_basis: Basis
	var relative_to: AlignRelativeTo = _align_selection_parameters.get_align_relative_to()
	var alignable_boxes: Array[AlignableOBB] = _align_selection_parameters.get_alignable_boxes()
	var something_changed: bool = false
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
			for i: int in alignable_boxes.size():
				something_changed = something_changed or alignable_boxes[i].align_rotation_to_basis(align_basis)
		AlignRelativeTo.SPECIFIC_BOX_PLANE:
			var align_target: AlignableOBB = _align_selection_parameters.get_align_obb_target()
			for i: int in alignable_boxes.size():
				something_changed = something_changed or alignable_boxes[i].align_rotation_to_box(align_target)
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
		AlignRelativeTo.SPECIFIC_BOX_PLANE:
			align_basis = _align_selection_parameters.get_align_obb_target().transform.basis
			var face: BoxFace = _align_selection_parameters.get_align_obb_target().selected_face
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


func _on_align_button_pressed(in_h_alignment: Alignment, in_v_alignment: Alignment) -> void:
	var skip_idx: int = AlignSelectionParameters.INVALID_BOX_INDEX
	var relative_to: AlignRelativeTo = _align_selection_parameters.get_align_relative_to()
	assert(not relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE],
		"Cannot align position to global planes, they dont have boundaries")
	var reference_obb: AlignableOBB = _align_selection_parameters.get_align_obb_target()
	var align_transform: Transform3D
	var face: BoxFace = reference_obb.selected_face
	align_transform = _align_selection_parameters.get_align_obb_target().transform
	var h_axis: int = Vector3.AXIS_X
	var v_axis: int = Vector3.AXIS_Y
	match face:
		BoxFace.FRONT_BACK:
			pass
		BoxFace.TOP_BOTTOM:
			v_axis = Vector3.AXIS_Z
			#align_transform = align_transform.rotated_local(align_transform.basis[0], PI * 0.5)
		BoxFace.LEFT_RIGHT:
			h_axis = Vector3.AXIS_Z
			#align_transform = align_transform.rotated_local(align_transform.basis[1], -PI * 0.5)

	var reference_point: Vector3 # in local space, relative to plane
	match in_h_alignment:
		Alignment.BEGIN:
			reference_point[h_axis] = -reference_obb.box.size[h_axis] * 0.5
		Alignment.CENTER:
			reference_point[h_axis] = 0
		Alignment.END:
			reference_point[h_axis] = reference_obb.box.size[h_axis] * 0.5
	match in_v_alignment:
		Alignment.BEGIN:
			reference_point[v_axis] = reference_obb.box.size[v_axis] * 0.5
		Alignment.CENTER:
			reference_point[v_axis] = 0
		Alignment.END:
			reference_point[v_axis] = -reference_obb.box.size[v_axis] * 0.5
	var alignable_boxes: Array[AlignableOBB] = _align_selection_parameters.get_alignable_boxes()
	skip_idx = alignable_boxes.find(_align_selection_parameters.get_align_obb_target())
	var something_changed: bool = false
	for i: int in alignable_boxes.size():
		if i == skip_idx:			continue
		var obb: OBB = alignable_boxes[i]
		for context: StructureContext in obb.point_cloud_source.keys():
			var nano_structure: NanoStructure = context.nano_structure
			var old_transform: Transform3D = obb.transform
			var box_pos: Vector3 = old_transform.origin
			var box_size: Vector3 = obb.box.size
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
				if relative_point[h_axis] < leftmost_point[h_axis]:
					leftmost_point = relative_point
				if relative_point[h_axis] > rightmost_point[h_axis]:
					rightmost_point = relative_point
				if relative_point[v_axis] > topmost_point[v_axis]:
					topmost_point = relative_point
				if relative_point[v_axis] < bottommost_point[v_axis]:
					bottommost_point = relative_point
			match in_h_alignment:
				Alignment.BEGIN:
					obj_reference_pos[h_axis] = leftmost_point[h_axis]
				Alignment.CENTER:
					obj_reference_pos[h_axis] = (align_transform.inverse() * box_pos)[h_axis]
				Alignment.END:
					obj_reference_pos[h_axis] = rightmost_point[h_axis]
			match in_v_alignment:
				Alignment.BEGIN:
					obj_reference_pos[v_axis] = topmost_point[v_axis]
				Alignment.CENTER:
					obj_reference_pos[v_axis] = (align_transform.inverse() * box_pos)[v_axis]
				Alignment.END:
					obj_reference_pos[v_axis] = bottommost_point[v_axis]
			var plane_offset := Vector3()
			plane_offset[h_axis] = reference_point[h_axis] - obj_reference_pos[h_axis]
			plane_offset[v_axis] = reference_point[v_axis] - obj_reference_pos[v_axis]
			var world_offset: Vector3 = align_transform.basis * plane_offset
			
			var new_transform: Transform3D = old_transform.translated(world_offset)
			var to_local: Transform3D = old_transform.inverse()
			var delta_transform: Transform3D = (to_local * new_transform).orthonormalized()
			
			var atoms_to_move: PackedInt32Array = []
			var previous_positions: PackedVector3Array = []
			var target_positions: PackedVector3Array = []
			var nmb_of_moved_atoms: int = 0
			for atom_id: int in obb.point_cloud_source[context]:
				var old_pos: Vector3 = nano_structure.atom_get_position(atom_id)
				var new_pos: Vector3 = new_transform * (to_local * old_pos)
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
