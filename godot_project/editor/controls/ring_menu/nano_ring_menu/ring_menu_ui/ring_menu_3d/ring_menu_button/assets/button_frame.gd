class_name RingMenuButtonFrame extends Node3D


var _active_animator: AnimationPlayer


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_active_animator = $ActiveAnimator


func inactive() -> void:
	if _active_animator.assigned_animation != "inactive":
		_active_animator.play("inactive")


func active() -> void:
	if _active_animator.assigned_animation != "active":
		_active_animator.play("active")

