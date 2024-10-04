class_name SideButtonModel extends Node3D

var _zoom_animator: AnimationPlayer
var _pop_animator: AnimationPlayer
var _pop_delayer: Timer
var _icon: Sprite3D
var _idle_animator: AnimationPlayer
var _press_animator: AnimationPlayer
var _side_button_internal_model: SideBtnInternalModel
var _pop_counter_clock_wise_delayer: Timer
var _dissapear_delayer: Timer


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_zoom_animator = $ZoomAnimator
		_pop_animator = $PopAnimator
		_pop_delayer = $PopDelayer
		_icon = $visuals/SideBtnInternalModel/icon
		_idle_animator = $IdleAnimator
		_press_animator = $PressAnimator
		_side_button_internal_model = $visuals/SideBtnInternalModel
		_pop_counter_clock_wise_delayer = $CounterClockWisePopDelayer
		_dissapear_delayer = $DissapearDelayer
	if in_what == NOTIFICATION_READY:
		hide()


func reset() -> void:
	_zoom_animator.play("RESET")
	_idle_animator.play("RESET")
	_pop_animator.play("RESET")
	_press_animator.play("RESET")
	_side_button_internal_model.undim()


func set_hover_speed(new_hover_speed: float) -> void:
	_idle_animator.speed_scale = new_hover_speed


func ensure_hidden() -> void:
	hide()


func set_icon(in_icon: Texture) -> void:
	_icon.texture = in_icon


func zoom_in() -> void:
	_zoom_animator.play("zoom_in")
	


func zoom_out() -> void:
	_zoom_animator.queue("zoom_out")
	


func press_in() -> void:
	_side_button_internal_model.dim()
	_press_animator.play("press_in")


func press_out() -> void:
	_side_button_internal_model.undim()
	_press_animator.play("press_out")


func popup(in_delay: float) -> void:
	hide()
	_pop_delayer.start(in_delay)


func _on_pop_delayer_timeout() -> void:
	show()
	_pop_animator.play("pop")
	_pop_animator.advance(0.0001)


func pop_counter_clockwise(in_delay: float) -> void:
	hide()
	_pop_counter_clock_wise_delayer.start(in_delay)


func _on_counter_clock_wise_pop_delayer_timeout() -> void:
	show()
	_pop_animator.play("pop_counter_clock_wise")
	_pop_animator.advance(0.0001)


func dissapear(in_delay: float) -> void:
	_dissapear_delayer.start(in_delay)


func _on_dissapear_delayer_timeout() -> void:
	_pop_animator.play("dissapear")


func _on_pop_animator_animation_finished(anim_name: StringName) -> void:
	if anim_name == "dissapear":
		hide()
