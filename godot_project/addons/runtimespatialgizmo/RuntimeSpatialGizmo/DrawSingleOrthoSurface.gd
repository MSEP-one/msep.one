# Some scripts that help the gizmo elements may be happen to be re usable by multiple elements.

# This seems to be one such, currently the DrawSingleGlobalSurface has the same code as this file,
# but it will most likely be removed soon.

extends Node2D

const Z_INDEX_OFFSET: int = 10

var surface_collision_id: int = 0
var collision_data_id: int = 0

@onready var gts_behavior: Node2D = get_parent()
@onready var gizmo: Node3D = owner


func update_drawing(in_surface_collision_id: int, in_collision_data_id: int):
	surface_collision_id = in_surface_collision_id
	collision_data_id = in_collision_data_id
	
	queue_redraw()


func determine_z_index() -> void:
	var h_direction: Vector3 = Vector3.ZERO
	var v_direction: Vector3 = Vector3.ZERO
	var camera_to_gizmo_direction: Vector3 = (gizmo.global_position - \
			gts_behavior.camera.global_position).normalized()
	if collision_data_id == 0:
		# Actual Z surface.
		h_direction = (gts_behavior.x_axis.global_position - gizmo.global_position).normalized()
		v_direction = (gts_behavior.y_axis.global_position - gizmo.global_position).normalized()
	elif collision_data_id == 1:
		# Actual X surface.
		h_direction = (gts_behavior.z_axis.global_position - gizmo.global_position).normalized()
		v_direction = (gts_behavior.y_axis.global_position - gizmo.global_position).normalized()
	else:
		# Actual Y surface.
		h_direction = (gts_behavior.x_axis.global_position - gizmo.global_position).normalized()
		v_direction = (gts_behavior.z_axis.global_position - gizmo.global_position).normalized()
	
	var h_dot: float = camera_to_gizmo_direction.dot(h_direction)
	var v_dot: float = camera_to_gizmo_direction.dot(v_direction)
	if h_dot > .0 && v_dot > .0:
		z_index = gizmo.z_index_root - Z_INDEX_OFFSET
	elif h_dot <= .0 && v_dot <= .0:
		z_index = gizmo.z_index_root + Z_INDEX_OFFSET
	else:
		z_index = gts_behavior.z_index


func draw_surface(in_id: int) -> void:
	determine_z_index()
	
	var coll: Array[Variant] = gts_behavior.collision_data[in_id]
	var c_surface_points: PackedVector2Array = gts_behavior.surface_points[coll[0]]
	var vertex_color: Color = coll[3]
	
	var color_alpha_delta: float = abs(abs(gts_behavior.COLOR_ALPHA_THRESHOLD.x * \
			gts_behavior.gizmo.viewport_size_factor) - abs(gts_behavior.COLOR_ALPHA_THRESHOLD.y * \
					gts_behavior.gizmo.viewport_size_factor))
	var surface_position: Vector2 = c_surface_points[0]
	var surface_distance_to_gizmo_center: float = surface_position.length()
	
	var color_alpha_factor: float = clamp((surface_distance_to_gizmo_center - \
			gts_behavior.COLOR_ALPHA_THRESHOLD.x * gts_behavior.gizmo.viewport_size_factor) / \
			color_alpha_delta, .0, 1.0)
	
	if in_id == gts_behavior.closest_collision_data && Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		vertex_color = coll[4]
	
	vertex_color.a *= color_alpha_factor
	
	var polygon_uvs: PackedVector2Array = [Vector2.ZERO, Vector2(.0, 1.0), Vector2.ONE, Vector2(1.0, .0)]
	if !Geometry2D.triangulate_polygon(c_surface_points).is_empty():
		draw_colored_polygon(c_surface_points, vertex_color, polygon_uvs, null)


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	if gts_behavior.collision_data.size() > 0:
		draw_surface(surface_collision_id)
