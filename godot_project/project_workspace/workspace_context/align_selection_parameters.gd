extends RefCounted
class_name AlignSelectionParameters


## Emitted when the Align Selection Panel is shown or hidden
signal alignment_tools_enabled_changed(in_enabled: bool)
## Emitted whenever the reference changes, be it the kind of target,
## (world plane, box side, etc) or the selected target (biggest plane
## changed or user selected changed)
signal align_relative_to_changed()
## Emitted when soem change in the UI requires the viewport preview to be redrawn
signal redraw_preview_requested()

enum AlignRelativeTo {
	WORLD_PLANE,
	CAMERA_PLANE,
	SPECIFIC_BOX_PLANE,
}

enum WorldPlane {
	XY,
	XZ,
	YZ,
}


enum AlignSelectionGroupingPolicy {
	OneBoxPerGroup,
	OneBoxPerSubgroup,
	OneBoxPerMolecule,
}


const BoxFace = AlignableOBB.BoxFace


const INVALID_BOX_INDEX: int = -1

var _align_relative_to: AlignRelativeTo = AlignRelativeTo.SPECIFIC_BOX_PLANE
var _selected_world_plane: WorldPlane
var _align_selection_grouping_policy := AlignSelectionGroupingPolicy.OneBoxPerSubgroup
var _alignable_boxes: Array[AlignableOBB] = []
var _align_to_box_index: int = INVALID_BOX_INDEX
var _align_depth_enabled: bool = true
var _workspace_context: WorkspaceContext


func _init(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context
	_workspace_context.history_changed.connect(_on_workspace_history_changed)


func request_redraw_preview() -> void:
	redraw_preview_requested.emit()


func set_alignment_tools_enabled(in_enabled: bool) -> void:
	alignment_tools_enabled_changed.emit(in_enabled)


func can_align_selection() -> bool:
	return count_alignable_boxes() > 0


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


func count_alignable_boxes() -> int:
	if not _alignable_boxes.is_empty() or _alignable_boxes.is_read_only():
		return _alignable_boxes.size()
	var alignable_objects: Array[StructureContext] = get_alignable_structure_contexts()
	var count: int = 0
	for context: StructureContext in alignable_objects:
		count += context.count_obb_with_selection_policy(_align_selection_grouping_policy)
	return count


var _previous_query: Dictionary[int, Array] = {
	# int_guid = Array[AlignableOBB]
}
func get_alignable_boxes() -> Array[AlignableOBB]:
	if _alignable_boxes.is_empty() and not _alignable_boxes.is_read_only():
		var alignable_objects: Array[StructureContext] = get_alignable_structure_contexts()
		var this_query: Dictionary[int, Array] = {}
		for context: StructureContext in alignable_objects:
			this_query[context.get_int_guid()] = []
			var group_boxes: Array[OBB] = context.get_selection_obb_with_selection_policy(_align_selection_grouping_policy)
			for i in group_boxes.size():
				var description: String = context.nano_structure.get_structure_name()
				if group_boxes.size() > 1:
					description += " Molecule %d" % [i + 1]
				var alignable_box: AlignableOBB = AlignableOBB.from_obb(group_boxes[i], description, self)
				if _previous_query.get(context.get_int_guid(), []).size() > i:
					var selected_face: BoxFace = _previous_query[context.get_int_guid()][i].selected_face
					var align_to_face: BoxFace = _previous_query[context.get_int_guid()][i].align_to_face
					if alignable_box.has_face(selected_face):
						alignable_box.selected_face = selected_face
					if alignable_box.has_face(align_to_face):
						alignable_box.align_to_face = align_to_face
					alignable_box.offset_ratio_h = _previous_query[context.get_int_guid()][i].offset_ratio_h
					alignable_box.offset_ratio_v = _previous_query[context.get_int_guid()][i].offset_ratio_v
					alignable_box.offset_ratio_d = _previous_query[context.get_int_guid()][i].offset_ratio_d
					alignable_box.align_to_center_of_mass = _previous_query[context.get_int_guid()][i].align_to_center_of_mass
				this_query[context.get_int_guid()].append(alignable_box)
				_alignable_boxes.append(alignable_box)
		_previous_query = this_query
		_previous_query.make_read_only()
		_alignable_boxes.make_read_only()
	return _alignable_boxes


func can_align_rotations() -> bool:
	var alignable_boxes: Array[AlignableOBB] = get_alignable_boxes()
	if alignable_boxes.is_empty():
		return false
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		for box: AlignableOBB in alignable_boxes:
			if box.selected_face != BoxFace.UNDEFINED:
				return true
		return false
	elif _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
		var current_box: AlignableOBB = get_align_obb_target()
		if current_box == null:
			return false
		for box: AlignableOBB in alignable_boxes:
			if box != current_box and box.selected_face != BoxFace.UNDEFINED:
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


func is_advanced_settings_enabled() -> bool:
	return _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE


func get_align_relative_to() -> AlignRelativeTo:
	return _align_relative_to


func set_align_relative_to(in_relative_to: AlignRelativeTo) -> void:
	if _align_relative_to == in_relative_to:
		return
	_align_relative_to = in_relative_to
	align_relative_to_changed.emit()


func get_align_selection_grouping_policy() -> AlignSelectionGroupingPolicy:
	return _align_selection_grouping_policy


func set_align_selection_grouping_policy(in_policy: AlignSelectionGroupingPolicy) -> void:
	if in_policy == _align_selection_grouping_policy:
		return
	_align_selection_grouping_policy = in_policy
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


func set_align_depth_enabled(in_enabled: bool) -> void:
	if in_enabled == _align_depth_enabled:
		return
	_align_depth_enabled = in_enabled
	request_redraw_preview()


func is_align_depth_enabled() -> bool:
	return _align_depth_enabled


func get_align_obb_target() -> AlignableOBB:
	if _align_relative_to in [AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE]:
		return null
	elif _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE and get_alignable_boxes().size():
		if _align_to_box_index < 0 or _align_to_box_index >= get_alignable_boxes().size():
			_align_to_box_index = 0
		return _alignable_boxes[_align_to_box_index]
	assert(false, "unknown align relative to target %d" % [_align_relative_to])
	return null


func set_specific_obb(out_box: AlignableOBB) -> void:
	var id: int = -1 if out_box == null else _alignable_boxes.find(out_box)
	if _align_to_box_index != id:
		_align_to_box_index = id
		if out_box.selected_face == BoxFace.UNDEFINED:
			out_box.align_to_face = BoxFace.XY
			if not out_box.has_face(BoxFace.XY):
				out_box.advance_align_to_face(1)
		else:
			out_box.align_to_face = out_box.selected_face
		if _align_relative_to == AlignRelativeTo.SPECIFIC_BOX_PLANE:
			align_relative_to_changed.emit()


func _on_workspace_history_changed() -> void:
	_alignable_boxes = []
