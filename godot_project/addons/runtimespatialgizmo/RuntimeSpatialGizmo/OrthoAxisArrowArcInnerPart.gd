extends Node2D

const HIDE_CONNECTION_THICKNESS_FACTOR: float = 1.1

var line_start_position: Vector2 = Vector2.ZERO
var line_end_position: Vector2 = Vector2.ZERO
var line_color: Color = Color.BLACK
var line_thickness: float = 1.0
var axis_position: Vector2 = Vector2.ZERO
var cutout_alpha_threshold: float = .99

@onready var gizmo: Node3D = owner


func update_drawing(in_line_start_position: Vector2, in_line_end_position: Vector2, \
		in_line_color: Color, in_line_thickness: float, in_axis_position: Vector2, \
		in_camera_to_node_direction: Vector3, in_axis_position3D: Vector3, \
		in_gizmo_position: Vector3, in_cutout_alpha_threshold: float, \
		in_behind_gizmo_z_index_offset: int):
	cutout_alpha_threshold = in_cutout_alpha_threshold
	line_start_position = in_line_start_position
	line_end_position = in_line_end_position
	line_color = in_line_color
	line_thickness = in_line_thickness
	axis_position = in_axis_position
	z_index = gizmo.z_index_root - in_behind_gizmo_z_index_offset
	var axis_direction: Vector3 = (in_axis_position3D - in_gizmo_position).normalized()
	if in_camera_to_node_direction.dot(axis_direction) < .0:
		z_index = gizmo.z_index_root + 1
	queue_redraw()


func draw_inner_part() -> void:
	# To mask the very slight visual artifact where the inner and outer parts meet.
	var cutout_compensated_alpha: float = line_color.a
	if line_color.a < cutout_alpha_threshold:
		cutout_compensated_alpha = line_color.a * (1.0 + (1.0 - line_color.a))
	else:
		cutout_compensated_alpha = line_color.a
	draw_line(line_start_position, axis_position, Color(line_color.r, line_color.g, line_color.b, \
			cutout_compensated_alpha), line_thickness * HIDE_CONNECTION_THICKNESS_FACTOR, true)
	
	if line_color.a > cutout_alpha_threshold:
		draw_line(line_start_position, line_end_position, line_color, line_thickness, true)


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	draw_inner_part()
