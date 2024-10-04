class_name CaptureInputArea extends Area3D
## "Area which captures user input"
## This Area recreates the behavior of input_capture_on_drag flag for the scenario where there is
## many viewports in the scene. Original input_capture_on_drag works only as long as mouse cursor
## does not leave the viewport on which Area3D is being rendered. This scene is basically a
## workaround for this behavior, you can consider it to be a
## 'multi viewport input_capture_on_drag solution'

signal press_out
signal press_in
signal clicked


var _is_mouse_inside: bool = false
var _is_pressed: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		assert(not input_capture_on_drag, "input_capture_on_drag does not work in the context of multiple viewports,
				the whole purpose behind this scene is to recreate behaviour of this flag for multi-viewport scenario.
				There is no need for this flag")


func _on_mouse_entered() -> void:
	_is_mouse_inside = true
	set_process_input(true)


func _on_mouse_exited() -> void:
	_is_mouse_inside = false
	if _is_pressed:
		# we still want to process input for this button even if mouse is outside
		set_process_input(true)
	else:
		set_process_input(false)


func is_mouse_inside() -> bool:
	return _is_mouse_inside


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if event.is_pressed():
		_press_logic()
	else:
		_unpress_logic()


func _press_logic() -> void:
	if !_is_mouse_inside:
		return
	_is_pressed = true
	press_in.emit()


func _unpress_logic() -> void:
	if not _is_pressed:
		return
	
	_is_pressed = false
	if not _is_mouse_inside:
		# we will re-start processing in _on_mouse_entered()
		set_process_input(false)
	press_out.emit()
	if _is_mouse_inside:
		clicked.emit()
