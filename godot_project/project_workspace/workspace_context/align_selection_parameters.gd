extends RefCounted
class_name AlignSelectionParameters


## Emitted when the Align Selection Panel is shown or hidden
signal alignment_tools_enabled_changed(in_enabled: bool)
## Emitted whenever the reference changes, be it the kind of target,
## (world plane, box side, etc) or the selected target (biggest plane
## changed or user selected changed)
signal align_relative_to_changed()
## Emitted when the picker button is pressed in the AlignSelectionPalen is pressed
signal pick_specific_obb_requested()


enum AlignRelativeTo {
	WORLD_PLANE,
	CAMERA_PLANE,
	BIGGEST_BOX_PLANE,
	SPECIFIC_BOX_PLANE,
}

enum WorldPlane {
	XY,
	XZ,
	YZ,
}

enum BoxFace {
	UNDEFINED = -1,
	FRONT_BACK = WorldPlane.XY,
	TOP_BOTTOM = WorldPlane.XZ,
	LEFT_RIGHT = WorldPlane.YZ,
}

var _align_relative_to: AlignRelativeTo
var _selected_world_plane: WorldPlane
var _align_to_group_int_guid: int = Workspace.INVALID_OBJECT_INDEX
var _align_to_group_box_face := BoxFace.UNDEFINED
var _biggest_obb: OBB = null
var _biggest_obb_group_id: int = Workspace.INVALID_OBJECT_INDEX
var _biggest_obb_box_face := BoxFace.UNDEFINED
var _workspace_context: WorkspaceContext


func _init(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context
	_workspace_context.history_changed.connect(_on_workspace_history_changed)


func set_alignment_tools_enabled(in_enabled: bool) -> void:
	alignment_tools_enabled_changed.emit(in_enabled)


func can_align_selection() -> bool:
	return get_alignable_structure_contexts().size() > 0


func get_alignable_structure_contexts() -> Array[StructureContext]:
	var selected_groups: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
	var active_group_id: int = _workspace_context.get_current_structure_context().get_int_guid()
	selected_groups.filter(func(context: StructureContext) -> bool:
		return context.nano_structure.int_parent_guid == active_group_id
	)
	return selected_groups


func can_align_rotations() -> bool:
	var alignable_objects: Array[StructureContext] = get_alignable_structure_contexts()
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		return alignable_objects.size() >= 1
	elif _align_relative_to == AlignRelativeTo.BIGGEST_BOX_PLANE:
		return alignable_objects.size() >= 2
	elif _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
		if alignable_objects.size() < 2 or _align_to_group_int_guid == Workspace.INVALID_OBJECT_INDEX:
			return false
		for ctx: StructureContext in alignable_objects:
			if _align_to_group_int_guid  == ctx.get_int_guid():
				return true
		return false
	assert(false, "unknown align relative to target %d" % [_align_relative_to])
	return false


func can_align_positions() -> bool:
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		# World planes doesn't have bounds
		return false
	# For the rest, the rules are the same as rotations
	return can_align_rotations()


func get_align_relative_to() -> AlignRelativeTo:
	return _align_relative_to


func set_align_relative_to(in_relative_to: AlignRelativeTo) -> void:
	if _align_relative_to == in_relative_to:
		return
	_align_relative_to = in_relative_to
	align_relative_to_changed.emit()


func get_align_to_what_plane() -> WorldPlane:
	return _selected_world_plane


func set_align_to_what_plane(in_plane: WorldPlane) -> void:
	if _selected_world_plane == in_plane:
		return
	_selected_world_plane = in_plane
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		align_relative_to_changed.emit()


func get_align_obb_target_id() -> int:
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		return Workspace.INVALID_OBJECT_INDEX
	elif _align_relative_to == AlignRelativeTo.BIGGEST_BOX_PLANE:
		if _biggest_obb == null:
			_find_biggest_obb()
		return _biggest_obb_group_id
	elif _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
		if not _workspace_context.workspace.has_structure_with_int_guid(_align_to_group_int_guid):
			return Workspace.INVALID_OBJECT_INDEX
		_align_to_group_int_guid
	assert(false, "unknown align relative to target %d" % [_align_relative_to])
	return Workspace.INVALID_OBJECT_INDEX


func get_align_obb_target() -> OBB:
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		return null
	elif _align_relative_to == AlignRelativeTo.BIGGEST_BOX_PLANE:
		if _biggest_obb == null:
			_find_biggest_obb()
		return _biggest_obb
	elif _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
		if not _workspace_context.workspace.has_structure_with_int_guid(_align_to_group_int_guid):
			return null
		_workspace_context.get_structure_context(_align_to_group_int_guid).get_selection_obb()
	assert(false, "unknown align relative to target %d" % [_align_relative_to])
	return null


func get_align_obb_face() -> BoxFace:
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		return BoxFace.UNDEFINED
	elif _align_relative_to == AlignRelativeTo.BIGGEST_BOX_PLANE:
		if _biggest_obb == null:
			_find_biggest_obb()
		return _biggest_obb_box_face
	elif _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
		if not _workspace_context.workspace.has_structure_with_int_guid(_align_to_group_int_guid):
			return BoxFace.UNDEFINED
		_align_to_group_box_face
	assert(false, "unknown align relative to target %d" % [_align_relative_to])
	return BoxFace.UNDEFINED


func start_picking_obb() -> void:
	pick_specific_obb_requested.emit()


func set_specific_obb_and_face(in_context: StructureContext, in_face: BoxFace) -> void:
	var id: int = Workspace.INVALID_OBJECT_INDEX if in_context == null else in_context.get_int_guid()
	if _align_to_group_int_guid != id or _align_to_group_box_face != in_face:
		_align_to_group_int_guid = id
		_align_to_group_box_face = in_face
		if _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
			align_relative_to_changed.emit()


func _find_biggest_obb() -> void:
	_biggest_obb = null
	_biggest_obb_box_face = BoxFace.UNDEFINED
	_biggest_obb_group_id = Workspace.INVALID_OBJECT_INDEX
	var alignable_objects: Array[StructureContext] = get_alignable_structure_contexts()
	if alignable_objects.size() == 0:
		return
	var biggest_face_area: float = 0
	for context: StructureContext in alignable_objects:
		var obb: OBB = context.get_selection_obb()
		var size: Vector3 = obb.box.size
		var top_face_area: float = size.x * size.z
		if top_face_area > biggest_face_area:
			biggest_face_area = top_face_area
			_biggest_obb = obb
			_biggest_obb_group_id = context.get_int_guid()
			_biggest_obb_box_face = BoxFace.TOP_BOTTOM
		var front_face_area: float = size.x * size.y
		if front_face_area > biggest_face_area:
			biggest_face_area = front_face_area
			_biggest_obb = obb
			_biggest_obb_group_id = context.get_int_guid()
			_biggest_obb_box_face = BoxFace.FRONT_BACK
		var side_face_area: float = size.y * size.z
		if side_face_area > biggest_face_area:
			biggest_face_area = side_face_area
			_biggest_obb = obb
			_biggest_obb_group_id = context.get_int_guid()
			_biggest_obb_box_face = BoxFace.LEFT_RIGHT
	return


func _on_workspace_history_changed() -> void:
	_biggest_obb = null
	_biggest_obb_group_id = Workspace.INVALID_OBJECT_INDEX
