extends Node2D

const CONSTANT_COLOR_GRADIENT_RATE: float = .5
const PREVENT_AXIS_LOCK_STEP_RATIO: float = 90.0
const EPSILON: float = .001
const FULL_R_CIRCLE: float = 2.0 * PI
const MIN_ARC_ROT_DELTA: float = PI * .5
const FULL_A_CIRCLE: float = 360.0
const LINE_THICKNESS: float = 3.0
const REFERENCE_LINE_THICKNESS: float = 2.0
# The more steps there are, the larger this value must be.
const COLLISION_RADIUS_FACTOR: float = 30.0
const COLOR_ALPHA_THRESHOLD: Vector2 = Vector2(29.8, 30.0)
const COLLISION_STEP_GAP: int = 5
const ARC_STEP_AMOUNT: int = 148
const REFERENCE_ARC_STEP_AMOUNT: int = 128
# If this is too small then inner part may start to overlap with the reference arc.
const REFERENCE_ARC_RADIUS_FACTOR: float = 1.038

var camera: Camera3D:
	get:
		return GizmoRoot.camera_3D
var selected_node: Node3D:
	get:
		return GizmoRoot.selected_node

var previous_mouse_position := Vector2.ZERO
var circle_size: float = .6

var xyz_arc_points: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), \
		PackedVector2Array()]
var xyz_arc_color_factors: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), \
		PackedFloat32Array()]
var in_coll_depths := PackedVector3Array()

var closest_colliding_arc: int = -1

var arc_rot_angle: float = .0
var prev_ar_angle: float = .0
var is_rotating := false

var prevent_axis_locking_dir := Vector2.ZERO
var is_camera_at_node_level := false

var relative_scale := Vector2.ONE

var color_alpha_delta: float = .0
var gizmo_position_2d_in_viewport: Vector2 = Vector2.ZERO

var old_angle: float = .0

@onready var gizmo: Node3D = owner
@onready var x_axis: Node3D = %X
@onready var y_axis: Node3D = %Y
@onready var z_axis: Node3D = %Z


func _ready() -> void:
	for i in range(0, 3):
		in_coll_depths.append(Vector3(INF, INF, INF))
	
	color_alpha_delta = abs(abs(COLOR_ALPHA_THRESHOLD.x * gizmo.viewport_size_factor) - \
			abs(COLOR_ALPHA_THRESHOLD.y * gizmo.viewport_size_factor))


func calculate_single_arc(axis: Node3D, perpendicular_vec: Vector3, dir_vec: Vector3, \
		arc_index: int, in_local_mouse_position: Vector2) -> void:
	var arc_points := PackedVector2Array()
	var arc_color_factors := PackedFloat32Array()
	var current_rotation := Quaternion.IDENTITY
	var rotation_step: float = (FULL_R_CIRCLE) / ARC_STEP_AMOUNT
	var rotation_progress: float = .0
	var camera_forward: Vector3 = camera.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD
	var collision_radius: float = FULL_A_CIRCLE / ARC_STEP_AMOUNT * COLLISION_RADIUS_FACTOR * \
	gizmo.gizmo_size_ratio * gizmo.viewport_size_factor
	var collision_radius_sqrd: float = collision_radius * collision_radius
	var rel_size: float = circle_size
	for i in range(0, ARC_STEP_AMOUNT):
		var vertex_offset: Vector3 = current_rotation * perpendicular_vec
		var offset_dot: float = camera_forward.dot(vertex_offset)
		
		var vertex_global_pos: Vector3 = gizmo.global_position + vertex_offset * rel_size
		var vertex_position_2d: Vector2 = camera.unproject_position(vertex_global_pos)
		arc_points.append(vertex_position_2d - gizmo_position_2d_in_viewport)
		
		if offset_dot < EPSILON:
			arc_color_factors.append(offset_dot)
			
			if i % COLLISION_STEP_GAP == 0:
				var color_alpha_threshold_squared: float = pow(COLOR_ALPHA_THRESHOLD.x * \
						gizmo.viewport_size_factor, 2)
				if vertex_position_2d.distance_squared_to(gizmo_position_2d_in_viewport) > \
						color_alpha_threshold_squared:
					var vertex_local_position_2d: Vector2 = (vertex_position_2d - \
							gizmo_position_2d_in_viewport) * relative_scale
					# Mouse hit test
					if in_local_mouse_position.distance_squared_to(vertex_local_position_2d) < \
							collision_radius_sqrd && in_local_mouse_position.length_squared() > \
									color_alpha_threshold_squared:
						in_coll_depths[arc_index] = vertex_global_pos
		else:
			arc_color_factors.append(.0)
		
		rotation_progress += rotation_step
		current_rotation = Quaternion(dir_vec, rotation_progress)
	
	arc_points.append(arc_points[0])
	arc_color_factors.append(arc_color_factors[0])
	
	xyz_arc_points[arc_index] = arc_points
	xyz_arc_color_factors[arc_index] = arc_color_factors


func draw_single_arc(color: Color, arc_index: int) -> void:
	var arc_points: PackedVector2Array = xyz_arc_points[arc_index]
	var arc_color_factors: PackedFloat32Array = xyz_arc_color_factors[arc_index]
	var vertex_count: int = arc_points.size()
	if vertex_count > 1:
		var polyline_points: PackedVector2Array = []
		var polyline_colors: PackedColorArray = []
		
		var gradient_start_index: int = 0
		
		if abs(arc_color_factors[0]) > EPSILON && abs(arc_color_factors[vertex_count - 1]) < EPSILON:
			gradient_start_index = 0
		else:
			for i in range(1, vertex_count):
				if abs(arc_color_factors[i]) > EPSILON && abs(arc_color_factors[i - 1]) < EPSILON:
					gradient_start_index = i
					break
		for i in range(gradient_start_index, vertex_count):
			if abs(arc_color_factors[i]) > EPSILON:
				polyline_points.append(arc_points[i])
			else:
				break
		for i in range(0, vertex_count):
			if abs(arc_color_factors[i]) > EPSILON:
				polyline_points.append(arc_points[i])
			else:
				break
		
		var polyline_size: int = polyline_points.size()
		if polyline_size > 1:
			var half_polyline_size: int = polyline_size / 2
			var gradient_step: float = PI / polyline_size
			for i in range(0, polyline_size):
				if i < half_polyline_size:
					var gradient_rate: float = max(gradient_step * i - .5, .0)
					polyline_colors.append(color + color * gradient_rate)
				else:
					var gradient_rate: float = max(gradient_step * (polyline_size - i) - .5, .0)
					polyline_colors.append(color + color * gradient_rate)
				polyline_colors[i].a = 1.0
			polyline_colors[0].a = .0
			polyline_colors[polyline_size - 1].a = .0
				
			for i in range(0, polyline_size - 1):
				var arc_point_offset_distance: float = (polyline_points[i].length() + polyline_points[i + 1].length()) * .5
				var color_alpha_factor: float = clamp((arc_point_offset_distance - COLOR_ALPHA_THRESHOLD.x \
						* gizmo.viewport_size_factor) / color_alpha_delta, .0, 1.0)
				# To disable fade into cutout.
				color_alpha_factor = floor(color_alpha_factor)
				polyline_colors[i].a *= color_alpha_factor
			
			# To center around cutout circle.
			for i in range(0, polyline_size - 1):
				polyline_points[i] = polyline_points[i] + (polyline_points[i + 1] - \
						polyline_points[i]) * .55
			
			draw_polyline_colors(polyline_points, polyline_colors, LINE_THICKNESS, true)


func draw_reference_arc() -> void:
	var center: Vector3 = gizmo.global_position
	var current_rotation: Quaternion = camera.global_transform.basis.get_rotation_quaternion()
	var vertex: Vector3 = Vector3.ZERO
	var rel_size: float = circle_size
	var previous_vertex: Vector3 = current_rotation * Vector3.RIGHT * rel_size
	var reference_diameter_step_amount: int = 4
	var step_rotation: Quaternion = Quaternion(Vector3.FORWARD, FULL_R_CIRCLE / \
			reference_diameter_step_amount)
	var previous_vertex_position_2d: Vector2 = (camera.unproject_position(center + previous_vertex) \
			- gizmo_position_2d_in_viewport) * relative_scale
	var diameter_start_position: Vector2 = Vector2.ZERO
	var diameter_end_position: Vector2 = Vector2.ZERO
	
	for i in range(0, reference_diameter_step_amount):
		current_rotation = current_rotation * step_rotation
		vertex = current_rotation * Vector3.RIGHT * rel_size
		var vertex_position_2d: Vector2 = (camera.unproject_position(center + vertex) - \
				gizmo_position_2d_in_viewport) * relative_scale
		if i == 0:
			diameter_start_position = vertex_position_2d
		elif i == 2:
			diameter_end_position = vertex_position_2d
		previous_vertex = vertex
		previous_vertex_position_2d = vertex_position_2d
	
	var reference_arc_radius: float = diameter_start_position.distance_to(diameter_end_position) \
			* .5 * REFERENCE_ARC_RADIUS_FACTOR
	draw_arc(Vector2.ZERO, reference_arc_radius, .0, FULL_R_CIRCLE, REFERENCE_ARC_STEP_AMOUNT, \
			Color.WHITE, REFERENCE_LINE_THICKNESS, true)


func preserve_dimensions() -> void:
	if GizmoRoot.gizmo_state == GizmoRoot.GizmoState.DISABLED:
		return
	
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
	
	var active_color_is_allowed: bool = GizmoRoot.input_is_allowed
	if !active_color_is_allowed:
		active_color_is_allowed = GizmoRoot.grab_mode != GizmoRoot.GrabMode.NONE
	
	var active_colors: Array[Color] = [
	gizmo.active_x_color if active_color_is_allowed else gizmo.inactive_x_color,
	gizmo.active_y_color if active_color_is_allowed else gizmo.inactive_y_color,
	gizmo.active_z_color if active_color_is_allowed else gizmo.inactive_z_color,
	]
	var inactive_colors: Array[Color] = [
	gizmo.inactive_x_color,
	gizmo.inactive_y_color,
	gizmo.inactive_z_color
	]
	for arc_index in [Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z]:
		var col: Color = inactive_colors[arc_index]
		if closest_colliding_arc == arc_index && Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			col = active_colors[arc_index]
		draw_single_arc(col, arc_index)
		if is_rotating && arc_index == closest_colliding_arc:
			draw_line(Vector2.ZERO, get_local_mouse_position(), col, LINE_THICKNESS, true)


func gather_colliding_axis() -> void:
	if GizmoRoot.gizmo_state == GizmoRoot.GizmoState.DISABLED:
		return
	
	for i in range(0, 3):
		in_coll_depths[i] = Vector3(INF, INF, INF)
	
	if !is_instance_valid(selected_node) || !is_instance_valid(camera):
		return
	
	var local_mouse_position := get_local_mouse_position()
	calculate_single_arc(x_axis, Vector3.FORWARD, Vector3.RIGHT, Vector3.AXIS_X, local_mouse_position)
	calculate_single_arc(y_axis, Vector3.FORWARD, Vector3.UP, Vector3.AXIS_Y, local_mouse_position)
	calculate_single_arc(z_axis, Vector3.UP, Vector3.FORWARD, Vector3.AXIS_Z, local_mouse_position)
	
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
		closest_colliding_arc = -1
		GizmoRoot.mouse_hover_detected.rotation_arcs = false
		
		var viewport_rect = get_viewport_rect()
		var mouse_pos = get_viewport().get_mouse_position()
		if !viewport_rect.has_point(mouse_pos):
			return
		
		if (GizmoRoot.mouse_hover_detected.translation_axis || \
				GizmoRoot.mouse_hover_detected.scale_axis) && \
				!gizmo.active_axis_is_pointing_away:
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
	


func detect_camera_at_node_level(vec_dir: Vector3) -> void:
	var camera_to_selected_node_dir: Vector3 = (selected_node.global_position - camera.global_position).normalized()
	if abs(camera_to_selected_node_dir.dot(vec_dir)) < EPSILON:
		is_camera_at_node_level = true
	else:
		is_camera_at_node_level = false


func manage_arc_rotation() -> void:
	if GizmoRoot.gizmo_state == GizmoRoot.GizmoState.DISABLED:
		return
	
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.ARC && GizmoRoot.mouse_hover_detected.rotation_arcs:
		var local_mouse_position: Vector2 = get_local_mouse_position()
		prev_ar_angle = arc_rot_angle
		arc_rot_angle = atan2(-local_mouse_position.y, -local_mouse_position.x)
		var tmp_scale: Vector3 = selected_node.scale
		selected_node.orthonormalize()
		selected_node.scale = tmp_scale
		match closest_colliding_arc:
			0:
				if (!is_rotating):
					detect_camera_at_node_level(Vector3.RIGHT)
				
				var rotation_delta: float = calculate_rotation_step(Vector3.RIGHT)
				if gizmo.rotate_back_on_negative_scale && selected_node.scale.x < .0:
					rotation_delta = -rotation_delta
				selected_node.global_rotate(Vector3.RIGHT, rotation_delta)
			1:
				if (!is_rotating):
					detect_camera_at_node_level(Vector3.UP)
				
				var rotation_delta: float = calculate_rotation_step(Vector3.UP)
				if gizmo.rotate_back_on_negative_scale && selected_node.scale.y < .0:
					rotation_delta = -rotation_delta
				selected_node.global_rotate(Vector3.UP, rotation_delta)
			2:
				if (!is_rotating):
					detect_camera_at_node_level(Vector3.FORWARD)
				
				var rotation_delta: float = calculate_rotation_step(Vector3.FORWARD)
				if gizmo.rotate_back_on_negative_scale && selected_node.scale.z < .0:
					rotation_delta = -rotation_delta
				selected_node.global_rotate(Vector3.FORWARD, rotation_delta)
		
		is_rotating = true
	else:
		is_rotating = false


func calculate_rotation_step(vec_dir: Vector3) -> float:
	var mouse_position = get_viewport().get_mouse_position()
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
		var vec_dir_2d: Vector2 = camera.unproject_position(vec_dir)
		var dir: Vector2 = (vec_dir_2d - gizmo_position_2d_in_viewport).normalized()
		prevent_axis_locking_dir = Vector2(-dir.y, dir.x)
		return .0


func determine_z_index() -> void:
	var potential_z_index: int = gizmo.z_index_root + 1
	if gizmo.determine_if_in_cutout_perifery():
		potential_z_index = gizmo.draw_in_front_z_index
	z_index = potential_z_index


func update_drawing() -> void:
	if !is_instance_valid(camera) ||!is_instance_valid(selected_node):
		return
	determine_z_index()
	gizmo_position_2d_in_viewport = camera.unproject_position(gizmo.global_position)
	gather_colliding_axis.call_deferred()
	
	manage_arc_rotation.call_deferred()
	
	preserve_dimensions.call_deferred()
	
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
