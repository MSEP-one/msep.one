extends Node2D

const RAY_LENGTH = 1000000.0
const EPSILON = .0001
const FULL_R_CIRCLE = 2.0 * PI
const MIN_ARC_ROT_DELTA = PI * .5
const FULL_A_CIRCLE = 360.0
const LINE_THICKNESS = 3.0
const SURFACE_COLLISION_RADIUS = 75.0

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

var closest_collision_data: int = -1

var surface_points: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]

var right_offset: float = .125
var up_offset: float = .125
var surface_width: float = .125
var surface_height: float = .125
var colliding_surface_ids: Array[int] = []
var collision_data: Array[Array] = [
#	[
#		surface_id,
#		distance_to_camera_sqrd,
#		is_mouse_hovering,
#		inactive_color,
#		active_color
#	], ...
]

var grab_offset := Vector2.ZERO
var current_plane := Plane(.0, .0, .0, .0)

var relative_scale := Vector2.ONE


func _ready() -> void:
	z_index = gizmo.z_index_root - 3


func gather_colliding_surfaces() -> void:
	colliding_surface_ids.clear()
	prepare_surface_points(x_axis, y_axis, 0)
	prepare_surface_points(z_axis, y_axis, 1)
	prepare_surface_points(x_axis, z_axis, 2)
	
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
		
		var viewport_rect = get_viewport_rect()
		var mouse_pos = get_viewport().get_mouse_position()
		if !viewport_rect.has_point(mouse_pos):
			GizmoRoot.mouse_hover_detected.translation_surface = false
			closest_collision_data = -1
			return
		
		collision_data.clear()
		var is_colliding: bool = is_surface_id_colliding(0)
		var distance_to_camera_sqrd: float = camera.global_position.distance_squared_to(x_axis.global_position)
		collision_data.append([
			0,
			distance_to_camera_sqrd,
			is_colliding,
			gizmo.inactive_z_color,
			gizmo.active_z_color
		])
		is_colliding = is_surface_id_colliding(1)
		distance_to_camera_sqrd = camera.global_position.distance_squared_to(y_axis.global_position)
		collision_data.append([
			1,
			distance_to_camera_sqrd,
			is_colliding,
			gizmo.inactive_x_color,
			gizmo.active_x_color
		])
		is_colliding = is_surface_id_colliding(2)
		distance_to_camera_sqrd = camera.global_position.distance_squared_to(z_axis.global_position)
		collision_data.append([
			2,
			distance_to_camera_sqrd,
			is_colliding,
			gizmo.inactive_y_color,
			gizmo.active_y_color
		])
		
		collision_data.sort_custom(sort_descending_collision_data)
		
		GizmoRoot.mouse_hover_detected.translation_surface = false
		closest_collision_data = -1

		var i: int = 0
		for coll in collision_data:
			if coll[2]:
				closest_collision_data = i
			i += 1
			
		if closest_collision_data != -1:
			GizmoRoot.mouse_hover_detected.translation_surface = true
			GizmoRoot.collision_mode = GizmoRoot.CollisionMode.SURFACE
		
		var translation_axis_colliding: bool = GizmoRoot.mouse_hover_detected.translation_axis
		var scale_axis_colliding: bool = GizmoRoot.mouse_hover_detected.scale_axis
		var rotation_arcs_colliding: bool = GizmoRoot.mouse_hover_detected.rotation_arcs
		if translation_axis_colliding || scale_axis_colliding || rotation_arcs_colliding:
			GizmoRoot.mouse_hover_detected.translation_surface = false
			closest_collision_data = -1
	


func prepare_surface_points(h_axis: Node3D, v_axis: Node3D, surface_index: int) -> void:
	var h_dir: Vector3 = (h_axis.global_position - gizmo.global_position).normalized()
	var v_dir: Vector3 = (v_axis.global_position - gizmo.global_position).normalized()
	var camera_forward: Vector3 = camera.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD
	var camera_to_selected_node_dir: Vector3 = (GizmoRoot.selected_node.global_position - camera.global_position).normalized()
	var projection_factor: float = camera_forward.dot(camera_to_selected_node_dir)
	if abs(projection_factor) < EPSILON:
		projection_factor = EPSILON * sign(projection_factor)
	
	var gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
	var c_surface_points := PackedVector2Array()
	var surface_origin: Vector3 = gizmo.global_position + h_dir * right_offset + v_dir * up_offset
	var width: Vector3 = h_dir * surface_width
	var heigth: Vector3 = v_dir * surface_height
	var surface_end: Vector3 = surface_origin + width + heigth
	var surface_center: Vector3 = (surface_origin + surface_end) / 2
	var surface_center_2d: Vector2 = (camera.unproject_position(surface_center) - gizmo_position_2d_in_viewport) * relative_scale
	var collision_radius: float = SURFACE_COLLISION_RADIUS * gizmo.gizmo_size_ratio * \
	gizmo.viewport_size_factor
	var collision_radius_sqrd: float = collision_radius * collision_radius
	if get_local_mouse_position().distance_squared_to(surface_center_2d) < collision_radius_sqrd:
		colliding_surface_ids.append(surface_index)
	c_surface_points.append((camera.unproject_position(surface_origin) - gizmo_position_2d_in_viewport) * relative_scale * projection_factor)
	c_surface_points.append((camera.unproject_position(surface_origin + heigth) - gizmo_position_2d_in_viewport) * relative_scale * projection_factor)
	c_surface_points.append((camera.unproject_position(surface_origin + width + heigth) - gizmo_position_2d_in_viewport) * relative_scale * projection_factor)
	c_surface_points.append((camera.unproject_position(surface_origin + width) - gizmo_position_2d_in_viewport) * relative_scale * projection_factor)
	surface_points[surface_index] = c_surface_points


static func sort_descending_collision_data(a: Array, b: Array) -> bool:
	if a[1] > b[1]:
		return true
	return false


func is_surface_id_colliding(in_id: int) -> bool:
	return colliding_surface_ids.has(in_id)


func preserve_dimensions() -> void:
	var rs: Vector2 = gizmo.calculate_relative_scale()
	var rsx: float = rs.x if abs(rs.x) > EPSILON else EPSILON * sign(rs.x)
	var rsy: float = rs.y if abs(rs.y) > EPSILON else EPSILON * sign(rs.y)
	relative_scale = Vector2.ONE / Vector2(rsx, rsy)


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	if !is_instance_valid(camera) || !is_instance_valid(selected_node):
		return
	if collision_data.is_empty():
		return

	draw_surface(0)
	draw_surface(1)
	draw_surface(2)


func draw_surface(id: int) -> void:
	var coll: Array[Variant] = collision_data[id]
	var c_surface_points: PackedVector2Array = surface_points[coll[0]]
	var col: Color = coll[4] if id == closest_collision_data else coll[3]
	if !Geometry2D.triangulate_polygon(c_surface_points).is_empty():
		draw_colored_polygon(c_surface_points, col, PackedVector2Array(), null)


func save_plane() -> void:
	if collision_data.is_empty():
		return
	match collision_data[closest_collision_data][0]:
		0:
			calculate_plane(Vector3.FORWARD)
		1:
			calculate_plane(Vector3.RIGHT)
		2:
			calculate_plane(Vector3.UP)


func calculate_plane(vec_dir: Vector3) -> void:
	var to_local_space_rotation: Quaternion = selected_node.global_transform.basis.get_rotation_quaternion()
	var plane_normal: Vector3 = to_local_space_rotation * vec_dir
	current_plane = Plane(plane_normal, selected_node.global_position)


func calculate_grab_offset() -> void:
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
	if !is_instance_valid(camera) || !is_instance_valid(selected_node):
		return

	preserve_dimensions()
	gather_colliding_surfaces()

	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
		save_plane()
		calculate_grab_offset()
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.SURFACE && GizmoRoot.mouse_hover_detected.translation_surface:
		place_on_plane()


func update_drawing() -> void:
	global_position = camera.unproject_position(selected_node.global_position)
	queue_redraw()


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
						if GizmoRoot.mouse_hover_detected.translation_surface && GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
							GizmoRoot.grab_mode = GizmoRoot.GrabMode.SURFACE
