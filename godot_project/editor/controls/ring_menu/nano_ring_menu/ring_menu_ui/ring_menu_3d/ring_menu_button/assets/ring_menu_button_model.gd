class_name RingMenuButtonModel extends Node3D


var _color_animator: AnimationPlayer
var _active_animator: AnimationPlayer
var _model: MeshInstance3D


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_color_animator = $ColorAnimator
		_active_animator = $ActiveAnimator
		_model = $RingMenu_IconCell_Normal
	
	if in_what == NOTIFICATION_READY:
		_color_animator.play("un-dim")
		_color_animator.advance(_color_animator.get_animation("un-dim").length)


func dim() -> void:
	_color_animator.play("dim")


func undim() -> void:
	if _color_animator.assigned_animation != "un-dim":
		_color_animator.play("un-dim")


func inactive() -> void:
	if _active_animator.assigned_animation != "inactive":
		_active_animator.play("inactive")
	_model.set_layer_mask_value(RingMenu3D.LIGHT_LAYER_REALTIME, false)


func active() -> void:
	if _active_animator.assigned_animation != "active":
		_active_animator.play("active")
	_model.set_layer_mask_value(RingMenu3D.LIGHT_LAYER_REALTIME, true)
