extends Node2D

const ARROW_STEP_AMOUNT: int = 16
const BRIGHTER_COLOR_TRANSITION_FACTOR: float = 3.0
const COLOR_ALPHA_THRESHOLD: Vector2 = Vector2(31.0, 40.0)
# This ensures that fading is separated from geometry and it's possible to fade the arrow out before
# it has overlapped with the cutout circle. It's important, because we draw circle on top of
# everything else (another perhaps better solution would be to draw the outer part of the arrow
# shaft separately with a different z index depth).
const COLOR_ALPHA_FADE_OFFSET: float = 20.0
const LINE_THICKNESS: float = 3.0
const ARROW_TIP_OFFSET: float = 1.25
const OUTER_SHAFT_ARC_OFFSET_FACTOR: float = .24
# It's important for the Node2D to not have relative ordering.
const BEHIND_GIZMO_Z_INDEX_OFFSET: int = 4
const AXIS_DEPTH_INDEX_OFFSET: int = 2
const ANTI_ALIAS_PASS_COUNT: int = 10
const ANTI_ALIAS_SIZE_FACTOR: float = 100000.0 * .75
const CUTOUT_ALPHA_THRESHOLD: float = .99

var axis: Node3D = null
var side_vec: Vector3 = Vector3.ZERO
var front_vec: Vector3 = Vector3.ZERO
var axis_color: Color = Color.BLACK

@onready var gta_behavior: Node2D = %GTABehavior
@onready var arc_inner_arrow_part: Node2D = get_child(0)
@onready var gizmo: Node3D = owner


func update_drawing(in_axis: Node3D, in_side_vec: Vector3, in_front_vec: Vector3, in_axis_color: Color, \
		in_depth_index: int):
	axis = in_axis
	side_vec = in_side_vec
	front_vec = in_front_vec
	axis_color = in_axis_color
	
	var camera_front_direction: Vector3 = \
	gta_behavior.camera.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD
	var at_camera_dot: float = side_vec.dot(camera_front_direction)
	
	# The arrow head should fade before the cut out circle so that it isn't behind it (More info in
	# the const COLOR_ALPHA_FADE_OFFSET description).
	z_index = gizmo.z_index_root - BEHIND_GIZMO_Z_INDEX_OFFSET if at_camera_dot > .0 \
	else gizmo.z_index_root + in_depth_index + AXIS_DEPTH_INDEX_OFFSET
	var camera_to_gizmo_direction: Vector3 = (gizmo.global_position - \
			gta_behavior.camera.global_position).normalized()
	var gizmo_to_node_direction: Vector3 = (axis.global_position - \
			gizmo.global_position).normalized()
	if gizmo.determine_single_axis_in_cutout_perifery(\
			gta_behavior.camera.unproject_position(in_axis.global_position),\
					gta_behavior.camera.unproject_position(gizmo.global_position), \
							camera_to_gizmo_direction, gizmo_to_node_direction):
		z_index = z_index + gizmo.draw_in_front_z_index
	
	queue_redraw()


func draw_axis_arrow() -> void:
	var camera_forward: Vector3 = \
	gta_behavior.camera.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD
	var camera_to_selected_node_dir: Vector3 = (gta_behavior.selected_node.global_position - \
			gta_behavior.camera.global_position).normalized()
	var projection_scale: float = camera_forward.dot(camera_to_selected_node_dir)
	projection_scale = max(abs(projection_scale), gta_behavior.EPSILON) * sign(projection_scale)
	var arrow_base_progress: float = .0
	var axis_amplitude: float = abs(axis.position.x + axis.position.y + axis.position.z)
	var axis_global_position: Vector3 = gizmo.global_position + side_vec * axis_amplitude
	var gizmo_position_2d_in_viewport: Vector2 = global_position
	var axis_local_position_2d: Vector2 = \
	gta_behavior.camera.unproject_position(axis_global_position) - \
			gizmo_position_2d_in_viewport
	var axis_outer_shaft_offset: Vector2 = \
	gta_behavior.camera.unproject_position(axis_global_position + \
			(gizmo.global_position - axis_global_position) * OUTER_SHAFT_ARC_OFFSET_FACTOR) - \
					gizmo_position_2d_in_viewport
	axis_local_position_2d *= gta_behavior.relative_scale
	axis_local_position_2d *= projection_scale
	var tip_from: Vector2 = axis_local_position_2d * ARROW_TIP_OFFSET
	
	var color_alpha_delta: float = abs(abs(COLOR_ALPHA_THRESHOLD.x * \
			gizmo.viewport_size_factor - COLOR_ALPHA_FADE_OFFSET * \
			gizmo.viewport_size_factor) - \
			abs(COLOR_ALPHA_THRESHOLD.y * gizmo.viewport_size_factor))
	var tip_distance_to_gizmo_center: float = tip_from.length()
	
	var color_alpha_factor: float = clamp((tip_distance_to_gizmo_center - COLOR_ALPHA_THRESHOLD.x \
			* gizmo.viewport_size_factor - COLOR_ALPHA_FADE_OFFSET) / \
			color_alpha_delta, .0, 1.0)
	
	if tip_distance_to_gizmo_center < COLOR_ALPHA_THRESHOLD.x * \
	gizmo.viewport_size_factor:
		gta_behavior.dont_detect_collision_axis = axis
	elif color_alpha_factor < 1.0 - CUTOUT_ALPHA_THRESHOLD:
		gta_behavior.dont_detect_collision_axis = axis
	else:
		var mouse_position: Vector2 = get_viewport().get_mouse_position()
		if mouse_position.distance_to(gizmo_position_2d_in_viewport) < COLOR_ALPHA_THRESHOLD.x \
				* gizmo.viewport_size_factor:
			gta_behavior.dont_detect_collision_axis = axis
	
	axis_color.a *= color_alpha_factor
	
	# With the current design it's fine to simply draw arrow shaft before the tip if we want
	# to implement some transparencies though we may consider turning the shaft to be a part of the
	# arrow polygon, so it can be z sorted accordingly.
	var gizmo_center_2d: Vector2 = gta_behavior.camera.unproject_position(gizmo.global_position) - \
			gizmo_position_2d_in_viewport
	arc_inner_arrow_part.update_drawing(gizmo_center_2d + axis_local_position_2d.normalized() \
			* COLOR_ALPHA_THRESHOLD.x * gizmo.viewport_size_factor, \
			axis_outer_shaft_offset, axis_color, LINE_THICKNESS, axis_local_position_2d, \
			camera_to_selected_node_dir, axis_global_position, gizmo.global_position, \
			CUTOUT_ALPHA_THRESHOLD, BEHIND_GIZMO_Z_INDEX_OFFSET)
	
	draw_line(axis_outer_shaft_offset, axis_local_position_2d, axis_color, LINE_THICKNESS, true)
	
	var brighter_transition_color: Color = Color(axis_color.r * BRIGHTER_COLOR_TRANSITION_FACTOR, \
			axis_color.g * BRIGHTER_COLOR_TRANSITION_FACTOR,
			axis_color.b * BRIGHTER_COLOR_TRANSITION_FACTOR, axis_color.a)
	gta_behavior.calculate_arrow_head(gta_behavior.TIP_OFFSET_3D, ARROW_STEP_AMOUNT, \
			axis_global_position, gizmo_position_2d_in_viewport, side_vec, front_vec, [axis_color, \
					brighter_transition_color, brighter_transition_color, axis_color], \
					gta_behavior.ARROW_RADIUS, projection_scale)
	draw_arrow_tip(ARROW_STEP_AMOUNT, axis_global_position, gizmo_position_2d_in_viewport)


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	draw_axis_arrow()


func draw_arrow_tip(in_arrow_steps: int, pos, in_offset):
	# + 2 to fill also the top and the bottom of the arrow head.
	for i in range(0, in_arrow_steps + 2):
		var poly_points: PackedVector2Array = gta_behavior.arrow_tip_sides[i][0]
		var poly_colors: PackedColorArray = gta_behavior.arrow_tip_sides[i][2]
		if !Geometry2D.triangulate_polygon(poly_points).is_empty():
			draw_polygon(poly_points, poly_colors)
