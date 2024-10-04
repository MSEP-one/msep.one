extends Node2D


@export var follow_target: Node3D
@export var position_shift: Vector3


func _process(_delta: float) -> void:
	assert(is_instance_valid(follow_target))
	
	if modulate.a == 0.0:
		return
	
	if !is_visible():
		return
	
	updateScreenPos();
	

func updateScreenPos() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if(not is_instance_valid(camera)):
		return;
	
	var pos_on_screen: Vector2 = camera.unproject_position(follow_target.get_global_transform().origin+position_shift)
	set_global_position(pos_on_screen)
