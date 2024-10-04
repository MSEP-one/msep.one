class_name SideBtnInternalModel extends Node3D


var _dim_animator: AnimationPlayer


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_dim_animator = $DimAnimator


func dim() -> void:
	_dim_animator.play("dim")


func undim() -> void:
	_dim_animator.queue("un-dim")
