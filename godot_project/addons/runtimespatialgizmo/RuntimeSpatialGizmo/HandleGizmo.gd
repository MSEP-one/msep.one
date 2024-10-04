extends Node3D

const EPSILON: float = .001
const VIEWPORT_SIZE_REFERENCE: float = 2000.0
const OUTSIDE_OF_FRUSTUM_OFFSET: float = 2.0
const CAMERA_TO_SELECTED_NODE_THRESHOLD_FIX_STEP: float = .00001
const CAMERA_TO_SELECTED_NODE_DOT_THRESHOLD: float = 1.0 - .0000001
const COLOR_ALPHA_THRESHOLD: Vector2 = Vector2(30.0, 30.0)
const Z_IN_FRONT_OFFSET: int = 20
const ORTHOGRAPHIC_SCALE: float = 0.165 # Determined experimentally

@export var z_index_root: int = 128

var active_axis_is_pointing_away := false
var viewport_size_factor : float = 1.0

@onready var draw_in_front_z_index: int = z_index_root + Z_IN_FRONT_OFFSET

## Force flipping, so that, when node is rotated it is flipped back.
## If we want to behave as Godot editor does.
@export var rotate_back_on_negative_scale: bool = false
## Should the translation axis be guarded against sudden jumps.
## If this is disabled gizmo will behave like Godot editor's gizmo.
@export var limit_axis_range: bool = true
## Enable this if you want it be possible to center drag the gizmo only
## if the center circle is clicked, otherwise center drag will behave like
## in Godot editor gizmo.
@export var limit_center_radius: bool = false
## Godot editor's global scale behavior is performing mathematically correct, but seemingly
## practically useless operation, plus it's buggy, enable this setting to have that weird
## behavior, but without bugs.
@export var enable_global_squash: bool = false

@export var inactive_x_color : Color
@export var inactive_y_color : Color
@export var inactive_z_color : Color
@export var inactive_center_color : Color

@export var active_x_color : Color
@export var active_y_color : Color
@export var active_z_color : Color
@export var active_center_color : Color

@export var reference_arc_color : Color

@export var middle_circle_color : Color

@export var gizmo_size_ratio : float = 1.0

@onready var scale_axes: Node = %SABehavior
@onready var scale_axes_wrapper: Node = scale_axes.get_parent()
@onready var global_scale_axes: Node = %GSABehavior
@onready var ortho_scale_axes: Node = %OSABehavior
@onready var global_scale_axes_wrapper: Node = global_scale_axes.get_parent()
@onready var ortho_scale_axes_wrapper: Node = ortho_scale_axes.get_parent()
@onready var translation_axes: Node = %TABehavior
@onready var translation_axes_wrapper: Node = translation_axes.get_parent()
@onready var global_translation_axes: Node = %GTABehavior
@onready var ortho_translation_axes: Node = %OTABehavior
@onready var global_translation_axes_wrapper: Node = global_translation_axes.get_parent()
@onready var ortho_translation_axes_wrapper: Node = ortho_translation_axes.get_parent()
@onready var rotation_arcs: Node = %RABehavior
@onready var rotation_arcs_wrapper: Node = rotation_arcs.get_parent()
@onready var global_rotation_arcs: Node = %GRABehavior
@onready var ortho_rotation_arcs: Node = %ORABehavior
@onready var global_rotation_arcs_wrapper: Node = global_rotation_arcs.get_parent()
@onready var ortho_rotation_arcs_wrapper: Node = ortho_rotation_arcs.get_parent()
@onready var translation_surfaces: Node = %TSBehavior
@onready var translation_surfaces_wrapper: Node = translation_surfaces.get_parent()
@onready var global_translation_surfaces: Node = %GTSBehavior
@onready var ortho_translation_surfaces: Node = %OTSBehavior
@onready var global_translation_surfaces_wrapper: Node = global_translation_surfaces.get_parent()
@onready var ortho_translation_surfaces_wrapper: Node = ortho_translation_surfaces.get_parent()
@onready var center_drag: Node = %CDBehavior
@onready var center_drag_wrapper: Node = center_drag.get_parent()

@onready var x_axis: Node3D = %X
@onready var y_axis: Node3D = %Y
@onready var z_axis: Node3D = %Z
@onready var behavior_handlers : Array[Node] = [
	%CDBehavior,
	%SABehavior,
	%GSABehavior,
	%TABehavior,
	%GTABehavior,
	%RABehavior,
	%GRABehavior,
	%TSBehavior,
	%GTSBehavior,
	%MCBehavior,
	%OSABehavior,
	%OTABehavior,
	%ORABehavior,
	#%OTSBehavior, # Uncomment this to enable old ortho translation surfaces working.
	%OZHBehavior,
	%OZSBehavior
]


func _process(_in_delta : float) -> void:
	viewport_size_factor = max(get_viewport().size.length() / VIEWPORT_SIZE_REFERENCE, EPSILON)
	draw_elements.call_deferred()


func determine_single_axis_in_cutout_perifery(in_axis_position2D: Vector2, \
		in_gizmo_position2D: Vector2, in_camera_to_gizmo_direction: Vector3, \
		in_gizmo_to_node_direction: Vector3) -> bool:
	var threshold: float = pow(COLOR_ALPHA_THRESHOLD.x * 2.0, 2)
	return in_axis_position2D.distance_squared_to(in_gizmo_position2D) < threshold && \
			in_camera_to_gizmo_direction.dot(in_gizmo_to_node_direction) < .0


func determine_if_in_cutout_perifery() -> bool:
	var camera: Node3D = GizmoRoot.camera_3D
	var gizmo_position2D: Vector2 = camera.unproject_position(global_position)
	var camera_to_gizmo_direction: Vector3 = (global_position - camera.global_position).normalized()
	var axis_position2D: Vector2 = camera.unproject_position(x_axis.global_position)
	var gizmo_to_node_direction: Vector3 = (x_axis.global_position - global_position).normalized()
	if (determine_single_axis_in_cutout_perifery(axis_position2D, gizmo_position2D, \
			camera_to_gizmo_direction, gizmo_to_node_direction)):
		return true
	axis_position2D = camera.unproject_position(y_axis.global_position)
	gizmo_to_node_direction = (y_axis.global_position - global_position).normalized()
	if (determine_single_axis_in_cutout_perifery(axis_position2D, gizmo_position2D, \
			camera_to_gizmo_direction, gizmo_to_node_direction)):
		return true
	axis_position2D = camera.unproject_position(z_axis.global_position)
	gizmo_to_node_direction = (z_axis.global_position - global_position).normalized()
	if (determine_single_axis_in_cutout_perifery(axis_position2D, gizmo_position2D, \
			camera_to_gizmo_direction, gizmo_to_node_direction)):
		return true
	
	return false


func draw_elements() -> void:
	if GizmoRoot.gizmo_state == GizmoRoot.GizmoState.DISABLED:
		return
	
	if !is_instance_valid(GizmoRoot.selected_node):
		return
	var camera := GizmoRoot.camera_3D
	if !is_instance_valid(camera):
		return
	var camera_frustum := camera.get_frustum()
	var dont_draw := false
	var selected_node_position := GizmoRoot.selected_node.global_position
	var camera_position := camera.global_position
	var distance_to_selected_node := camera_position.distance_to(selected_node_position)
	var direction_to_selected_node := (selected_node_position - camera_position).normalized()
	var camera_forward := camera.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD
	
	# If camera is looking exactly at selected node (the selected node is exactly at the center of
	# the screen), then the gizmo will get stuck in the middle of the screen, this prevents it from
	# happening.
	if direction_to_selected_node.dot(camera_forward) > CAMERA_TO_SELECTED_NODE_DOT_THRESHOLD:
		camera.global_position += Vector3.ONE * distance_to_selected_node * \
		CAMERA_TO_SELECTED_NODE_THRESHOLD_FIX_STEP
	
	# Make sure to avoid the one frame desync (and flip around of gizmo) between gizmo element
	# drawing and GizmoRoot.
	if direction_to_selected_node.dot(camera_forward) < .0:
		dont_draw = true
	else:
		for plane in camera.get_frustum():
			# It's better to check global_position of gizmo than selected node.  This way the gizmo
			# won't disappear suddenly on near plane, but instead will move to the side just like in
			# Godot editor and one of the side planes will take care of hiding. This can be done as
			# the camera transformation is adjusted if it looks almost exactly at the selected node.

			if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
				dont_draw = plane.distance_to(global_position) > OUTSIDE_OF_FRUSTUM_OFFSET
			else:
				dont_draw = plane.distance_to(selected_node_position) > OUTSIDE_OF_FRUSTUM_OFFSET
			if dont_draw:
				break
	for handler in behavior_handlers:
		if handler != null && handler.is_inside_tree():
			if dont_draw:
				handler.visible = false
			else:
				handler.visible = true
				handler.update_drawing()


func calculate_relative_scale() -> Vector2:
	var ratio = Vector2.ONE
	
	if GizmoRoot.active_viewport is SubViewport and GizmoRoot.active_viewport.get_parent() is SubViewportContainer:
		var viewport_size: Vector2 = Vector2(GizmoRoot.active_viewport.size)
		var viewport_container_size: Vector2 = GizmoRoot.active_viewport.get_parent().get_global_rect().size
		if viewport_size.length_squared() != .0 && viewport_container_size.length_squared() != .0:
			ratio = viewport_container_size / viewport_size
	
	return ratio


func calculate_relative_offset() -> Vector2:
	var gizmo_position_2d_in_window: Vector2 = Vector2.ZERO
	
	if GizmoRoot.active_viewport is SubViewport and GizmoRoot.active_viewport.get_parent() is SubViewportContainer:
		gizmo_position_2d_in_window = GizmoRoot.active_viewport.get_parent().get_global_rect().position
	
	return gizmo_position_2d_in_window


func process_gizmo_input(event: InputEvent):
	for behavior in behavior_handlers:
		if behavior.is_inside_tree():
			behavior.gizmo_input(event)


func _ready() -> void:
	# Prepare the initial look of the gizmo, turn some elements off and some on.
	
	GizmoRoot.remove_global_translation_axes()
	GizmoRoot.remove_global_translation_surfaces()
	GizmoRoot.remove_global_scale_axes()
	GizmoRoot.remove_global_rotation_arcs()
	
	if is_instance_valid(scale_axes):
		scale_axes_wrapper.remove_child(scale_axes)
	if is_instance_valid(ortho_scale_axes):
		ortho_scale_axes_wrapper.remove_child(ortho_scale_axes)
	if translation_axes_wrapper.get_child_count() == 0:
		translation_axes_wrapper.add_child(translation_axes)
	GizmoRoot.axes_mode = GizmoRoot.AxesMode.TRANSLATION

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Manually free handlers that may not be in the tree
		#+This avoids leaks when exit the application
		for handler in behavior_handlers:
			if is_instance_valid(handler):
				handler.queue_free()
