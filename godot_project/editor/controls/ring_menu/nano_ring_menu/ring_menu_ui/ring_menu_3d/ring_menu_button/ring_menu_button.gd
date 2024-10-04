class_name RingMenuButton extends Node3D
# Responsible for visual state of the ring menu button

signal clicked
signal hovered(in_name: String, in_tooltip: String)
signal focused(in_name: String, in_tooltip: String)
signal unfocused(in_name: String)


@export var icon_texture: Texture


var _focus_animator: AnimationPlayer
var _press_animator: AnimationPlayer
var _button_visual: RingMenuButtonModel
var _pop_animator: AnimationPlayer
var _pop_delayer: Timer
var _icon_animator: AnimationPlayer
var _icon_delayer: Timer
var _mild_icon_delayer: Timer
var _btn_frame: RingMenuButtonFrame
var _mouse_detector: CaptureInputArea
var _icon_holder: Node3D
var _disable_delayer: Timer
var _enable_delayer: Timer

var _is_enabled: bool = true
var _current_icon: RingMenuIcon
var _current_icon_name: String
var _current_icon_tooltip: String


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_focus_animator = $FocusAnimator
		_press_animator = $PressAnimator
		_button_visual = $visuals/button
		_pop_animator = $PopAnimator
		_pop_delayer = $PopDelayer
		_icon_animator = $IconAnimator
		_icon_delayer = $IconDelayer
		_mild_icon_delayer = $MildIconDelayer
		_btn_frame = $visuals/button_frame
		_mouse_detector = $MouseDetector
		_icon_holder = $visuals/button/iconHolder
		_disable_delayer = $DisableDelayer
		_enable_delayer = $EnableDelayer
	if in_what == NOTIFICATION_READY:
		hide()


func prepare_for_usage() -> void:
	if is_instance_valid(_current_icon):
		_current_icon.prepare_for_usage()
	_button_visual.undim()
	_press_animator.play("RESET")


func enable(in_enable_delay: float) -> void:
	if in_enable_delay <= 0.0:
		_enable()
	else:
		_enable_delayer.start(in_enable_delay)


func _on_enable_delayer_timeout() -> void:
	_enable()


func _enable() -> void:
	_button_visual.active()
	_btn_frame.active()
	_is_enabled = true
	if is_instance_valid(_current_icon):
		_current_icon.active()


func disable(in_disable_animation_delay: float) -> void:
	_is_enabled = false
	if in_disable_animation_delay <= 0.0:
		_disable()
	else:
		_disable_delayer.start(in_disable_animation_delay)


func _on_disable_delayer_timeout() -> void:
	_disable()


func _disable() -> void:
	_button_visual.inactive()
	_btn_frame.inactive()
	_is_enabled = false
	if is_instance_valid(_current_icon):
		_current_icon.inactive()


func _on_mouse_detector_mouse_entered() -> void:
	if is_instance_valid(_current_icon):
		_current_icon.focus_in()
	hovered.emit(_current_icon_name, _current_icon_tooltip, _is_enabled)
	if _is_enabled:
		_focus_animator.play("highlight")
		focused.emit(_current_icon_name, _current_icon_tooltip)


func _on_mouse_detector_mouse_exited() -> void:
	if not is_instance_valid(_current_icon):
		return
	_current_icon.focus_out()
	if _focus_animator.assigned_animation == "highlight":
		_focus_animator.queue("lowlight")
	unfocused.emit(_current_icon_name)


func _on_mouse_detector_press_in() -> void:
	if not _is_enabled:
		return
	_press_animator.play("press_in")
	_current_icon.press_in()
	_button_visual.dim()


func _on_mouse_detector_press_out() -> void:
	if not _is_enabled:
		return
	_press_animator.queue("press_out")
	_current_icon.press_out()
	_button_visual.undim()


func _on_mouse_detector_clicked() -> void:
	if not _is_enabled:
		return
	clicked.emit()


func is_mouse_hovering() -> bool:
	return _mouse_detector.is_mouse_inside()


func get_icon_name() -> String:
	return _current_icon_name


func popup(in_delay_time: float, in_icon: RingMenuIcon, in_name: String, in_tooltip: String) -> void:
	if is_instance_valid(in_icon):
		assert(not in_icon.is_inside_tree(), "Icon is already in the tree")
		assert(in_icon.has_method("press_in"), "Icon needs to implement `press_in()` method")
		assert(in_icon.has_method("press_out"), "Icon needs to implement `press_out()` method")
		assert(in_icon.has_method("fade_in"), "Icon needs to implement `fade_in()` method")
		assert(in_icon.has_method("fade_out_and_queue_free"), "Icon needs to implement fade_out_and_queue_free()` method")
	
	_current_icon = null
	_current_icon_name = in_name
	_current_icon_tooltip = in_tooltip
	for icon in _icon_holder.get_children():
		icon.queue_free()
		icon.hide()
	if is_instance_valid(in_icon):
		_icon_holder.add_child(in_icon)
		_current_icon = in_icon
	hide()
	if in_delay_time > 0.0:
		_pop_delayer.start(in_delay_time)
	else:
		_pop_animation()
	
	if _current_icon == null:
		disable(0.0)
	else:
		_button_visual.active()
		_btn_frame.active()


func _on_pop_delayer_timeout() -> void:
	_pop_animation()


func _pop_animation() -> void:
	_pop_animator.play("pop")
	_pop_animator.advance(0.0001)
	if is_instance_valid(_current_icon):
		_current_icon.pop_animation()
	show()


func _apply_current_icon() -> void:
	for icon in _icon_holder.get_children():
		if _current_icon != icon:
			icon.queue_free()
			icon.hide()
	if is_instance_valid(_current_icon) and not _current_icon.is_inside_tree():
		_icon_holder.add_child(_current_icon)


func _apply_current_icon_with_fade() -> void:
	for icon in _icon_holder.get_children():
		if _current_icon != icon:
			icon.queue_free()
			icon.hide()
	if is_instance_valid(_current_icon):
		if not _current_icon.is_inside_tree():
			_icon_holder.add_child(_current_icon)
		_current_icon.fade_in()
	

func change_icon(in_change_delay: float, in_icon: RingMenuIcon, in_name: String, in_tooltip: String) -> void:
	# _current_icon will be applied by _icon_animator at proper moment during the animation
	# by calling _apply_current_icon / _apply_current_icon_with_fade
	_current_icon = in_icon
	_current_icon_name = in_name
	_current_icon_tooltip = in_tooltip
	_icon_delayer.start(in_change_delay)


func _on_icon_delayer_timeout() -> void:
	_icon_animator.play("change")
	for icon in _icon_holder.get_children():
		icon.fade_out_and_queue_free()


func _on_icon_animator_animation_finished(anim_name: StringName) -> void:
	if anim_name != "change":
		return
	if _mouse_detector.is_mouse_inside() and _is_enabled:
		_focus_animator.stop()
		_focus_animator.play("highlight_slow")
		focused.emit(_current_icon_name, _current_icon_tooltip)


func change_icon_mild(in_change_delay: float, in_icon: RingMenuIcon, in_name: String, in_tooltip: String) -> void:
	_current_icon = in_icon
	_current_icon_name = in_name
	_current_icon_tooltip = in_tooltip
	_mild_icon_delayer.start(in_change_delay)


func _on_mild_icon_delayer_timeout() -> void:
	var animation_in_progress: bool = _icon_animator.current_animation == "change_mild"
	if not animation_in_progress:
		_icon_animator.play("change_mild")
	for icon in _icon_holder.get_children():
		var is_icon_expired: bool = _current_icon != icon
		if is_icon_expired:
			icon.fade_out_and_queue_free()
