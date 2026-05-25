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

enum AlignSelectionGroupingPolicy {
	OneBoxPerGroup,
	OneBoxPerSubgroup,
	OneBoxPerMolecule,
}

const INVALID_BOX_INDEX: int = -1

var _align_relative_to: AlignRelativeTo
var _selected_world_plane: WorldPlane
var _align_selection_grouping_policy := AlignSelectionGroupingPolicy.OneBoxPerSubgroup
var _alignable_boxes: Array[OBB] = []
var _align_to_box_index: int = INVALID_BOX_INDEX
var _align_to_face := BoxFace.UNDEFINED
var _biggest_obb: OBB = null
var _biggest_obb_box_face := BoxFace.UNDEFINED
var _workspace_context: WorkspaceContext


func _init(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context
	_workspace_context.history_changed.connect(_on_workspace_history_changed)


func set_alignment_tools_enabled(in_enabled: bool) -> void:
	alignment_tools_enabled_changed.emit(in_enabled)


func can_align_selection() -> bool:
	return get_alignable_boxes().size() > 0


func get_alignable_structure_contexts() -> Array[StructureContext]:
	var include_empty: bool = _align_selection_grouping_policy == AlignSelectionGroupingPolicy.OneBoxPerGroup
	var selected_groups: Array[StructureContext] = \
		_workspace_context.get_structure_contexts_with_selection(include_empty)
	var active_group_id: int = _workspace_context.get_current_structure_context().get_int_guid()
	if _align_selection_grouping_policy == AlignSelectionGroupingPolicy.OneBoxPerGroup:
		selected_groups = selected_groups.filter(func(context: StructureContext) -> bool:
			return (
				context.nano_structure.int_guid == active_group_id
				or context.nano_structure.int_parent_guid == active_group_id
			)
		)
	return selected_groups


func get_alignable_boxes() -> Array[OBB]:
	if _alignable_boxes.is_empty() and not _alignable_boxes.is_read_only():
		var alignable_objects: Array[StructureContext] = get_alignable_structure_contexts()
		for context: StructureContext in alignable_objects:
			_alignable_boxes.append_array(
				context.get_selection_obb_with_selection_policy(_align_selection_grouping_policy)
			)
		_alignable_boxes.make_read_only()
	return _alignable_boxes


func can_align_rotations() -> bool:
	var alignable_boxes: Array[OBB] = get_alignable_boxes()
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		return alignable_boxes.size() >= 1
	elif _align_relative_to == AlignRelativeTo.BIGGEST_BOX_PLANE:
		return alignable_boxes.size() >= 2
	elif _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
		if alignable_boxes.size() < 2:
			return false
		if _align_to_box_index >= 0 and _align_to_box_index < alignable_boxes.size():
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
	_alignable_boxes = []
	align_relative_to_changed.emit()


func get_align_selection_grouping_policy() -> AlignSelectionGroupingPolicy:
	return _align_selection_grouping_policy


func set_align_selection_grouping_policy(in_policy: AlignSelectionGroupingPolicy) -> void:
	if in_policy == _align_selection_grouping_policy:
		return
	_align_selection_grouping_policy = in_policy
	_biggest_obb = null
	_alignable_boxes = []
	align_relative_to_changed.emit()


func get_align_to_what_plane() -> WorldPlane:
	return _selected_world_plane


func set_align_to_what_plane(in_plane: WorldPlane) -> void:
	if _selected_world_plane == in_plane:
		return
	_selected_world_plane = in_plane
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		align_relative_to_changed.emit()


func get_align_obb_target() -> OBB:
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		return null
	elif _align_relative_to == AlignRelativeTo.BIGGEST_BOX_PLANE:
		if get_alignable_boxes().size() == 0:
			return null
		if _biggest_obb == null:
			_find_biggest_obb()
		return _biggest_obb
	elif _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
		if _align_to_box_index >= 0 and _align_to_box_index < get_alignable_boxes().size():
			return _alignable_boxes[_align_to_box_index]
		return null
	assert(false, "unknown align relative to target %d" % [_align_relative_to])
	return null


func get_align_obb_face() -> BoxFace:
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		return BoxFace.UNDEFINED
	elif _align_relative_to == AlignRelativeTo.BIGGEST_BOX_PLANE:
		if get_alignable_boxes().size() == 0:
			return BoxFace.UNDEFINED
		if _biggest_obb == null:
			_find_biggest_obb()
		return _biggest_obb_box_face
	elif _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
		if _align_to_box_index >= 0 and _align_to_box_index < get_alignable_boxes().size():
			return _align_to_face
		return BoxFace.UNDEFINED
	assert(false, "unknown align relative to target %d" % [_align_relative_to])
	return BoxFace.UNDEFINED


func start_picking_obb() -> void:
	pick_specific_obb_requested.emit()


func set_specific_obb_and_face(in_box: OBB, in_face: BoxFace) -> void:
	var id: int = -1 if in_box == null else _alignable_boxes.find(in_box)
	if _align_to_box_index != id or _align_to_face != in_face:
		_align_to_box_index = id
		_align_to_face = in_face
		if _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
			align_relative_to_changed.emit()


func _find_biggest_obb() -> void:
	_biggest_obb = null
	_biggest_obb_box_face = BoxFace.UNDEFINED
	var alignable_boxes: Array[OBB] = get_alignable_boxes()
	if alignable_boxes.size() == 0:
		return
	var biggest_face_area: float = 0
	for obb: OBB in alignable_boxes:
		var size: Vector3 = obb.box.size
		var top_face_area: float = size.x * size.z
		if top_face_area > biggest_face_area:
			biggest_face_area = top_face_area
			_biggest_obb = obb
			_biggest_obb_box_face = BoxFace.TOP_BOTTOM
		var front_face_area: float = size.x * size.y
		if front_face_area > biggest_face_area:
			biggest_face_area = front_face_area
			_biggest_obb = obb
			_biggest_obb_box_face = BoxFace.FRONT_BACK
		var side_face_area: float = size.y * size.z
		if side_face_area > biggest_face_area:
			biggest_face_area = side_face_area
			_biggest_obb = obb
			_biggest_obb_box_face = BoxFace.LEFT_RIGHT
	return


func _on_workspace_history_changed() -> void:
	_biggest_obb = null
	_alignable_boxes = []
