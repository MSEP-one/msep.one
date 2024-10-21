extends CanvasLayer


const TWEEN_TIME = 0.2
const SPIN_DELAY = 0.1


var _spin_factor: float = 1.0:
	set = _set_spin_factor
var _blur_factor: float = 0.0:
	set = _set_blur_factor
var _tween_gears: Tween = null
var _tween_self: Tween = null
var _elapsed: float = 0.0
var _minutes: int = 0

# Access to internal nodes are initialized in NOTIFICATION_SCENE_INSTANTIATED
var _blur_background: ColorRect
var _center_container: CenterContainer
var _gears_anim: Control
var _info_container: VBoxContainer
var _message: Label
var _steps_container: HBoxContainer
var _progress_bar: ProgressBar
var _elapsed_time_label: Label
var _button_work_in_background: Button
var _button_stop: Button
var _button_cancel: Button
var _spinning_gears: Array[Node] = []

var _center_container_remote_control_rect: Control = null
var _cancel_callback: Callable
var _stop_callback: Callable

var _active: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_blur_background = $BlurBackground
		_center_container = %CenterContainer
		_gears_anim = %GearsAnim
		_info_container = %InfoContainer
		_message = %Message
		_steps_container = %StepsContainer
		_progress_bar = %ProgressBar
		_elapsed_time_label = %ElapsedTimeLabel
		_button_work_in_background = %ButtonWorkInBackground
		_button_stop = %ButtonStop
		_button_cancel = %ButtonCancel
		_elapsed_time_label.hide()
		for child in _gears_anim.get_children():
			if child.has_method(&"set_spin_factor"):
				_spinning_gears.append(child)
		for child in _steps_container.get_children():
			child.queue_free()
		_button_work_in_background.pressed.connect(_on_button_work_in_background_pressed)
		_button_stop.pressed.connect(_on_button_stop_pressed)
		_button_cancel.pressed.connect(_on_button_cancel_pressed)
		_spin_factor = 0.0
		_blur_factor = 0.0
		hide()
		set_process(false)


func is_active() -> bool:
	return _active


func activate(in_with_message: String = "",
			in_cancel_callback: Callable = Callable(),
			in_stop_callback: Callable = Callable(),
			in_with_run_in_background_button: bool = false,
			in_center_in_control: Control = null,
			in_progress_handler: Object = null) -> void:
	_active = true
	if is_instance_valid(_tween_gears):
		_tween_gears.kill()
	if is_instance_valid(_tween_self):
		_tween_self.kill()
	_tween_gears = _gears_anim.create_tween()
	_tween_self = self.create_tween()
	_tween_gears.tween_property(_gears_anim, "modulate:a", 0.5, TWEEN_TIME)
	_tween_self.tween_property(self, "_spin_factor", 1.0, TWEEN_TIME) \
		.set_trans(Tween.TRANS_EXPO) \
		.set_delay(SPIN_DELAY)
	_tween_self.tween_property(self, "_blur_factor", 1.0, TWEEN_TIME)
	# in_with_message
	if in_with_message.is_empty():
		_message.hide()
	else:
		_message.text = in_with_message
		_message.show()
	# with_elapsed_time_counter
	var with_elapsed_time_counter: bool = FeatureFlagManager.get_flag_value(
		FeatureFlagManager.SHOW_ASYNC_PROCESS_ELAPSED_TIME
	)
	_elapsed = 0.0
	_minutes = 0
	_elapsed_time_label.text = ""
	_elapsed_time_label.visible = with_elapsed_time_counter
	set_process(with_elapsed_time_counter)
	# in_cancel_callback
	_button_cancel.visible = in_cancel_callback.is_valid()
	_cancel_callback = in_cancel_callback
	# in_stop_callback
	_button_stop.visible = in_stop_callback.is_valid()
	_stop_callback = in_stop_callback
	# in_with_run_in_background_button
	_button_work_in_background.visible = in_with_run_in_background_button
	assert(not in_with_run_in_background_button, "Run in background button is Unimplemented!")
	# in_center_in_control
	if is_instance_valid(_center_container_remote_control_rect):
		_center_container_remote_control_rect.resized.disconnect(_update_center_container_rect)
	_center_container_remote_control_rect = in_center_in_control
	if is_instance_valid(in_center_in_control):
		in_center_in_control.resized.connect(_update_center_container_rect)
	_update_center_container_rect()
	# in_progress_handler
	if in_progress_handler == null:
		_steps_container.hide()
		_progress_bar.hide()
	else:
		assert(false, "Progress Handler is Unimplemented!")
		pass
	show()
	for control: Control in [_button_cancel, _button_stop, _button_work_in_background, _gears_anim]:
		if control.visible:
			control.grab_focus()
			break
	

func deactivate() -> void:
	set_process(false)
	_cancel_callback = Callable()
	_stop_callback = Callable()
	if is_instance_valid(_tween_gears):
		_tween_gears.kill()
	if is_instance_valid(_tween_self):
		_tween_self.kill()
	_tween_gears = _gears_anim.create_tween()
	_tween_self = self.create_tween()
	_tween_gears.tween_property(_gears_anim, "modulate:a", 0.0, TWEEN_TIME) \
		.set_delay(SPIN_DELAY)
	_tween_self.tween_property(self, "_spin_factor", 0.0, TWEEN_TIME) \
		.set_trans(Tween.TRANS_EXPO)
	_tween_self.tween_property(self, "_blur_factor", 0.0, TWEEN_TIME)
	await _tween_self.finished
	_active = false
	hide()


func _set_spin_factor(in_factor: float) -> void:
	_spin_factor = in_factor
	for gear in _spinning_gears:
		gear.set_spin_factor(in_factor)


func _set_blur_factor(in_factor: float) -> void:
	_blur_factor = in_factor
	if is_instance_valid(_blur_background):
		_blur_background.material.set_shader_parameter(&"blur", in_factor)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 60.0:
		_minutes += 1
		_elapsed -= 60.0
	_elapsed_time_label.text = tr("Elapsed: ") + ("%02d:%02d.%03d" % [_minutes, _elapsed, fmod(_elapsed, 1.0)*1000])


func _update_center_container_rect() -> void:
	if _center_container_remote_control_rect != null:
		_center_container.global_position = _center_container_remote_control_rect.global_position
		_center_container.size = _center_container_remote_control_rect.size
	else:
		_center_container.position = Vector2.ZERO
		_center_container.size = _center_container.get_viewport_rect().size

func _on_button_work_in_background_pressed() -> void:
	assert(false, "Run in background button is Unimplemented!")
	pass


func _on_button_stop_pressed() -> void:
	if _stop_callback.is_valid():
		_stop_callback.call()
		_button_work_in_background.hide()
		_button_stop.hide()
		_button_cancel.hide()


func _on_button_cancel_pressed() -> void:
	if _cancel_callback.is_valid():
		_cancel_callback.call()
		_button_work_in_background.hide()
		_button_stop.hide()
		_button_cancel.hide()

