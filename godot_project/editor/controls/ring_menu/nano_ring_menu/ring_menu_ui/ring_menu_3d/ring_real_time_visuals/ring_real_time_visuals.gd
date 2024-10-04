class_name RingRealTimeVisuals extends Node3D

const MAX_HORIZONTAL_ROTATION = 12.5
const MAX_VERTICAL_ROTATION = 10.0

const ROTATION_ACTIVE_RANGE = 3.0
const ROTATION_RANGE = ROTATION_ACTIVE_RANGE + 0.3
const ROTATION_RESET_DISTANCE = ROTATION_RANGE + 0.3


var _mouse_light: SpotLight3D


var _target_x_rotation: float = 0.0
var _target_y_rotation: float = 0.0
var _light_look_target: Vector3 = Vector3(0,0,0)


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_mouse_light = $MouseFollower
		_mouse_light.light_cull_mask = 1 << (RingMenu3D.LIGHT_LAYER_REALTIME - 1)


func reset(in_buttons_holder: Node3D) -> void:
	in_buttons_holder.rotation_degrees.x = 0
	in_buttons_holder.rotation_degrees.y = 0
	_target_x_rotation = 0.0
	_target_y_rotation = 0.0
	_light_look_target = Vector3()


func update(in_buttons_holder: Node3D, delta: float) -> void:
	process_button_ring_rotation(in_buttons_holder, delta)
	process_mouse_light(delta)


func process_button_ring_rotation(in_buttons_holder: Node3D, in_delta: float) -> void:
	var current_x_rotation: float = in_buttons_holder.rotation_degrees.x
	var current_y_rotation: float = in_buttons_holder.rotation_degrees.y
	in_buttons_holder.rotation_degrees.x = lerp(current_x_rotation, _target_x_rotation, in_delta * 2.5)
	in_buttons_holder.rotation_degrees.y = lerp(current_y_rotation, _target_y_rotation, in_delta * 2.5)


func process_mouse_light(in_delta: float) -> void:
	if _light_look_target.length_squared() == 0.0:
		return
	var current_quat := Quaternion(_mouse_light.basis)
	var target_quat := Quaternion(Basis.looking_at(_light_look_target, Vector3(0,1,0)))
	var new_quat: Quaternion = current_quat.slerp(target_quat, 1.5 * in_delta)
	_mouse_light.transform.basis = Basis(new_quat)


func input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	
	#
	var mouse_position: Vector2 = event.position
	var camera_distance: float = get_viewport().get_camera_3d().global_position.distance_to(global_position)
	_light_look_target = get_viewport().get_camera_3d().project_position(mouse_position, camera_distance)
	
	#
	var distance_to_mouse_cursor_3d: float = global_position.distance_to(_light_look_target)
	if distance_to_mouse_cursor_3d > ROTATION_RANGE:
		if distance_to_mouse_cursor_3d > ROTATION_RESET_DISTANCE:
			_target_x_rotation = 0.0
			_target_y_rotation = 0.0
		return
	
	#
	var current_horizontal_delta: float = clamp(_light_look_target.x - global_position.x,
			-ROTATION_ACTIVE_RANGE, ROTATION_ACTIVE_RANGE)
	_target_y_rotation = _linear_interpolate_between_2_points(-ROTATION_ACTIVE_RANGE, MAX_HORIZONTAL_ROTATION,
			ROTATION_ACTIVE_RANGE, -MAX_HORIZONTAL_ROTATION, current_horizontal_delta)
	
	var current_vertical_delta: float = clamp(_light_look_target.y - global_position.y,
			-ROTATION_ACTIVE_RANGE, ROTATION_ACTIVE_RANGE)
	_target_x_rotation = _linear_interpolate_between_2_points(-ROTATION_ACTIVE_RANGE, -MAX_VERTICAL_ROTATION,
			ROTATION_ACTIVE_RANGE, MAX_VERTICAL_ROTATION, current_vertical_delta)
	

func _linear_interpolate_between_2_points( inP1: float,  inP1Val: float,  inP2: float, inP2Val: float, interpolationPoint: float) -> float:
	return ((interpolationPoint * inP1Val) - (interpolationPoint * inP2Val) + (inP1 * inP2Val) - (inP2 * inP1Val))/ (inP1 - inP2);

