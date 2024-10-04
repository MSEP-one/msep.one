extends Node2D

const HIDE_SURFACE_DISTANCE: float = 10000.0
const RAY_LENGTH: float = 1000000.0
const EPSILON: float = .0001
const FULL_R_CIRCLE: float = 2.0 * PI
const MIN_ARC_ROT_DELTA: float = PI * .5
const FULL_A_CIRCLE: float = 360.0
const LINE_THICKNESS: float = 3.0
const SURFACE_COLLISION_RADIUS: float = 80.0
const COLOR_ALPHA_THRESHOLD: Vector2 = Vector2(30.0, 35.0)
const CUT_AT_CENTER_HIDE_VALUE: Vector2 = Vector2.ONE * 1000000.0
const VERTEX_AMOUNT: int = 4
const ANTI_ALIAS_SMOOTH_BOUNDS: Vector2 = Vector2(.04, .2)
const ANTI_ALIAS_SMOOTH_OFFSET: Vector2 = Vector2(.25, .75)
const ANTI_ALIAS_VERTEX_OFFSET_FACTOR: float = .8
# This is right in the middle between individual axis z depth being in front of each other or behind
# everything else. In the future perhaps could thing of even regularity between different gizmo
# elements. As this work well for the current gizmo, but if we decide to add more elements some
# constants in some of the elements might have to be adjusted.
const SURFACES_Z_INDEX_OFFSET: int = 3

@onready var gizmo: Node3D = owner
@onready var x_axis: Node3D = %X
@onready var y_axis: Node3D = %Y
@onready var z_axis: Node3D = %Z
# Used as a collection of Node2D
@onready var draw_axes: Array[Node] = [get_node("DrawX"), get_node("DrawY"), get_node("DrawZ")]

var camera: Camera3D:
	get:
		return GizmoRoot.camera_3D
var selected_node: Node3D:
	get:
		return GizmoRoot.selected_node

var closest_collision_data: int = -1

var surface_points: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]

var right_offset: float = .25
var up_offset: float = .25
var surface_width: float = .12
var surface_height: float = .12
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
	z_index = gizmo.z_index_root - SURFACES_Z_INDEX_OFFSET


func gather_colliding_surfaces() -> void:
	colliding_surface_ids.clear()
	
	var camera_rotation: Quaternion = camera.global_transform.basis.get_rotation_quaternion()
	prepare_surface_points(camera_rotation * Vector3.RIGHT, camera_rotation * Vector3.UP, 0)
	prepare_surface_points(camera_rotation * -Vector3.FORWARD * HIDE_SURFACE_DISTANCE, \
			camera_rotation * Vector3.UP * HIDE_SURFACE_DISTANCE, 1)
	prepare_surface_points(camera_rotation * Vector3.RIGHT * HIDE_SURFACE_DISTANCE, \
			camera_rotation * -Vector3.FORWARD * HIDE_SURFACE_DISTANCE, 2)
	
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
		
		var active_color_is_allowed: bool = GizmoRoot.input_is_allowed
		if !active_color_is_allowed:
			active_color_is_allowed = GizmoRoot.grab_mode != GizmoRoot.GrabMode.NONE
		
		collision_data.append([
			0,
			distance_to_camera_sqrd,
			is_colliding,
			gizmo.inactive_z_color,
			gizmo.active_z_color if active_color_is_allowed else gizmo.inactive_z_color
		])
		is_colliding = is_surface_id_colliding(1)
		distance_to_camera_sqrd = camera.global_position.distance_squared_to(y_axis.global_position)
		collision_data.append([
			1,
			distance_to_camera_sqrd,
			is_colliding,
			gizmo.inactive_x_color,
			gizmo.active_x_color if active_color_is_allowed else gizmo.inactive_x_color
		])
		is_colliding = is_surface_id_colliding(2)
		distance_to_camera_sqrd = camera.global_position.distance_squared_to(z_axis.global_position)
		collision_data.append([
			2,
			distance_to_camera_sqrd,
			is_colliding,
			gizmo.inactive_y_color,
			gizmo.active_y_color if active_color_is_allowed else gizmo.inactive_y_color
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
		if ((translation_axis_colliding || scale_axis_colliding) && \
				!gizmo.active_axis_is_pointing_away) || rotation_arcs_colliding:
			GizmoRoot.mouse_hover_detected.translation_surface = false
			closest_collision_data = -1


func prepare_surface_points(in_h_dir: Vector3, in_v_dir: Vector3, in_surface_index: int) -> void:
	var camera_forward: Vector3 = camera.global_transform.basis.get_rotation_quaternion() * \
			Vector3.FORWARD
	var camera_to_selected_node_dir: Vector3 = (GizmoRoot.selected_node.global_position - \
			camera.global_position).normalized()
	var projection_factor: float = camera_forward.dot(camera_to_selected_node_dir)
	if abs(projection_factor) < EPSILON:
		projection_factor = EPSILON * sign(projection_factor)
	
	var gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
	var surface_origin: Vector3 = gizmo.global_position + in_h_dir * right_offset + in_v_dir * up_offset
	var width: Vector3 = in_h_dir * surface_width
	var height: Vector3 = in_v_dir * surface_height
	var surface_end: Vector3 = surface_origin + width + height
	var surface_center: Vector3 = (surface_origin + surface_end) * .5
	var surface_center_2d: Vector2 = (camera.unproject_position(surface_center) - \
			gizmo_position_2d_in_viewport) * relative_scale
	
	var collision_radius: float = SURFACE_COLLISION_RADIUS * gizmo.gizmo_size_ratio * \
	gizmo.viewport_size_factor
	var collision_radius_sqrd: float = collision_radius * collision_radius
	
	var c_surface_points: PackedVector2Array = []
	for i in range (0, VERTEX_AMOUNT):
		c_surface_points.append(CUT_AT_CENTER_HIDE_VALUE)
	
	var surface_origin_2d: Vector2 = camera.unproject_position(surface_origin)
	
	if surface_origin_2d.distance_to(gizmo_position_2d_in_viewport) > COLOR_ALPHA_THRESHOLD.x \
			* gizmo.viewport_size_factor:
		if get_local_mouse_position().distance_squared_to(surface_center_2d) < collision_radius_sqrd:
			colliding_surface_ids.append(in_surface_index)
		c_surface_points[0] = ((camera.unproject_position(surface_origin) - \
				gizmo_position_2d_in_viewport) * relative_scale * projection_factor)
		c_surface_points[1] = ((camera.unproject_position(surface_origin + height) - \
				gizmo_position_2d_in_viewport) * relative_scale * projection_factor)
		c_surface_points[2] = ((camera.unproject_position(surface_origin + width + height) - \
				gizmo_position_2d_in_viewport) * relative_scale * projection_factor)
		c_surface_points[3] = ((camera.unproject_position(surface_origin + width) - \
				gizmo_position_2d_in_viewport) * relative_scale * projection_factor)
	
	surface_points[in_surface_index] = c_surface_points


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
	
	draw_axes[0].update_drawing(0, collision_data[0][0])
	draw_axes[1].update_drawing(1, collision_data[1][0])
	draw_axes[2].update_drawing(2, collision_data[2][0])


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


func calculate_plane(vec_dir) -> void:
	var plane_normal: Vector3 = camera.global_transform.basis.get_rotation_quaternion() * vec_dir
	
	current_plane = Plane(plane_normal, selected_node.global_position) # Plane(normal, point)


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


func _calculate_state() -> void:
	if GizmoRoot.gizmo_state == GizmoRoot.GizmoState.DISABLED:
		return
	
	if !is_instance_valid(camera) || !is_instance_valid(selected_node):
		return
	
	preserve_dimensions()
	gather_colliding_surfaces()
	
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
		save_plane()
		calculate_grab_offset()
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.SURFACE && GizmoRoot.mouse_hover_detected.translation_surface:
		place_on_plane()


func _process(_delta: float) -> void:
	if GizmoRoot.mouse_hover_detected.translation_surface:
		_calculate_state()
	else:
		_calculate_state.call_deferred()


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
