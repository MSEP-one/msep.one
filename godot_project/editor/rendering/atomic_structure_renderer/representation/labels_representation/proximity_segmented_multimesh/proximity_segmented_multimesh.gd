extends SegmentedMultimesh


# used to distribute the check over many frames, it's quite cheap but there is no need for it to do
# all the work each frame
const MAX_NMB_OF_SEGMENTS_TO_CHECK_IN_ONE_FRAME: int = 5


var _segment_start_idx: int = 0
var _orthogonal_fade_out_at_distance: float
var _max_segment_visibility_distance_sqr: float


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		var _fade_out_at_distance: float = _material_override.get_shader_parameter("distance_fade_min")
		_orthogonal_fade_out_at_distance = _fade_out_at_distance * 0.3
		_max_segment_visibility_distance_sqr = ((SEGMENT_SIZE * 0.5) + _fade_out_at_distance) ** 2.0


func update(_delta: float) -> void:
	_proximity_visibility_step()


func _proximity_visibility_step() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var is_orthogonal: bool = camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var all_segments: Array = _id_to_segment_map.values() #type is: Array[Segment]
	var last_segment_to_check_this_frame: int = _segment_start_idx + MAX_NMB_OF_SEGMENTS_TO_CHECK_IN_ONE_FRAME
	var reached_end: bool = last_segment_to_check_this_frame >= (all_segments.size() - 1)
	if reached_end:
		last_segment_to_check_this_frame = all_segments.size() - 1
	
	for idx_segment_to_check in range(_segment_start_idx, last_segment_to_check_this_frame + 1):
		var segment: Segment = all_segments[idx_segment_to_check]
		var segment_sqr_distance_to_camera: float = segment.multimesh_instance.global_position.distance_squared_to(camera.global_position)
		var is_segment_visible: bool
		if is_orthogonal:
			is_segment_visible = camera.size < _orthogonal_fade_out_at_distance
		else:
			is_segment_visible = segment_sqr_distance_to_camera < _max_segment_visibility_distance_sqr
		segment.multimesh_instance.set_visible(is_segment_visible)
	
	_segment_start_idx = last_segment_to_check_this_frame + 1
	if _segment_start_idx == all_segments.size():
		_segment_start_idx = 0


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = super.create_state_snapshot()
	state_snapshot["_segment_start_idx"] = _segment_start_idx
	state_snapshot["_orthogonal_fade_out_at_distance"] = _orthogonal_fade_out_at_distance
	state_snapshot["_max_segment_visibility_distance_sqr"] = _max_segment_visibility_distance_sqr
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_state_snapshot)
	_segment_start_idx = in_state_snapshot["_segment_start_idx"]
	_orthogonal_fade_out_at_distance = in_state_snapshot["_orthogonal_fade_out_at_distance"]
	_max_segment_visibility_distance_sqr = in_state_snapshot["_max_segment_visibility_distance_sqr"]
