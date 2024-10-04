extends Node2D

const PREVENT_AXIS_LOCK_STEP_RATIO = 90.0
const EPSILON = .0001
const FULL_R_CIRCLE = 2.0 * PI
const MIN_ARC_ROT_DELTA = PI * .5
const FULL_A_CIRCLE = 360.0
const LINE_THICKNESS = 3.0
const COLLISION_RADIUS_FACTOR = 21.0

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

var previous_mouse_position := Vector2.ZERO
var circle_size: float = .6
var arc_step_amount: float = 128

var xyz_arc_points: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), \
		PackedVector2Array()]
var in_coll_depths := PackedVector3Array()

var closest_colliding_arc: int = -1

var arc_rot_angle: float = .0
var prev_ar_angle: float = .0
var is_rotating := false

var prevent_axis_locking_dir := Vector2.ZERO
var is_camera_at_node_level := false

var relative_scale := Vector2.ONE


func _ready() -> void:
	z_index = gizmo.z_index_root
	
	for i in range(0, 3):
		in_coll_depths.push_back(Vector3(INF, INF, INF))


func calculate_single_arc(axis: Node3D, perpendicular_vec: Vector3, dir_vec: Vector3, arc_index: int) -> void:
	var arc_points := PackedVector2Array()
	
	var gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
	var current_rotation := Quaternion.IDENTITY
	var rotation_step: float = (FULL_R_CIRCLE) / arc_step_amount
	var rotation_progress: float = .0
	var camera_forward: Vector3 = camera.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD
	var collision_radius: float = FULL_A_CIRCLE / arc_step_amount * COLLISION_RADIUS_FACTOR * \
	gizmo.gizmo_size_ratio * gizmo.viewport_size_factor
	var collision_radius_sqrd: float = collision_radius * collision_radius
	var rel_size: float = circle_size
	var local_mouse_position := get_local_mouse_position()
	for i in range(0, arc_step_amount):
		var vertex_offset: Vector3 = gizmo.global_transform.basis.get_rotation_quaternion() * current_rotation * perpendicular_vec
		if camera_forward.dot(vertex_offset) < EPSILON:
			var vertex_global_pos: Vector3 = gizmo.global_position + vertex_offset * rel_size
			var vertex_position_2d: Vector2 = camera.unproject_position(vertex_global_pos)
			arc_points.append(vertex_position_2d)
			
			var vertex_position_2d_in_viewport: Vector2 = (vertex_position_2d - gizmo_position_2d_in_viewport) * relative_scale
			# Mouse hit test
			if local_mouse_position.distance_squared_to(vertex_position_2d_in_viewport) < collision_radius_sqrd:
				in_coll_depths[arc_index] = vertex_global_pos
		
		rotation_progress += rotation_step
		current_rotation = Quaternion(dir_vec, rotation_progress)
	
	xyz_arc_points[arc_index] = arc_points
	

func draw_single_arc(color: Color, arc_index: int) -> void:
	var arc_points: PackedVector2Array = xyz_arc_points[arc_index]
	var vertex_count: int = arc_points.size()
	var force_closed: bool = true if vertex_count > arc_step_amount * .8 else false
	if vertex_count > 1:
		var max_segment_length_sqrd: float = arc_points[0].distance_squared_to(arc_points[vertex_count-1])
		for i in range(0, vertex_count - 1):
			var segment_length_sqrd: float = arc_points[i].distance_squared_to(arc_points[i + 1])
			if segment_length_sqrd > max_segment_length_sqrd:
				max_segment_length_sqrd = segment_length_sqrd
		
		draw_line_segment(arc_points[0], arc_points[vertex_count-1], max_segment_length_sqrd, color, force_closed)
		for i in range(0, vertex_count - 1):
			var from: Vector2 = arc_points[i]
			var to: Vector2 = arc_points[i + 1]
			draw_line_segment(from, to, max_segment_length_sqrd, color, force_closed)


func draw_line_segment(from: Vector2, to: Vector2, max_segment_length_sqrd: float, col: Color, force_closed: bool) -> void:
	var gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
	if from.distance_squared_to(to) < max_segment_length_sqrd || force_closed:
		# transform from 2d global space to local space
		from = (from - gizmo_position_2d_in_viewport) * relative_scale
		to = (to - gizmo_position_2d_in_viewport) * relative_scale
		draw_line(from, to, col, LINE_THICKNESS, false)


func draw_reference_arc() -> void:
	var center: Vector3 = gizmo.global_position
	var current_rotation: Quaternion = camera.global_transform.basis.get_rotation_quaternion()
	var vertex: Vector3 = Vector3.ZERO
	var rel_size: float = circle_size
	var previous_vertex: Vector3 = current_rotation * Vector3.RIGHT * rel_size
	var step_rotation := Quaternion(Vector3.FORWARD, FULL_R_CIRCLE / arc_step_amount)
	var gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
	
	for i in range(0, arc_step_amount):
		current_rotation = current_rotation * step_rotation
		vertex = current_rotation * Vector3.RIGHT * rel_size
		var vertex_position_2d: Vector2 = (camera.unproject_position(center + vertex) - gizmo_position_2d_in_viewport) * relative_scale
		var previous_vertex_position_2d: Vector2 = (camera.unproject_position(center + previous_vertex) - gizmo_position_2d_in_viewport) * relative_scale
		draw_line(previous_vertex_position_2d, vertex_position_2d, gizmo.reference_arc_color, 1.0, false)
		previous_vertex = vertex


func preserve_dimensions() -> void:
	var rs: Vector2 = gizmo.calculate_relative_scale()
	var rsx: float = rs.x if abs(rs.x) > EPSILON else EPSILON * sign(rs.x)
	var rsy: float = rs.y if abs(rs.y) > EPSILON else EPSILON * sign(rs.y)
	relative_scale = Vector2.ONE / Vector2(rsx, rsy)
	previous_mouse_position = get_viewport().get_mouse_position()


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	if !is_instance_valid(camera):
		return
	draw_reference_arc()
	var active_colors: Array[Color] = [
		gizmo.active_x_color,
		gizmo.active_y_color,
		gizmo.active_z_color
	]
	var inactive_colors: Array[Color] = [
		gizmo.inactive_x_color,
		gizmo.inactive_y_color,
		gizmo.inactive_z_color
	]
	for arc_index in [Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z]:
		var col: Color = active_colors[arc_index] if closest_colliding_arc == arc_index else inactive_colors[arc_index]
		draw_single_arc(col, arc_index)
		if is_rotating && arc_index == closest_colliding_arc:
			draw_line(Vector2.ZERO, get_local_mouse_position(), col, LINE_THICKNESS, false)


func gather_colliding_axis() -> void:
	for i in range(0, 3):
		in_coll_depths[i] = Vector3(INF, INF, INF)
	
	if !is_instance_valid(selected_node) || !is_instance_valid(camera):
		return
	
	calculate_single_arc(x_axis, Vector3.FORWARD, Vector3.RIGHT, Vector3.AXIS_X)
	calculate_single_arc(y_axis, Vector3.FORWARD, Vector3.UP, Vector3.AXIS_Y)
	calculate_single_arc(z_axis, Vector3.UP, Vector3.FORWARD, Vector3.AXIS_Z)
	
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
		closest_colliding_arc = -1
		GizmoRoot.mouse_hover_detected.rotation_arcs = false
		
		var viewport_rect = get_viewport_rect()
		var mouse_pos = get_viewport().get_mouse_position()
		if !viewport_rect.has_point(mouse_pos):
			return
		
		
		if GizmoRoot.mouse_hover_detected.translation_axis || GizmoRoot.mouse_hover_detected.scale_axis:
			return
		
		var closest_distance_sqrd: float = 0
		for i in range(0, 3):
			if !is_inf(in_coll_depths[i].x):
				var distance_to_camera: float = in_coll_depths[i].distance_squared_to(camera.global_position)
				if distance_to_camera < closest_distance_sqrd || closest_colliding_arc == -1:
					closest_colliding_arc = i
					closest_distance_sqrd = distance_to_camera
		
		if closest_colliding_arc != -1:
			GizmoRoot.mouse_hover_detected.rotation_arcs = true
			GizmoRoot.collision_mode = GizmoRoot.CollisionMode.ARC
		



func detect_camera_at_node_level(vec_dir) -> void:
	var to_local_space_quaternion: Quaternion = selected_node.global_transform.basis.get_rotation_quaternion()
	vec_dir = to_local_space_quaternion * vec_dir
	var camera_to_selected_node_dir: Vector3 = (selected_node.global_position - camera.global_position).normalized()
	if abs(camera_to_selected_node_dir.dot(vec_dir)) < EPSILON:
		is_camera_at_node_level = true
	else:
		is_camera_at_node_level = false


func manage_arc_rotation() -> void:
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.ARC && GizmoRoot.mouse_hover_detected.rotation_arcs:
		var local_mouse_position: Vector2 = get_local_mouse_position()
		prev_ar_angle = arc_rot_angle
		arc_rot_angle = atan2(-local_mouse_position.y, -local_mouse_position.x)
		var to_local_space_quaternion: Quaternion = selected_node.global_transform.basis.get_rotation_quaternion()
		var tmp_scale: Vector3 = selected_node.scale
		selected_node.orthonormalize()
		selected_node.scale = tmp_scale
		match closest_colliding_arc:
			0:
				if (!is_rotating):
					detect_camera_at_node_level(Vector3.RIGHT)
				
				var rotation_delta: float = calculate_rotation_step(to_local_space_quaternion, Vector3.RIGHT)
				if gizmo.rotate_back_on_negative_scale && selected_node.scale.x < .0:
					rotation_delta = -rotation_delta
				selected_node.rotate_object_local(Vector3.RIGHT, rotation_delta)
			1:
				if (!is_rotating):
					detect_camera_at_node_level(Vector3.UP)
				
				var rotation_delta: float = calculate_rotation_step(to_local_space_quaternion, Vector3.UP)
				if gizmo.rotate_back_on_negative_scale && selected_node.scale.y < .0:
					rotation_delta = -rotation_delta
				selected_node.rotate_object_local(Vector3.UP, rotation_delta)
			2:
				if (!is_rotating):
					detect_camera_at_node_level(Vector3.FORWARD)
				
				var rotation_delta: float = calculate_rotation_step(to_local_space_quaternion, Vector3.FORWARD)
				if gizmo.rotate_back_on_negative_scale && selected_node.scale.z < .0:
					rotation_delta = -rotation_delta
				selected_node.rotate_object_local(Vector3.FORWARD, rotation_delta)
		
		is_rotating = true
	else:
		is_rotating = false


func calculate_rotation_step(to_local_space_quaternion, vec_dir) -> float:
	vec_dir = to_local_space_quaternion * vec_dir
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	if is_rotating:
		var angle_delta: float = arc_rot_angle - prev_ar_angle
		
		if is_camera_at_node_level:
			angle_delta = mouse_position.distance_to(previous_mouse_position) / PREVENT_AXIS_LOCK_STEP_RATIO
			if (mouse_position - previous_mouse_position).normalized().dot(prevent_axis_locking_dir) < .0:
				angle_delta = -angle_delta
		else:
			var camera_to_selected_node_dir: Vector3 = (gizmo.global_position - camera.global_position).normalized()
			var ud: float = vec_dir.dot(camera_to_selected_node_dir)
			angle_delta = angle_delta if ud > .0 else -angle_delta
		
		if abs(angle_delta) > MIN_ARC_ROT_DELTA:
			angle_delta = .0
		
		return angle_delta
	else:
		var gizmo_position_2d_in_viewport: Vector2 = camera.unproject_position(selected_node.global_position)
		var vec_dir_2d: Vector2 = camera.unproject_position(vec_dir)
		var dir: Vector2 = (vec_dir_2d - gizmo_position_2d_in_viewport).normalized()
		prevent_axis_locking_dir = Vector2(-dir.y, dir.x)
		return .0


func _process(_delta: float) -> void:
	preserve_dimensions()
	gather_colliding_axis()
	manage_arc_rotation()


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
						if GizmoRoot.mouse_hover_detected.rotation_arcs && GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
							GizmoRoot.grab_mode = GizmoRoot.GrabMode.ARC
