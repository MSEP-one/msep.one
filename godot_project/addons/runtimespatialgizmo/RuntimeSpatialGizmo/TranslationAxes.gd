extends Node2D

const MAX_LOOK_AT_CAMERA = .995
const CIRCLE_EIGHT = PI * .25
const EPSILON = .0001
const RAY_LENGTH = 1000000
const FULL_R_CIRCLE = 2.0 * PI
const ARROW_RADIUS = .045
const ARROW_TIP_OFFSET = 1.25
const LINE_THICKNESS = 3.0
const ARROW_COLLISION_RADIUS = 200.0

@onready var gizmo: Node3D = owner
var camera: Camera3D:
	get:
		return GizmoRoot.camera_3D
var selected_node: Node3D:
	get:
		return GizmoRoot.selected_node

@onready var x_axis: Node3D = %X
@onready var y_axis: Node3D = %Y
@onready var z_axis: Node3D = %Z

var xyz_axes_distances_to_mouse: Array[Array] = [
#	[
#		pointer_to_axis_distance,
#		axis_node_3d
#	], ...
]
var potential_collision := false
var colliding_axis: Node3D = null
var mouse_movement := Vector2.ZERO

var current_plane := Plane(.0, .0, .0, .0)
var grab_offset := Vector2.ZERO
var grab_initial_position := Vector3.ZERO

var relative_scale := Vector2.ONE


func _ready() -> void:
	z_index = gizmo.z_index_root - 1


func check_axis_collision(axis: Node3D) -> void:
	var axis_global_position: Vector3 = axis.global_position
	var axis_position_2d_in_viewport: Vector2 = camera.unproject_position(axis_global_position)
	var gizmo_position_2d_in_viewport: Vector2 = camera.unproject_position(gizmo.global_position)
	var mouse_position = get_viewport().get_mouse_position()
	var camera_to_selected_node_dir: Vector3 = (selected_node.global_position - camera.global_position).normalized()
	
	var axis_to_camera_abs_dot : float = \
	1.0 - clamp(abs(camera_to_selected_node_dir.dot(axis_global_position.normalized())), .75, 1.0) + .5
	var collision_radius: float = ARROW_COLLISION_RADIUS * gizmo.gizmo_size_ratio * \
	axis_to_camera_abs_dot * gizmo.viewport_size_factor
	var collision_radius_sqrd: float = collision_radius * collision_radius
	var gizmo_to_axis_vector: Vector2 = (axis_position_2d_in_viewport - gizmo_position_2d_in_viewport) * relative_scale
	if (mouse_position - gizmo_position_2d_in_viewport).distance_squared_to(gizmo_to_axis_vector) < collision_radius_sqrd:
		xyz_axes_distances_to_mouse.append([camera.global_position.distance_to(axis_global_position), axis])
		potential_collision = true


func get_closest_axis() -> Node3D:
	if xyz_axes_distances_to_mouse.is_empty():
		return null
	xyz_axes_distances_to_mouse.sort_custom(GizmoRoot.sort_ascending_by_first_element)
	return xyz_axes_distances_to_mouse[0][1]


func gather_colliding_axis() -> void:
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
		colliding_axis = null
		potential_collision = false
		xyz_axes_distances_to_mouse.clear()
		check_axis_collision(x_axis)
		check_axis_collision(y_axis)
		check_axis_collision(z_axis)
		if potential_collision:
			colliding_axis = get_closest_axis()
		
		var viewport_rect = get_viewport_rect()
		var mouse_pos = get_viewport().get_mouse_position()
		if !viewport_rect.has_point(mouse_pos):
			colliding_axis = null
		
		GizmoRoot.mouse_hover_detected.translation_axis = false
	
	
	if colliding_axis != null:
		GizmoRoot.mouse_hover_detected.translation_axis = true
		GizmoRoot.collision_mode = GizmoRoot.CollisionMode.AXIS


func draw_axis_arrow(axis: Node3D, side_vec: Vector3, front_vec: Vector3, axis_color: Color) -> void:
	var arrow_base_progress: float = .0
	var arrow_step_amount: float = 32
	var arrow_base_step: float = FULL_R_CIRCLE / arrow_step_amount
	var step_quaternion := Quaternion(side_vec, arrow_base_step)
	var current_rotation: Quaternion = gizmo.global_transform.basis.get_rotation_quaternion()
	var gizmo_position_2d_in_viewport: Vector2 = camera.unproject_position(gizmo.global_position)
	var axis_local_position_2d: Vector2 = camera.unproject_position(axis.global_position) - gizmo_position_2d_in_viewport
	axis_local_position_2d *= relative_scale
	
	draw_line(Vector2.ZERO, axis_local_position_2d, axis_color, LINE_THICKNESS, false)
	
	var tip_from: Vector2 = axis_local_position_2d * ARROW_TIP_OFFSET
	var col: Color = axis_color
	col.a /= (arrow_step_amount / 4.0)
	
	for i in range(0, arrow_step_amount):
		var vertex_offset: Vector3 = current_rotation * front_vec * ARROW_RADIUS
		var vertex_position_2d_in_vewport: Vector2 = camera.unproject_position(axis.global_position + vertex_offset)
		var to: Vector2 = (vertex_position_2d_in_vewport - gizmo_position_2d_in_viewport) * relative_scale
		draw_line(axis_local_position_2d, to, col, LINE_THICKNESS, false)
		draw_line(tip_from, to, col, LINE_THICKNESS, false)
		
		current_rotation *= step_quaternion


func preserve_dimensions() -> void:
	var rs: Vector2 = gizmo.calculate_relative_scale()
	var rsx: float = rs.x if abs(rs.x) > EPSILON else EPSILON * sign(rs.x)
	var rsy: float = rs.y if abs(rs.y) > EPSILON else EPSILON * sign(rs.y)
	relative_scale = Vector2.ONE / Vector2(rsx, rsy)


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	if !is_instance_valid(selected_node) || !is_instance_valid(camera):
		return
	draw_axis_arrow(x_axis, Vector3.RIGHT, Vector3.FORWARD, gizmo.active_x_color if colliding_axis == x_axis else gizmo.inactive_x_color)
	draw_axis_arrow(y_axis, Vector3.UP, Vector3.FORWARD, gizmo.active_y_color if colliding_axis == y_axis else gizmo.inactive_y_color)
	draw_axis_arrow(z_axis, Vector3.FORWARD, Vector3.UP, gizmo.active_z_color if colliding_axis == z_axis else gizmo.inactive_z_color)


func save_plane() -> void:
	if colliding_axis == null:
		return
	var axis_dir: Vector3 = colliding_axis.position.normalized()
	var camera_to_selected_node_dir: Vector3 = (selected_node.global_position - camera.global_position).normalized()
	var axis_dots: Array[Array] = []
	var axes: Array[Node3D] = [x_axis, y_axis, z_axis]
	for axis in axes:
		if axis == colliding_axis:
			continue
		var other_axis_dir: Vector3 = axis.position.normalized()
		var other_axis_globally_transformed: Vector3 = selected_node.global_transform.basis.get_rotation_quaternion() * other_axis_dir
		axis_dots.append([abs(other_axis_globally_transformed.dot(camera_to_selected_node_dir)), other_axis_dir, axis])
	axis_dots.sort_custom(GizmoRoot.sort_ascending_by_first_element)
	
	var global_space_plane_normal: Vector3 = axis_dots.back()[1]
	
	var plane_normal := Vector3.ZERO
	if gizmo.limit_axis_range:
		var transformed_axis_dir: Vector3 = selected_node.global_transform.basis.get_rotation_quaternion() * axis_dir
		var axis_to_camera_dot: float = transformed_axis_dir.dot(camera_to_selected_node_dir)
		if abs(axis_to_camera_dot) > MAX_LOOK_AT_CAMERA:
			plane_normal = camera_to_selected_node_dir
		else:
			plane_normal = selected_node.global_transform.basis.get_rotation_quaternion() * global_space_plane_normal
	else:
		plane_normal = selected_node.global_transform.basis.get_rotation_quaternion() * global_space_plane_normal
	
	
	current_plane = Plane(plane_normal, selected_node.global_position) # Plane(normal, point)
	grab_initial_position = selected_node.global_position


func calculate_grab_offset() -> void:
	grab_offset = get_local_mouse_position()


func place_on_plane() -> void:
	if colliding_axis == null:
		return
	var vec_dir: Vector3 = colliding_axis.position.normalized()
	var mouse_position = get_viewport().get_mouse_position()
	# ray_from can be not equal to camera global position on depth==0 if projection mode is orthogonal
	var ray_from: Vector3 = camera.project_position(mouse_position - grab_offset, .0)
	var ray_to: Vector3 = camera.project_position(mouse_position - grab_offset, RAY_LENGTH)
	var intersect_position = current_plane.intersects_ray(ray_from, ray_to - ray_from)
	if intersect_position != null:
		var global_offset: Vector3 = intersect_position - grab_initial_position
		var distance: float = global_offset.length()
		var dir: Vector3 = global_offset.normalized()
		var global_space_axis_dir: Vector3 = selected_node.global_transform.basis.get_rotation_quaternion() * vec_dir
		var projection_factor: float = global_space_axis_dir.dot(dir)
		selected_node.global_position = grab_initial_position + \
						global_space_axis_dir * distance * projection_factor


func _process(_delta: float) -> void:
	if !is_instance_valid(selected_node) || !is_instance_valid(camera):
		return
	GizmoRoot.calculate_pointing_away()
	
	preserve_dimensions()
	gather_colliding_axis()
	
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
		save_plane()
		calculate_grab_offset()
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.AXIS && GizmoRoot.mouse_hover_detected.translation_axis:
		place_on_plane()
	
	mouse_movement = Vector2.ZERO


func update_drawing() -> void:
	global_position = camera.unproject_position(selected_node.global_position)
	queue_redraw()


func gizmo_input(event: InputEvent) -> void:
	if GizmoRoot.input_is_allowed and event is InputEventMouse:
		var viewport_rect = get_viewport_rect()
		var mouse_pos = get_viewport().get_mouse_position()
		if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE && !viewport_rect.has_point(mouse_pos):
			return
		if event is InputEventMouseMotion:
			GizmoRoot.input_is_being_consumed = true
			mouse_movement = event.relative
		elif event is InputEventMouseButton:
			GizmoRoot.input_is_being_consumed = true
			if event.is_pressed():
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						if GizmoRoot.mouse_hover_detected.translation_axis && GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
							GizmoRoot.grab_mode = GizmoRoot.GrabMode.AXIS
