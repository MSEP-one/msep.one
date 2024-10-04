extends Node2D

const RAY_LENGTH = 1000000.0
const EPSILON = .0001
const COLLISION_RADIUS = 200.0
const DISPLAY_RADIUS = 70.0


@onready var gizmo: Node3D = owner

var camera: Camera3D:
	get:
		return GizmoRoot.camera_3D
var selected_node: Node3D:
	get:
		return GizmoRoot.selected_node

var grab_offset: Vector2 = Vector2.ZERO
var current_plane: Plane = Plane(.0, .0, .0, .0)


func _ready() -> void:
	z_index = gizmo.z_index_root - 4


func detect_collision() -> bool:
	GizmoRoot.mouse_hover_detected.center_drag = false
	
	var viewport_rect = get_viewport_rect()
	var mouse_pos = get_viewport().get_mouse_position()
	if !viewport_rect.has_point(mouse_pos):
		return false
	
	# Prioritize some elements over center when only from behind.
	if GizmoRoot.mouse_hover_detected.translation_axis || \
		GizmoRoot.mouse_hover_detected.scale_axis || \
		GizmoRoot.mouse_hover_detected.rotation_arcs || \
		GizmoRoot.mouse_hover_detected.translation_surface:
			return false
	
	var collision_radius: float = DISPLAY_RADIUS if gizmo.limit_center_radius else COLLISION_RADIUS
	collision_radius *= gizmo.gizmo_size_ratio * gizmo.viewport_size_factor
	var collision_radius_sqrd: float = collision_radius * collision_radius
	var origin = Vector2.ZERO
	if get_local_mouse_position().length_squared() < collision_radius_sqrd:
		GizmoRoot.mouse_hover_detected.center_drag = true
		GizmoRoot.collision_mode = GizmoRoot.CollisionMode.CENTER
	return GizmoRoot.mouse_hover_detected.center_drag


func save_plane() -> void:
	var camera_forward = camera.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD
	current_plane = Plane(camera_forward, selected_node.global_position)
	grab_offset = get_local_mouse_position()


func place_on_plane() -> void:
	# ray_from can be not equal to camera global position on depth==0 if projection mode is orthogonal
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_from: Vector3 = camera.project_position(mouse_position - grab_offset, .0)
	var ray_to: Vector3 = camera.project_position(mouse_position - grab_offset, RAY_LENGTH)
	var intersect_position = current_plane.intersects_ray(ray_from, ray_to - ray_from)
	if intersect_position != null:
		selected_node.global_position = intersect_position


func _process(_delta: float) -> void:
	if is_instance_valid(selected_node) and is_instance_valid(camera):
		if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
			if detect_collision():
				save_plane()
		elif GizmoRoot.grab_mode == GizmoRoot.GrabMode.CENTER && GizmoRoot.mouse_hover_detected.center_drag:
			place_on_plane()


func update_drawing() -> void:
	global_position = camera.unproject_position(selected_node.global_position)
	queue_redraw()


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	if GizmoRoot.mouse_hover_detected.center_drag:
		var r: float = DISPLAY_RADIUS * gizmo.gizmo_size_ratio
		draw_circle(Vector2.ZERO, r, gizmo.active_center_color)
	else:
		var r: float = DISPLAY_RADIUS * gizmo.gizmo_size_ratio
		draw_circle(Vector2.ZERO, r, gizmo.inactive_center_color)


func gizmo_input(event: InputEvent) -> void:
	if GizmoRoot.input_is_allowed and event is InputEventMouse:
		var viewport_rect = get_viewport_rect()
		var mouse_pos = get_viewport().get_mouse_position()
		if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE && !viewport_rect.has_point(mouse_pos):
			return
		if event is InputEventMouseButton:
			GizmoRoot.input_is_being_consumed = true
			if event.is_pressed():
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						if GizmoRoot.mouse_hover_detected.center_drag && GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
							GizmoRoot.grab_mode = GizmoRoot.GrabMode.CENTER
