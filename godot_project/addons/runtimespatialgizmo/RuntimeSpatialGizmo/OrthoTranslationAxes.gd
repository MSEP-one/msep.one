extends Node2D

const MAX_LOOK_AT_CAMERA: float = .995
const EPSILON: float = .0001
const RAY_LENGTH: float = 1000000.0
const FULL_R_CIRCLE: float = 2.0 * PI
const ARROW_RADIUS: float = .045
const ARROW_COLLISION_RADIUS: float = 200.0
const AXIS_COLLISION_OFFSET_FACTOR: float = .1
const ARROW_TOP_RADIUS_FACTOR: float = .15
const TIP_OFFSET_3D: float = .21


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
var mouse_movement := Vector2.ZERO
var current_plane := Plane(.0, .0, .0, .0)
var grab_offset := Vector2.ZERO
var plane_distance: float = .0
var grab_initial_position := Vector3.ZERO
var relative_scale := Vector2.ONE
var dont_detect_collision_axis: Node3D = null
var arrow_base_points2D: PackedVector2Array = []
var arrow_top_points2D: PackedVector2Array = []
var arrow_base_depth_dots: PackedFloat32Array = []
var arrow_tip_sides: Array[Array] = []
var arrow_tip_position2D: Vector2 = Vector2.ZERO
var grab_distance: float = .0

@onready var gizmo: Node3D = owner
@onready var x_axis: Node3D = %X
@onready var y_axis: Node3D = %Y
@onready var z_axis: Node3D = %Z
# Used as a collection of Node2D
@onready var draw_axes: Array[Node] = [get_node("DrawX"), get_node("DrawY"), get_node("DrawZ")]


func _ready() -> void:
	z_index = gizmo.z_index_root - 1


func check_axis_collision(axis: Node3D) -> void:
	if dont_detect_collision_axis == axis:
		return
	
	var is_orthogonal: bool = camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var axis_vector: Vector3 = camera.global_transform.basis.get_rotation_quaternion() * axis.position.normalized()
	
	var camera_forward: Vector3 = camera.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD
	var camera_to_selected_node_dir: Vector3 = (selected_node.global_position - camera.global_position).normalized()
	var projection_scale: float = camera_forward.dot(camera_to_selected_node_dir)
	projection_scale = max(abs(projection_scale), EPSILON) * sign(projection_scale)
	
	var gizmo_position: Vector3 = gizmo.global_position
	if is_orthogonal:
		gizmo_position = selected_node.global_position
	var axis_amplitude: float = abs(axis.position.x + axis.position.y + axis.position.z)
	var axis_global_position: Vector3 = gizmo_position + axis_vector * axis_amplitude
	var axis_collision_position_2d_in_viewport: Vector2 = camera.unproject_position(axis_global_position + \
			(axis_global_position - gizmo_position).normalized() * AXIS_COLLISION_OFFSET_FACTOR)
	var gizmo_position_2d_in_viewport: Vector2 = global_position
	var mouse_position = get_viewport().get_mouse_position()
	
	var axis_to_camera_abs_dot : float = \
	1.0 - clamp(abs(camera_to_selected_node_dir.dot(axis_vector)), .75, 1.0) + .5
	var collision_radius: float = ARROW_COLLISION_RADIUS * gizmo.gizmo_size_ratio * \
	axis_to_camera_abs_dot * gizmo.viewport_size_factor
	var collision_radius_sqrd: float = collision_radius * collision_radius
	var axis_direction_2d: Vector2 = (axis_collision_position_2d_in_viewport - gizmo_position_2d_in_viewport) * relative_scale
	if (mouse_position - gizmo_position_2d_in_viewport).distance_squared_to(axis_direction_2d) < collision_radius_sqrd:
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


func calculate_arrow_head(in_arrow_height: float, in_arrow_steps: int, \
		in_axis_global_position: Vector3, in_offset: Vector2, \
		in_tip_direction: Vector3, in_base_direction: Vector3, in_arrow_tip_colors: PackedColorArray, \
		in_arrow_radius: float, in_projection_scale: float):
	var arrow_tip_position: Vector3 = in_axis_global_position + in_tip_direction * in_arrow_height
	
	var quaternion_rotated_pivot: Quaternion = Quaternion.IDENTITY
	var rotation_step: Quaternion = Quaternion(in_tip_direction, FULL_R_CIRCLE / in_arrow_steps)
	var camera_direction: Vector3 = (in_axis_global_position - camera.global_position).normalized()
	arrow_base_points2D.clear()
	arrow_top_points2D.clear()
	var arrow_base_colors: PackedColorArray
	var arrow_top_colors: PackedColorArray
	arrow_base_depth_dots.clear()
	var arrow_base_points: PackedVector3Array = []
	var arrow_top_points: PackedVector3Array = []
	for i in range(0, in_arrow_steps):
		var arrow_base_step: Vector3 = quaternion_rotated_pivot * in_base_direction * in_arrow_radius
		arrow_base_points.append(arrow_base_step)
		var arrow_top_step: Vector3 = quaternion_rotated_pivot * in_base_direction * \
		in_arrow_radius * ARROW_TOP_RADIUS_FACTOR
		arrow_top_points.append(arrow_top_step + in_tip_direction * in_arrow_height)
		quaternion_rotated_pivot *= rotation_step
	
	for i in range(0, in_arrow_steps):
		var end_index: int = i + 1 if i + 1 < in_arrow_steps else 0
		var edge1: Vector3 = (in_tip_direction * TIP_OFFSET_3D - arrow_base_points[i]).normalized()
		var edge2: Vector3 = (arrow_base_points[end_index] - arrow_base_points[i]).normalized()
		# It's fine to calculate normal for the triangle as the two triangles that form the
		# quadrilateral are guaranteed to be coplanar.
		var side_normal: Vector3 = -edge1.cross(edge2)
		
		var arrow_base_step2D = camera.unproject_position(arrow_base_points[i] + \
				in_axis_global_position) - in_offset
		arrow_base_points2D.append(arrow_base_step2D * in_projection_scale * relative_scale)
		var arrow_top_step2D = camera.unproject_position(arrow_top_points[i] + \
				in_axis_global_position) - in_offset
		arrow_top_points2D.append(arrow_top_step2D * in_projection_scale * relative_scale)
		arrow_base_colors.append(in_arrow_tip_colors[0])
		arrow_top_colors.append(in_arrow_tip_colors[1])
		arrow_base_depth_dots.append(camera_direction.dot(side_normal))
	
	assert(arrow_base_points2D.size() == in_arrow_steps, "Incorrect arrow_base_points2D size.")
	arrow_tip_position2D = (camera.unproject_position(arrow_tip_position) - in_offset) * \
			in_projection_scale * relative_scale
	var arrow_tip_side_points: PackedVector2Array = []
	# Sides
	var arrow_tip_side: Array[Variant] = []
	arrow_tip_sides.clear()
	for i in range(0, in_arrow_steps):
		var end_index: int = i + 1 if i + 1 < in_arrow_steps else 0
		
		arrow_tip_side_points = []
		arrow_tip_side_points.append(arrow_base_points2D[i])
		arrow_tip_side_points.append(arrow_top_points2D[i])
		arrow_tip_side_points.append(arrow_top_points2D[end_index])
		arrow_tip_side_points.append(arrow_base_points2D[end_index])
		
		arrow_tip_side = []
		arrow_tip_side.append(arrow_tip_side_points)
		arrow_tip_side.append(arrow_base_depth_dots[i])
		arrow_tip_side.append(in_arrow_tip_colors)
		
		arrow_tip_sides.append(arrow_tip_side)
	# Base
	arrow_tip_side = []
	arrow_tip_side.append(arrow_base_points2D)
	var base_dot: float = camera_direction.dot(in_tip_direction)
	arrow_tip_side.append(-base_dot)
	arrow_tip_side.append(arrow_base_colors)
	arrow_tip_sides.append(arrow_tip_side)
	# Top
	arrow_tip_side = []
	arrow_tip_side.append(arrow_top_points2D)
	arrow_tip_side.append(base_dot)
	arrow_tip_side.append(arrow_top_colors)
	arrow_tip_sides.append(arrow_tip_side)
	
	arrow_tip_sides.sort_custom(sort_arrow_sides_by_depth)


func sort_arrow_sides_by_depth(a: Array, b: Array):
	if a[1] > b[1]:
		return true
	return false


func preserve_dimensions() -> void:
	var rs: Vector2 = gizmo.calculate_relative_scale()
	var rsx: float = rs.x if abs(rs.x) > EPSILON else EPSILON * sign(rs.x)
	var rsy: float = rs.y if abs(rs.y) > EPSILON else EPSILON * sign(rs.y)
	relative_scale = Vector2.ONE / Vector2(rsx, rsy)
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		relative_scale *= camera.size * gizmo.ORTHOGRAPHIC_SCALE


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	if !is_instance_valid(camera):
		return
	dont_detect_collision_axis = null
	
	var active_color_is_allowed: bool = GizmoRoot.input_is_allowed
	if !active_color_is_allowed:
		active_color_is_allowed = GizmoRoot.grab_mode != GizmoRoot.GrabMode.NONE
	
	var reference_rotation: Quaternion = camera.global_transform.basis.get_rotation_quaternion()
	
	var draw_axis_params: Array[Array] = [
			[x_axis, reference_rotation * Vector3.RIGHT, reference_rotation * Vector3.FORWARD, \
					gizmo.active_x_color \
			if colliding_axis == x_axis && Input.mouse_mode != Input.MOUSE_MODE_CAPTURED && \
			active_color_is_allowed else gizmo.inactive_x_color, \
			x_axis.global_position.distance_squared_to(camera.global_position)],
			[y_axis, reference_rotation * Vector3.UP, reference_rotation * Vector3.FORWARD, \
					gizmo.active_y_color \
			if colliding_axis == y_axis && Input.mouse_mode != Input.MOUSE_MODE_CAPTURED && \
			active_color_is_allowed else gizmo.inactive_y_color, \
			y_axis.global_position.distance_squared_to(camera.global_position)],
			[z_axis, reference_rotation * -Vector3.FORWARD, reference_rotation * Vector3.UP, \
					gizmo.active_z_color \
			if colliding_axis == z_axis && Input.mouse_mode != Input.MOUSE_MODE_CAPTURED && \
			active_color_is_allowed else gizmo.inactive_z_color, \
			z_axis.global_position.distance_squared_to(camera.global_position)]
			]
	
	# Albeit axes are drawn each separately, they have the same z_index, so the sorting is
	# important. This could now be changed by modifying z index of each axis relative to the gizmo.
	draw_axis_params.sort_custom(sort_axis_depth)
	
	for i in range(0, 3):
		draw_axes[i].update_drawing(draw_axis_params[i][0], draw_axis_params[i][1], \
				draw_axis_params[i][2], draw_axis_params[i][3], i)


func sort_axis_depth(a: Array, b: Array):
	if a[4] > b[4]:
		return true
	return false


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
		axis_dots.append([abs(other_axis_dir.dot(camera_to_selected_node_dir)), other_axis_dir, axis])
	axis_dots.sort_custom(GizmoRoot.sort_ascending_by_first_element)
	
	var global_space_plane_normal: Vector3 = axis_dots.back()[1]
	
	var plane_normal: Vector3 = Vector3.ZERO
	if gizmo.limit_axis_range:
		var axis_to_camera_dot: float = axis_dir.dot(camera_to_selected_node_dir)
		if abs(axis_to_camera_dot) > MAX_LOOK_AT_CAMERA:
			plane_normal = camera_to_selected_node_dir
		else:
			plane_normal = global_space_plane_normal
	else:
		plane_normal = global_space_plane_normal
	
	current_plane = Plane(plane_normal, selected_node.global_position) # Plane(normal, point)
	grab_initial_position = selected_node.global_position


func calculate_grab_offset() -> void:
	grab_offset = get_local_mouse_position()
	
	var hypotenuse: Vector3 = GizmoRoot.selected_node.global_position - camera.global_position
	var adjacent: Vector3 = camera.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD
	var angle: float = hypotenuse.normalized().angle_to(adjacent)
	grab_distance = hypotenuse.length() * cos(angle)


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
		var projection_factor: float = vec_dir.dot(dir)
		selected_node.global_position = grab_initial_position + vec_dir * distance * projection_factor


func place_ortho() -> void:
	var placement_position: Vector2 = get_viewport().get_mouse_position() - grab_offset
	var selection_position2D: Vector2 = \
	camera.unproject_position(GizmoRoot.selected_node.global_position)
	if colliding_axis.name == "X":
		placement_position = Vector2(placement_position.x, selection_position2D.y)
	elif colliding_axis.name == "Y":
		placement_position = Vector2(selection_position2D.x, placement_position.y)
	selected_node.global_position = camera.project_position(placement_position, grab_distance)


func _process(_delta: float) -> void:
	if !is_instance_valid(selected_node) || !is_instance_valid(camera):
		return
	GizmoRoot.calculate_pointing_away()
	
	preserve_dimensions()
	if gizmo.active_axis_is_pointing_away:
		if !GizmoRoot.mouse_hover_detected.rotation_arcs && \
		!GizmoRoot.mouse_hover_detected.translation_surface:
			gather_colliding_axis()
		else:
			GizmoRoot.mouse_hover_detected.translation_axis = false
			colliding_axis = null
	else:
		gather_colliding_axis()
	
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
		save_plane()
		calculate_grab_offset()
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.AXIS && GizmoRoot.mouse_hover_detected.translation_axis:
		place_ortho()
	
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
