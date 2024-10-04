class_name SideButton extends Node3D
# Responsible for
# - representing small button that's hovering next to RingMenu
# - informing about click event through signal

signal clicked


const INSIDE_RADIUS_TOLERANCE = 0.2
var INSIDE_RADIUS_SQUARED: float


@export var icon: Texture = null : set = set_icon
@export var hover_speed: float = 0.6 : set = set_hover_speed

var _model: SideButtonModel
var _mouse_detector: Area3D


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_model = $SideButtonModel
		_mouse_detector = $MouseDetector
		
		var collision_shape: CollisionShape3D = _mouse_detector.get_node("CollisionShape3D")
		assert(collision_shape.shape is SphereShape3D, "MouseDetector shape is a sphere")
		var radius: float = collision_shape.shape.radius
		INSIDE_RADIUS_SQUARED = pow(radius + INSIDE_RADIUS_TOLERANCE, 2)


func prepare_for_usage() -> void:
	_model.reset()


func is_active() -> bool:
	return _model.is_visible_in_tree()


func is_point_inside(in_mouse_point: Vector2) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var segment_start_point: Vector3 = camera.project_ray_origin(in_mouse_point)
	var segment_direction: Vector3 = camera.project_ray_normal(in_mouse_point)
	var segment_end_point: Vector3 = segment_start_point + segment_direction * camera.far
	var closest_point_to_input_ray: Vector3 = Geometry3D.get_closest_point_to_segment_uncapped(
				global_position, segment_start_point, segment_end_point)
	var click_distance: float = global_position.distance_squared_to(closest_point_to_input_ray)
	return click_distance < INSIDE_RADIUS_SQUARED


func ensure_hidden() -> void:
	_model.ensure_hidden()


func set_hover_speed(in_hover_speed: float) -> void:
	hover_speed = in_hover_speed
	_model.set_hover_speed(hover_speed)


func set_icon(in_new_icon: Texture) -> void:
	icon = in_new_icon
	_model.set_icon(icon)


func _on_mouse_detector_mouse_entered() -> void:
	_model.zoom_in()


func _on_mouse_detector_mouse_exited() -> void:
	_model.zoom_out()


func popup(in_pop_delay: float) -> void:
	_model.popup(in_pop_delay)


func pop_counter_clockwise(in_pop_delay: float) -> void:
	_model.pop_counter_clockwise(in_pop_delay)


func dissapear(in_hide_delay: float) -> void:
	_model.dissapear(in_hide_delay)
	

func disable() -> void:
	_mouse_detector.set_collision_layer_value(1, false)


func enable() -> void:
	_mouse_detector.set_collision_layer_value(1, true)


func _on_mouse_detector_press_in() -> void:
	_model.press_in()


func _on_mouse_detector_press_out() -> void:
	_model.press_out()


func _on_mouse_detector_clicked() -> void:
	clicked.emit()
