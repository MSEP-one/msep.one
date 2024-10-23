class_name OrientationWidgetUI
extends Control

const MAX_RESOLUTION: float = 16384.0
const WIDGET_SIZE: float = 8.0
const AXIS_LENGTH: float = .5
const DEPTH_DISTANCE_ID = 0
const DEPTH_2DPOSITION_ID = 1
const DEPTH_COLOR_ID = 2
const DEPTH_CHAR_ID = 3
const DEPTH_INVERSION_ID = 4
const VIEWPORT_SIZE_RELATIVE_AXIS_GOAL_OFFSET = 1250.0
const FULL_CIRCLE = 2.0 * PI
const DISTANCE_RATIO = 1.5
const EPSILON = .001
const DIM_PADDING = .35
const CIRCLE_RADIUS = 10.0
const LINE_THICKNESS = 1.0
const RIGHT_PANEL_ADJUSTMENT: float = 15.0
# This isn't adjusted automatically with widget size, you can choose the size.
const WIDGET_RADIUS = 65.0
const INVERTED_AXIS_COLOR_DIM_COEFFICIENT = .75
@export var manual_offset := Vector2(75.0, -175.0)
@export var x_axis_color := Color(0.930342, 0.193663, 0.31138)
@export var y_axis_color := Color(0.550397, 0.815403, 0.179389)
@export var z_axis_color := Color(0.165993, 0.497978, 0.851155)
@export var active_axis_color := Color(1.0, 1.0, 1.0, 1.0)
@export var font_color := Color(.1, .1, .1, 1.0)
var container_offset := Vector2.ZERO
var widget_circle_color := Color(.0, .0, .0, .0)
var font_offset := Vector2(-5.0, 6.0)
var axis_depths : Array = []
var widget_alpha := 1.0
var mouse_position := Vector2.ZERO
var mouse_drag_in_widget_is_active := false
var workspace_tools_container : Control = null
var colliding_axis_index : int = -1
var snap_rotation: Vector3 = Vector3.ZERO
var snap_progress: float = .0
var snap_speed: float = 1.0
var snap_is_active: bool = false
var orbit_radius: float = .0
var orbit_center: Vector3 = Vector3.ZERO
var creation_distance: float = 7.4
var _initial_scale_factor: Vector2 = Vector2.ONE
var _resolution_factor: float = .0
@onready var default_font : Font = get_theme_default_font()
@onready var orientation_widget : Node3D = owner
@onready var _editor_viewport: WorkspaceEditorViewport = _find_editor_viewport()
@onready var _camera : Camera3D = _find_editor_viewport_camera_3d()


func _find_editor_viewport() -> WorkspaceEditorViewport:
	var ancestor: Node = get_parent()
	while not ancestor is SubViewportContainer:
		ancestor = ancestor.get_parent()
	return ancestor.get_child(0) as WorkspaceEditorViewport


func _find_editor_viewport_camera_3d() -> Camera3D:
	assert(_editor_viewport, "Invalid project hierarchy, could not find viewport!")
	return _editor_viewport.get_camera_3d()


func set_workspace_tools_reference(in_workspace_tools_container: Control) -> void:
	workspace_tools_container = in_workspace_tools_container


func _draw_single_axis(in_index : int) -> void:
	var axis_color : Color = axis_depths[in_index][DEPTH_COLOR_ID]
	
	if _detect_colliding_index() == in_index:
		axis_color = active_axis_color
	
	if axis_depths[in_index][DEPTH_INVERSION_ID]:
		var dim_coefficient := INVERTED_AXIS_COLOR_DIM_COEFFICIENT
		var circle_color := Color(axis_color.r * dim_coefficient, axis_color.g * dim_coefficient,\
				axis_color.b * dim_coefficient, axis_color.a)
		draw_circle(axis_depths[in_index][DEPTH_2DPOSITION_ID], CIRCLE_RADIUS, circle_color)
		var arc_color := Color(axis_color.r, axis_color.g, axis_color.b, axis_color.a)
		draw_arc(axis_depths[in_index][DEPTH_2DPOSITION_ID], CIRCLE_RADIUS, .0, FULL_CIRCLE, 16, \
				arc_color, 2.0, false)
		
		var axis_char := str("-", axis_depths[in_index][DEPTH_CHAR_ID])
		draw_string(default_font, axis_depths[in_index][DEPTH_2DPOSITION_ID] + font_offset, \
				axis_char, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,\
				font_color)
	else:
		var circle_color := Color(axis_color.r, axis_color.g, axis_color.b, axis_color.a)
		draw_line(Vector2.ZERO, axis_depths[in_index][DEPTH_2DPOSITION_ID], circle_color, \
				LINE_THICKNESS, true)
		draw_circle(axis_depths[in_index][DEPTH_2DPOSITION_ID], CIRCLE_RADIUS, circle_color)
		draw_string(default_font, axis_depths[in_index][DEPTH_2DPOSITION_ID] + font_offset, \
				axis_depths[in_index][DEPTH_CHAR_ID], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, font_color)


func _detect_colliding_index() -> int:
	colliding_axis_index = -1
	for index in range(0, axis_depths.size()):
		if (axis_depths[index][1] * _resolution_factor).distance_to(mouse_position \
				- position) < CIRCLE_RADIUS * _resolution_factor:
			colliding_axis_index = index
			if !axis_depths[index][5]:
				break
	
	return colliding_axis_index


func _has_point(_point: Vector2) -> bool:
	return _detect_colliding_index() != -1


func _gui_input(event: InputEvent) -> void:
	# HACK: This widget has to capture mouse to prevent events reaching the gizmo
	# however this also prevents events reaching Camera Input Handler
	# because of that we redirect this mouse inputs directly into the viewport
	if event is InputEventMouseButton:
		_editor_viewport.set_input_forwarding_enabled(true)
		_editor_viewport.forward_viewport_input(event)


func _draw() -> void:
	draw_circle(Vector2.ZERO, WIDGET_RADIUS, widget_circle_color)
	for index in range(0, axis_depths.size()):
		_draw_single_axis(index)


func _ready() -> void:
	_editor_viewport.size_changed.connect(_on_size_changed)
	_initial_scale_factor = scale


func _on_size_changed() -> void:
	_process(get_process_delta_time(), true)


func _process(_in_delta: float, in_force: bool = false, in_finish: bool = false) -> void:
	if !in_force && (InitialInfoScreen.visible || BusyIndicator.visible):
		return
	
	_resolution_factor = _calculate_resolution_factor()
	
	mouse_position = _editor_viewport.get_mouse_position()
	
	var widget_position_unprojected : Vector2 = \
	_camera.unproject_position(orientation_widget.global_position)
	var viewport_size : Vector2 = get_viewport().get_size()
	container_offset = workspace_tools_container.global_position\
			- viewport_size * .5 + Vector2(.0, viewport_size.y) + manual_offset
	global_position = widget_position_unprojected + container_offset
	# The UI is sized relative to y so, I use y.
	var axis_length: float = AXIS_LENGTH
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		axis_length *= 0.042 * _camera.size # Determined experimentally
	var x_goal_position := orientation_widget.global_position + Vector3.RIGHT * axis_length / \
	(Vector2(get_viewport().size).y / VIEWPORT_SIZE_RELATIVE_AXIS_GOAL_OFFSET)
	var y_goal_position := orientation_widget.global_position + Vector3.UP * axis_length / \
	(Vector2(get_viewport().size).y / VIEWPORT_SIZE_RELATIVE_AXIS_GOAL_OFFSET)
	var z_goal_position := orientation_widget.global_position - Vector3.FORWARD * axis_length / \
	(Vector2(get_viewport().size).y / VIEWPORT_SIZE_RELATIVE_AXIS_GOAL_OFFSET)
	var x_goal_position_unprojected := _camera.unproject_position(x_goal_position)
	var y_goal_position_unprojected := _camera.unproject_position(y_goal_position)
	var z_goal_position_unprojected := _camera.unproject_position(z_goal_position)
	
	var x_axis_params : Array = calculate_axis_params(x_goal_position, x_goal_position_unprojected,\
			x_axis_color, "X", false)
	var y_axis_params : Array = calculate_axis_params(y_goal_position, y_goal_position_unprojected,\
			y_axis_color, "Y", false)
	var z_axis_params : Array = calculate_axis_params(z_goal_position, z_goal_position_unprojected,\
			z_axis_color, "Z", false)
	
	var direction_to_x_goal_position := x_goal_position - orientation_widget.global_position
	var unprojected_direction_to_center_from_x_goal_position := \
	_camera.unproject_position(orientation_widget.global_position\
			- direction_to_x_goal_position)
	var direction_to_y_goal_position := y_goal_position - orientation_widget.global_position
	var unprojected_direction_to_center_from_y_goal_position := \
	_camera.unproject_position(orientation_widget.global_position\
			- direction_to_y_goal_position)
	var direction_to_z_goal_position := z_goal_position - orientation_widget.global_position
	var unprojected_direction_to_center_from_z_goal_position := \
	_camera.unproject_position(orientation_widget.global_position\
			- direction_to_z_goal_position)
	
	var inverted_x_axis_params : Array = calculate_axis_params(orientation_widget.global_position\
			- direction_to_x_goal_position, unprojected_direction_to_center_from_x_goal_position,\
			x_axis_color, "X", true)
	var inverted_y_axis_params : Array = calculate_axis_params(orientation_widget.global_position\
			- direction_to_y_goal_position, unprojected_direction_to_center_from_y_goal_position,\
			y_axis_color, "Y", true)
	var inverted_z_axis_params : Array = calculate_axis_params(orientation_widget.global_position\
			- direction_to_z_goal_position, unprojected_direction_to_center_from_z_goal_position,\
			z_axis_color, "Z", true)
	
	axis_depths = [x_axis_params, y_axis_params, z_axis_params, inverted_x_axis_params,\
			inverted_y_axis_params, inverted_z_axis_params]
	var sort_by_axis_depth: Callable = func(
			in_first_to_compare_axis_depth: Array,
			in_second_to_compare_axis_depth: Array) -> bool:
		return in_first_to_compare_axis_depth[0] > in_second_to_compare_axis_depth[0]
	axis_depths.sort_custom(sort_by_axis_depth)
	queue_redraw()
	modulate.a = widget_alpha
	
	if snap_is_active:
		if snap_progress < 1.0 - EPSILON || in_finish:
			snap_progress = min(snap_progress + _in_delta * snap_speed, 1.0)
			_camera.global_rotation = _camera.global_rotation.lerp(snap_rotation, \
					snap_progress)
			_camera.global_position = orbit_center - \
			_camera.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD * \
					orbit_radius + _calculate_screen_offset(orbit_radius)
		else:
			snap_is_active = false
			snap_progress = 1.0
			
	_adjust_relative_to_resolution()


func finish_snap() -> void:
	snap_progress = 1.0
	_process(.02, true, true)


func _calculate_resolution_factor() -> float:
	var current_screen_size: Vector2 = DisplayServer.screen_get_size()
	return current_screen_size.x / MAX_RESOLUTION * WIDGET_SIZE


func _adjust_relative_to_resolution() -> void:
	var global_widget_scale: float = MolecularEditorContext.msep_editor_settings.ui_widget_scale
	scale = Vector2(_resolution_factor, _resolution_factor) * _initial_scale_factor * global_widget_scale
	
	position.x += _resolution_factor * global_widget_scale * manual_offset.x - manual_offset.x
	position.y += _resolution_factor * global_widget_scale * manual_offset.y - manual_offset.y


func _calculate_screen_offset(in_orbit_radius: float) -> Vector3:
	var center_of_viewport3D: Vector3 = _camera.project_position(get_viewport().size * .5,\
			in_orbit_radius)
	var rect_center: Vector2 = workspace_tools_container.get_global_rect().get_center()
	var center_of_rect3D: Vector3 = _camera.project_position(Vector2(rect_center.x + \
			RIGHT_PANEL_ADJUSTMENT, rect_center.y), in_orbit_radius)
	return center_of_viewport3D - center_of_rect3D


func _calculate_snap(in_rotation : Vector3) -> void:
	if !MolecularEditorContext.get_current_workspace_context().has_visible_objects():
		return
	
	snap_progress = .0
	
	if GizmoRoot.selected_node:
		orbit_radius = \
		_camera.global_position.distance_to(GizmoRoot.selected_node.global_position)
		orbit_center = GizmoRoot.selected_node.global_position
	elif orbit_radius < EPSILON:
		orbit_radius = creation_distance
	
	snap_rotation = in_rotation
	
	snap_is_active = true


func _determine_axis_overlap(in_axis_char: String, in_inverted: bool, in_position: Vector2) -> bool:
	for i in range(0, axis_depths.size()):
		if axis_depths[i][3] == in_axis_char && axis_depths[i][4] != in_inverted && \
		axis_depths[i][1].distance_to(in_position) < .1:
			return true
	return false


func _calculate_axis_snap(in_axis_char: String, in_non_inverted_rotation: Vector3, \
		in_inverted_rotation: Vector3) -> void:
	if axis_depths[colliding_axis_index][4]:
		if _determine_axis_overlap(in_axis_char, true, axis_depths[colliding_axis_index][1]):
			_calculate_snap(in_non_inverted_rotation)
		else:
			_calculate_snap(in_inverted_rotation)
	else:
		if _determine_axis_overlap(in_axis_char, false, axis_depths[colliding_axis_index][1]):
			_calculate_snap(in_inverted_rotation)
		else:
			_calculate_snap(in_non_inverted_rotation)


func manage_mouse_click(in_input_event: InputEvent) -> void:
	if in_input_event.button_index == MOUSE_BUTTON_LEFT:
		match axis_depths[colliding_axis_index][3]:
			"X":
				_calculate_axis_snap("X", Vector3(.0, PI * .5 + EPSILON, .0), \
						Vector3(.0, PI * -.5 - EPSILON, .0))
			"Y":
				_calculate_axis_snap("Y", Vector3(PI * -.5 + EPSILON, .0, .0), \
						Vector3(PI * .5 - EPSILON, .0, .0))
			"Z":
				_calculate_axis_snap("Z", Vector3(.0, EPSILON, .0), \
						Vector3(.0, PI - EPSILON, .0))


func calculate_axis_params(in_direction_to_center_from_axis_goal_position : Vector3,\
		in_unprojected_direction_to_center_from_axis_goal_position : Vector2, in_color : Color, \
		in_axis_char : String, in_inverted : bool) -> Array:
	
	var distance_from_camera_to_axis := \
	_camera.global_position.distance_to(in_direction_to_center_from_axis_goal_position)
	distance_from_camera_to_axis -= (orientation_widget.DISTANCE_FROM_CAMERA - DISTANCE_RATIO)
	var camera_forward: Vector3 = _camera.global_transform.basis.get_rotation_quaternion() * \
			Vector3.FORWARD
	var axis_dim_factor: float = .0
	axis_dim_factor = camera_forward.dot(-(in_direction_to_center_from_axis_goal_position \
			- orientation_widget.global_position).normalized())
	axis_dim_factor = clamp(axis_dim_factor + 1, .75, 1.0)
	
	var new_axis_color := Color(in_color.r * axis_dim_factor, in_color.g * axis_dim_factor,\
			in_color.b * axis_dim_factor, 1.0)
	return [distance_from_camera_to_axis, in_unprojected_direction_to_center_from_axis_goal_position\
			- global_position + container_offset, new_axis_color, in_axis_char, in_inverted, \
			true if axis_dim_factor < 1.0 - EPSILON else false]
