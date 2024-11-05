extends CanvasLayer

var _blocker: Control = null


func _ready() -> void:
	_blocker = %BlockerRect as Control
	_blocker.set_mouse_filter(_blocker.MOUSE_FILTER_STOP)


func _process(_in_delta: float) -> void:
	_unblock_last_frame_input_events()


func is_blocking() -> bool:
	return _blocker.get_mouse_filter() == _blocker.MOUSE_FILTER_STOP


func block_current_frame_input_events() -> void:
	_blocker.set_mouse_filter(_blocker.MOUSE_FILTER_STOP)


func _unblock_last_frame_input_events() -> void:
	_blocker.set_mouse_filter(_blocker.MOUSE_FILTER_IGNORE)
