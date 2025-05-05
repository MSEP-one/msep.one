class_name SimulationData extends RefCounted


enum Status {
	REQUESTING,
	RUNNING,
	ABORTED,
}

signal frame_received(time: float, state: PackedVector3Array)
signal invalid_state_received()


var _last_seeked_time: float = -1.0
var _last_seeked_state: PackedVector3Array = []

var id: int: get = _get_simulation_id
var start_promise := Promise.new()
var parameters: SimulationParameters = null:
	set = _set_parameters_once
var original_payload: OpenMMPayload = null
var _has_error: bool = false
var _status := Status.REQUESTING
var frames: Dictionary = {
	# time:float = positions:PackedVector3Array
}

func _init(in_parameters: SimulationParameters) -> void:
	parameters = in_parameters
	_track_start_promise_error()


func _track_start_promise_error() -> void:
	await start_promise.wait_for_fulfill()
	if start_promise.has_error() and _status == Status.REQUESTING:
		_has_error = true
		_status = Status.RUNNING


func push_frame(in_time: float, in_positions: PackedVector3Array) -> void:
	if _has_error:
		# ignore incomming frames after an error was detected
		return
	if _status == Status.REQUESTING and in_time > 0:
		# push frame happens in a thread, use call deferred for fulfilling the start promise
		start_promise.fulfill.call_deferred(true)
		_status = Status.RUNNING
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		# Only run in the main thread
		push_frame.bind(in_time, in_positions).call_deferred()
		return
	for p in in_positions:
		if is_nan(p.x) || is_nan(p.y) || is_nan(p.z) || p.length_squared() > 3e18:
			invalidate()
			return
	frames[in_time] = in_positions
	frame_received.emit(in_time, in_positions)


func abort() -> void:
	_status = Status.ABORTED


func was_aborted() -> bool:
	return _status == Status.ABORTED


func is_being_requested() -> bool:
	return _status == Status.REQUESTING


func invalidate() -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		# Only run in the main thread
		invalidate.call_deferred()
		return
	if not _has_error:
		_has_error = true
		_status = Status.ABORTED
		invalid_state_received.emit()


func find_state(in_time: float) -> PackedVector3Array:
	assert(in_time >= 0, "Invalid time argument")
	if _last_seeked_time == in_time:
		return _last_seeked_state
	_last_seeked_time = in_time
	if frames.has(in_time):
		_last_seeked_state = frames[in_time]
		return _last_seeked_state
	var stamps: Array = frames.keys()
	stamps.sort()
	var remove_bigger: Callable = func(t: float) -> bool: return t < in_time
	stamps = stamps.filter(remove_bigger)
	var closest_time: float = stamps[-1]
	_last_seeked_state = frames[closest_time]
	return _last_seeked_state

func get_last_seeked_time() -> float:
	return max(_last_seeked_time, 0) # _last_seeked_time is -1 by default

func _get_simulation_id() -> int:
	return get_instance_id()

func _set_parameters_once(in_params: SimulationParameters) -> void:
		if parameters == null:
			parameters = in_params.duplicate()
		else:
			push_error("Cannot set simulation parameters more than once! value of {} was rejected"
			.format(str(in_params)))
