extends Node2D

const EPSILON = .0001
const FULL_R_CIRCLE = 2.0 * PI
const CUBE_SIZE = .065
const LINE_THICKNESS = 3.0
const CUBE_COLLISION_RADIUS = 11.0
const GLOBAL_FLIP_THRESHOLD = .15

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

var xyz_axes_distances_to_mouse = [
#	[
#		pointer_to_axis_distance,
#		axis_node_3d
#	], ...
]
var potential_collision := false
var colliding_axis: Node3D = null
var mouse_movement := Vector2.ZERO

var scale_factor: float = 1.0
var is_scaling := false
# Callback will capture information about the target axis
var update_scale_callback: Callable = Callable()

var relative_scale := Vector2.ONE

# The selected_node's global_transform when the user presses the mouse
var initial_drag_transform := Transform3D()
# The selected_node's orthonormalized rotation when the user presses the mouse
var initial_orthonormalized_selected_node_rotation := Quaternion.IDENTITY
# The value to multiply the initial_drag_transform to get the current scale
var accumulated_scale_drag: float = 1.0


func _ready() -> void:
	z_index = gizmo.z_index_root


func check_axis_collision(axis: Node3D) -> void:
	var axis_vector: Vector3 = axis.position.normalized()
	var axis_amplitude: float = abs(axis.position.x + axis.position.y + axis.position.z)
	var axis_global_position: Vector3 = gizmo.global_position + axis_vector * axis_amplitude
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
	
	var translation_surfaces_colliding: bool = gizmo.active_axis_is_pointing_away && GizmoRoot.mouse_hover_detected.translation_surface
	var rotation_arcs_colliding: bool = gizmo.active_axis_is_pointing_away && GizmoRoot.mouse_hover_detected.rotation_arcs
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
	var current_rotation := Quaternion.IDENTITY
	var initialization_rotation := Quaternion(side_vec, PI / 4) # Rotate around axis by 45º
	current_rotation *= initialization_rotation
	var gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
	var axis_amplitude: float = abs(axis.position.x + axis.position.y + axis.position.z)
	var axis_global_position: Vector3 = gizmo.global_position + side_vec * axis_amplitude
	var axis_local_position_2d: Vector2 = camera.unproject_position(axis_global_position) - gizmo_position_2d_in_viewport
	axis_local_position_2d *= relative_scale
	
	draw_line(Vector2.ZERO, axis_local_position_2d, axis_color, LINE_THICKNESS, false)
	
	var tip_from: Vector2 = axis_local_position_2d * CUBE_SIZE * Vector2.ONE.length() * relative_scale
	
	var cube_points := PackedVector2Array()
	
	for i in range(0, arrow_step_amount):
		var vertex_offset_3d: Vector3 = current_rotation * front_vec * CUBE_SIZE
		var vertex_position_2d_in_viewport: Vector2 = camera.unproject_position(axis_global_position + vertex_offset_3d)
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
	var rs: Vector2 = gizmo.calculate_relative_scale()
	var rsx: float = rs.x if abs(rs.x) > EPSILON else EPSILON * sign(rs.x)
	var rsy: float = rs.y if abs(rs.y) > EPSILON else EPSILON * sign(rs.y)
	relative_scale = Vector2.ONE / Vector2(rsx, rsy)


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	if !is_instance_valid(camera):
		return
	draw_axis_cube(x_axis, Vector3.RIGHT, Vector3.FORWARD, gizmo.active_x_color if colliding_axis == x_axis else gizmo.inactive_x_color)
	draw_axis_cube(y_axis, Vector3.UP, Vector3.FORWARD,  gizmo.active_y_color if colliding_axis == y_axis else gizmo.inactive_y_color)
	draw_axis_cube(z_axis, -Vector3.FORWARD, Vector3.UP,  gizmo.active_z_color if colliding_axis == z_axis else gizmo.inactive_z_color)


func _process(delta: float) -> void:
	GizmoRoot.calculate_pointing_away()
	
	preserve_dimensions()
	gather_colliding_axis()
	
	if mouse_movement.length_squared() > 0:
		if gizmo.enable_global_squash:
			perform_squash_scale(delta)
		else:
			perform_global_scale(delta)
	
	mouse_movement = Vector2.ZERO


func update_drawing() -> void:
	global_position = camera.unproject_position(selected_node.global_position)
	queue_redraw()


func perform_squash_scale(delta: float) -> void:
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.AXIS && GizmoRoot.mouse_hover_detected.scale_axis:
		
		if !is_scaling:
			is_scaling = true
			scale_factor = abs(g_scale.length() + EPSILON)
			update_scale_callback = func(global_axis_vec: Vector3, delta):
				var global_axis_direction_2d: Vector2 = calculate_global_axis_dir(global_axis_vec)
				var du: float = mouse_movement.dot(global_axis_direction_2d)
				
				var delta_scale_factor: float = sign(du) * delta * scale_factor
				
				var local_scale: Vector3 = global_axis_vec * delta_scale_factor
				var glob_scale: Vector3 = orthonormalized_selected_node_rotation * local_scale
				
				var global_axis_fliped: Vector3 = global_axis_vec * rot_flip * scale_flip
				var flip: float = global_axis_fliped.x + global_axis_fliped.y + global_axis_fliped.z
				
				var dup: float = calculate_dir_flip(global_axis_vec)
				if dup > .0:
					g_scale += glob_scale * flip
				else:
					g_scale -= glob_scale * flip
		
		if colliding_axis == x_axis:
			update_scale_callback.call(Vector3.RIGHT, delta)
		elif colliding_axis == y_axis:
			update_scale_callback.call(Vector3.UP, delta)
		elif colliding_axis == z_axis:
			update_scale_callback.call(Vector3.FORWARD, delta)
		
		selected_node.scale = g_scale
	else:
		scale_flip.x = sign(selected_node.scale.x)
		scale_flip.y = sign(selected_node.scale.y)
		scale_flip.z = sign(selected_node.scale.z)
		rot_flip.x = calculate_rot_flip(Vector3.RIGHT)
		rot_flip.y = calculate_rot_flip(Vector3.UP)
		rot_flip.z = calculate_rot_flip(Vector3.FORWARD)
		
		initial_orthonormalized_selected_node_rotation = orthonormalized_selected_node_rotation
		g_scale = selected_node.scale
		is_scaling = false


func perform_global_scale(delta: float) -> void:
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.AXIS && GizmoRoot.mouse_hover_detected.scale_axis:
		
		if !is_scaling:
			is_scaling = true
			scale_factor = abs(selected_node.scale.length() + EPSILON)
			update_scale_callback = func(global_axis_vec: Vector3, delta):
				var global_axis_direction_2d: Vector2 = calculate_global_axis_dir(global_axis_vec)
				var du: float = mouse_movement.dot(global_axis_direction_2d)
				
				var delta_scale_drag: float = du * delta * scale_factor
				accumulated_scale_drag += delta_scale_drag
				
				var scale_multiplier: Vector3 = Vector3(
					1.0 if global_axis_vec.x == 0 else accumulated_scale_drag,
					1.0 if global_axis_vec.y == 0 else accumulated_scale_drag,
					1.0 if global_axis_vec.z == 0 else accumulated_scale_drag,
				)
				
				var scaled_transform: Transform3D = initial_drag_transform.scaled(scale_multiplier)
				scaled_transform.origin = selected_node.global_position
				
				selected_node.global_transform = scaled_transform
		if colliding_axis == x_axis:
			update_scale_callback.call(Vector3.RIGHT, delta)
		if colliding_axis == y_axis:
			update_scale_callback.call(Vector3.UP, delta)
		if colliding_axis == z_axis:
			update_scale_callback.call(-Vector3.FORWARD, delta)
	else:
		initial_drag_transform = selected_node.global_transform
		accumulated_scale_drag = 1.0
		is_scaling = false


func calculate_dir_flip(dir_vec: Vector3) -> float:
	var rotated_vec: Vector3 = selected_node.basis.get_rotation_quaternion() * dir_vec
	var oup: Vector3 = initial_orthonormalized_selected_node_rotation * dir_vec
	return oup.dot(rotated_vec)


func calculate_global_axis_dir(dir_vec: Vector3) -> Vector2:
	var gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
	var axis_global_position: Vector3 = gizmo.global_position + dir_vec
	var axis_local_position_2d: Vector2 = camera.unproject_position(axis_global_position) - gizmo_position_2d_in_viewport
	return axis_local_position_2d.normalized()


func calculate_rot_flip(dir_vec: Vector3) -> float:
	var oup: Vector3 = initial_orthonormalized_selected_node_rotation * dir_vec
	var wup: float = oup.dot(dir_vec)
	return 1.0 if wup > .0 else -1.0

var scale_flip := Vector3.ONE
var rot_flip := Vector3.ONE
var orthonormalized_selected_node_rotation: Quaternion:
	get:
		if is_instance_valid(selected_node):
			return selected_node.basis.orthonormalized().get_rotation_quaternion()
		return Quaternion.IDENTITY
var g_scale := Vector3(1.0, 1.0, 1.0)


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
						if GizmoRoot.mouse_hover_detected.scale_axis && GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
							GizmoRoot.grab_mode = GizmoRoot.GrabMode.AXIS
