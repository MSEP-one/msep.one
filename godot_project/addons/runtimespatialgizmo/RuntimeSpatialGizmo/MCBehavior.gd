extends Node2D

const COLOR_ALPHA_THRESHOLD: Vector2 = Vector2(30.0, 50.0)
const IN_FRONT_OF_GIZMO_Z_INDEX: int = 5
# It's nice to have it thicker to hid the arc cut off.
# With the ortho gizmo, we can make it thinner, because the arc segments don't pop in and out
# anymore
const LINE_THICKNESS: float = 3.0
const ARC_SEGMENT_COUNT: int = 64

@onready var gizmo: Node3D = owner
var camera: Camera3D:
	get:
		return GizmoRoot.camera_3D
var selected_node: Node3D:
	get:
		return GizmoRoot.selected_node


func update_drawing() -> void:
	global_position = camera.unproject_position(selected_node.global_position)
	queue_redraw()


func gizmo_input(event: InputEvent) -> void:
	pass


func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		return
	
	if gizmo.determine_if_in_cutout_perifery():
		z_index = gizmo.draw_in_front_z_index + IN_FRONT_OF_GIZMO_Z_INDEX
	else:
		z_index = gizmo.z_index_root + IN_FRONT_OF_GIZMO_Z_INDEX
		
	
	var camera_forward: Vector3 = camera.global_transform.basis.get_rotation_quaternion() * \
			Vector3.FORWARD
	var radius: float = COLOR_ALPHA_THRESHOLD.x * gizmo.viewport_size_factor
	draw_arc(Vector2.ZERO, radius, .0, 2.0 * PI, ARC_SEGMENT_COUNT, gizmo.middle_circle_color, LINE_THICKNESS, true)
