extends Node2D

const EPSILON = .0001
const FULL_R_CIRCLE = 2.0 * PI
const CUBE_SIZE = .065
const LINE_THICKNESS = 3.0
const CUBE_COLLISION_RADIUS = 18.0

@onready var gizmo: Node3D = owner
@onready var x_axis: Node3D = %X
@onready var y_axis: Node3D = %Y
@onready var z_axis: Node3D = %Z

var camera: Camera3D:
	get:
		return GizmoRoot.camera_3D
var selected_node: Node3D:
	get:
		return GizmoRoot.selected_node

var xyz_axes_distances_to_mouse: Array[Array] = [
#	[
#		pointer_to_axis_distance,
#		axis_node_3d
#	], ...
]
var potential_collision := false
var colliding_axis: Node3D = null
var mouse_relative_position := Vector2.ZERO

var scale_factor := 1.0
var is_scaling := false
# Callback will capture information about the target axis
var update_scale_callback: Callable = Callable()

var relative_scale := Vector2.ONE


func _ready() -> void:
	z_index = gizmo.z_index_root


func check_axis_collision(axis: Node3D) -> void:
	var axis_global_position: Vector3 = axis.global_position
	var axis_position_2d_in_viewport: Vector2 = camera.unproject_position(axis_global_position)
	var gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
	
	var collision_radius: float = CUBE_COLLISION_RADIUS * gizmo.gizmo_size_ratio * PI
	var collision_radius_sqrd: float = collision_radius * collision_radius
	var axis_local_position_2d: Vector2 = (axis_position_2d_in_viewport - gizmo_position_2d_in_viewport) * relative_scale
	if get_local_mouse_position().distance_squared_to(axis_local_position_2d) < collision_radius_sqrd:
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
		
		GizmoRoot.mouse_hover_detected.scale_axis = false
		
		var viewport_rect = get_viewport_rect()
		var mouse_pos = get_viewport().get_mouse_position()
		if !viewport_rect.has_point(mouse_pos):
			return
	
	var translation_surfaces_colliding = gizmo.active_axis_is_pointing_away && GizmoRoot.mouse_hover_detected.translation_surface
	var rotation_arcs_colliding = gizmo.active_axis_is_pointing_away && GizmoRoot.mouse_hover_detected.rotation_arcs
	if translation_surfaces_colliding || rotation_arcs_colliding:
		colliding_axis = null
	
	if colliding_axis != null:
		GizmoRoot.mouse_hover_detected.scale_axis = true
		GizmoRoot.collision_mode = GizmoRoot.CollisionMode.SCALE

const POLYGON_VERTEX_INDEXES = [0, 1, 3, 2, 2, 3, 5, 4, 4, 5, 7, 6, 6, 7, 1, 0, 0, 2, 4, 6, 1, 3, 5, 7]

func draw_axis_cube(axis: Node3D, side_vec: Vector3, front_vec: Vector3, axis_color: Color) -> void:
	var arrow_base_progress: float = .0
	var arrow_step_amount: float = 4
	var arrow_base_step: float = FULL_R_CIRCLE / arrow_step_amount
	var side_quaternion := Quaternion(side_vec, arrow_base_step)
	var gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
	var axis_local_position_2d: Vector2 = camera.unproject_position(axis.global_position) - gizmo_position_2d_in_viewport
	
	draw_line(Vector2.ZERO, axis_local_position_2d * relative_scale, axis_color, LINE_THICKNESS, false)
	
	var tip_from: Vector2 = axis_local_position_2d * CUBE_SIZE * Vector2.ONE.length() * relative_scale
	
	var cube_points = PackedVector2Array()
	
	var current_rotation: Quaternion = gizmo.global_transform.basis.get_rotation_quaternion()
	var initialization_rotation := Quaternion(side_vec, PI / 4) # Rotate around axis by 45º
	current_rotation *= initialization_rotation
	for i in range(0, arrow_step_amount):
		var vertex_offset_3d: Vector3 = current_rotation * front_vec * CUBE_SIZE
		var vertex_position_2d_in_viewport: Vector2 = camera.unproject_position(axis.global_position + vertex_offset_3d)
		var to: Vector2 = (vertex_position_2d_in_viewport - gizmo_position_2d_in_viewport) * relative_scale
		var tof: Vector2 = to + tip_from
		cube_points.append(to)
		cube_points.append(tof)
		
		current_rotation *= side_quaternion
	
	for i in range(0, 6):
		var ply := PackedVector2Array()
		ply.append(cube_points[POLYGON_VERTEX_INDEXES[i * 4]])
		ply.append(cube_points[POLYGON_VERTEX_INDEXES[i * 4 + 1]])
		ply.append(cube_points[POLYGON_VERTEX_INDEXES[i * 4 + 2]])
		ply.append(cube_points[POLYGON_VERTEX_INDEXES[i * 4 + 3]])
		
		draw_colored_polygon(ply, axis_color, PackedVector2Array(), null)


func preserve_dimensions() -> void:
	var rs = gizmo.calculate_relative_scale()
	var rsx = rs.x if abs(rs.x) > EPSILON else EPSILON * sign(rs.x)
	var rsy = rs.y if abs(rs.y) > EPSILON else EPSILON * sign(rs.y)
	relative_scale = Vector2.ONE / Vector2(rsx, rsy)


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	if !is_instance_valid(camera):
		return
	draw_axis_cube(x_axis, Vector3.RIGHT, Vector3.FORWARD, gizmo.active_x_color if colliding_axis == x_axis else gizmo.inactive_x_color)
	draw_axis_cube(y_axis, Vector3.UP, Vector3.FORWARD,  gizmo.active_y_color if colliding_axis == y_axis else gizmo.inactive_y_color)
	draw_axis_cube(z_axis, Vector3.FORWARD, Vector3.UP,  gizmo.active_z_color if colliding_axis == z_axis else gizmo.inactive_z_color)


func _process(delta: float) -> void:
	GizmoRoot.calculate_pointing_away()
	
	preserve_dimensions()
	gather_colliding_axis()
	
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.AXIS && GizmoRoot.mouse_hover_detected.scale_axis:
		var axis_position_2d_in_viewport: Vector2 = camera.unproject_position(colliding_axis.global_position)
		var gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
		var gizmo_to_axis_2d_direction: Vector2 = (axis_position_2d_in_viewport - gizmo_position_2d_in_viewport).normalized()
		var proyection_factor: float = mouse_relative_position.dot(gizmo_to_axis_2d_direction)
		
		if !is_scaling:
			is_scaling = true
			if colliding_axis == x_axis:
					scale_factor = abs(GizmoRoot.selected_node.scale.x)
					update_scale_callback = func(proyection_factor: float, delta: float):
						if GizmoRoot.selected_node.scale.x > .0:
							GizmoRoot.selected_node.scale.x += proyection_factor * delta * scale_factor
						else:
							GizmoRoot.selected_node.scale.x -= proyection_factor * delta * scale_factor
			elif colliding_axis == y_axis:
					scale_factor = abs(GizmoRoot.selected_node.scale.y)
					update_scale_callback = func(proyection_factor: float, delta: float):
						if GizmoRoot.selected_node.scale.y > .0:
							GizmoRoot.selected_node.scale.y += proyection_factor * delta * scale_factor
						else:
							GizmoRoot.selected_node.scale.y -= proyection_factor * delta * scale_factor
			elif colliding_axis == z_axis:
					scale_factor = abs(GizmoRoot.selected_node.scale.z)
					update_scale_callback = func(proyection_factor: float, delta: float):
						if GizmoRoot.selected_node.scale.z > .0:
							GizmoRoot.selected_node.scale.z += proyection_factor * delta * scale_factor
						else:
							GizmoRoot.selected_node.scale.z -= proyection_factor * delta * scale_factor
			
		# If in the middle of the viewport.
		if gizmo_to_axis_2d_direction.length_squared() < EPSILON:
			proyection_factor = mouse_relative_position.dot(Vector2.ONE) * sign(scale_factor)
		
		if update_scale_callback.is_valid():
			update_scale_callback.call(proyection_factor, delta)
	else:
		is_scaling = false
	
	mouse_relative_position = Vector2.ZERO


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
			mouse_relative_position = event.relative
		elif event is InputEventMouseButton:
			GizmoRoot.input_is_being_consumed = true
			if event.is_pressed():
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						if GizmoRoot.mouse_hover_detected.scale_axis && GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
							GizmoRoot.grab_mode = GizmoRoot.GrabMode.AXIS
