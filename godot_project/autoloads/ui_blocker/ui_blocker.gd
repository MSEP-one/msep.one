extends CanvasLayer

var _blocker: Control = null
var _block_requests: Array[Object] = []

func _ready() -> void:
	_blocker = %BlockerRect as Control
	_blocker.set_mouse_filter(_blocker.MOUSE_FILTER_STOP)


func _process(_in_delta: float) -> void:
	for i in range(_block_requests.size()-1, -1, -1):
		if not is_instance_valid(_block_requests[i]):
			_block_requests.remove_at(i)
		else:
			# Something is blocking all inputs for undefined frames
			return
	_unblock_last_frame_input_events()


func is_blocking() -> bool:
	return _blocker.get_mouse_filter() == _blocker.MOUSE_FILTER_STOP


func block_current_frame_input_events() -> void:
	_blocker.set_mouse_filter(_blocker.MOUSE_FILTER_STOP)


func start_blocking_input_events(in_requester: Object) -> void:
	if (not is_instance_valid(in_requester)) or _block_requests.has(in_requester):
		return
	_blocker.set_mouse_filter(_blocker.MOUSE_FILTER_STOP)
	_block_requests.push_back(in_requester)


func stop_blocking_input_events(in_requester: Object) -> void:
	_block_requests.erase(in_requester)


func _unblock_last_frame_input_events() -> void:
	_blocker.set_mouse_filter(_blocker.MOUSE_FILTER_IGNORE)
