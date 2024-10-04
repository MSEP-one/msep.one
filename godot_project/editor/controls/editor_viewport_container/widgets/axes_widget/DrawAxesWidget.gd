class_name AxesWidget
extends Control

# The size can be set in axes_widget.gd, by setting distance from camera.

enum MoveDirection {NONE, X, Y, Z}
const MAX_RESOLUTION: float = 16384.0
const WIDGET_SIZE: float = 8.0
const ORBIT_SMOOTHING_FACTOR: float = .1
# Adjust camera rotation and movement handles here.
const ORBIT_TO_CENTER_SPEED: float = .015
const ORBIT_ROTATION_START_SENSITIVITY: float = .001
const ORBIT_ROTATION_SENSITIVITY_SPEEDUP_TIME: float = 4.0
const ORBIT_ROTATION_SENSITIVITY: float = .01
const CAMERA_SLOW_DOWN_COEFFICIENT: float = 1.0
const CAMERA_SPEED_UP_COEFFICIENT: float = 1.0
# End Adjust Camera rotation and movement handles here.
const EPSILON: float = .001
const RIGHT_PANEL_ADJUSTMENT: float = 15.0
# This isn't adjusted automatically with widget size, you can choose the size.
const HIGHLIGHT_SPEED: float = 10.0
const DEFAULT_WIDGET_SIZE: Vector2 = Vector2(90, 90)

var orbit_rotation_current_sensitivity: float = ORBIT_ROTATION_START_SENSITIVITY
var mouse_position := Vector2.ZERO
var mouse_drag_in_widget_is_active := false
var mouse_delta := Vector2.ZERO
var mouse_is_in_drag_radius := false
var working_area_rect_control : Control = null
var mouse_delta_goal := Vector2.ZERO
var orbit_screen_vector := Vector3.ZERO
var is_orbiting := false
var orbit_old_camera_position := Vector3.ZERO
var orbit_radius := .0
var workspace_has_transformable_selection := false
var no_selection_orbit_active: bool = false
var no_selection_reference_position: Vector3 = Vector3.ZERO
var x_lerped_step: float = .0
var y_lerped_step: float = .0
var restore_to_widget_mouse_position: Vector2 = Vector2.ZERO
var current_up: Vector3 = Vector3.UP
var old_selection_position: Vector3 = Vector3.ZERO
var orbiting_allowed: bool = false

@onready var orbit_handle: TextureRect = %OrbitHandle
@onready var orbit_handle_highlight: TextureRect = %Highlighted
@onready var orbit_handle_pressed: TextureRect = %Pressed
@onready var axes_widget_3d: AxesWidget3D = $AxesWidget3D
@onready var move_direction := MoveDirection.NONE
@onready var _editor_viewport: WorkspaceEditorViewport = _find_editor_viewport()
@onready var _camera : Camera3D = _find_editor_viewport_camera_3d()


func _ready() -> void:
	assert(_editor_viewport, "Invalid project hierarchy, could not find viewport!")
	assert(_camera, "Could not find editor camera")
	_camera.owner.axes_widget = self
	orbit_handle_pressed.visible = false
	_editor_viewport.size_changed.connect(_adjust_relative_to_resolution)
	MolecularEditorContext.msep_editor_settings.changed.connect(_adjust_relative_to_resolution)
	_adjust_relative_to_resolution()


func _find_editor_viewport() -> WorkspaceEditorViewport:
	var ancestor: Node = get_parent()
	while not ancestor is SubViewportContainer:
		ancestor = ancestor.get_parent()
	return ancestor.get_child(0) as WorkspaceEditorViewport


func _find_editor_viewport_camera_3d() -> Camera3D:
	assert(_editor_viewport, "Invalid project hierarchy, could not find viewport!")
	return _editor_viewport.get_camera_3d()


func _adjust_relative_to_resolution() -> void:
	var current_screen_size: Vector2 = DisplayServer.screen_get_size()
	var x_factor: float = current_screen_size.x / MAX_RESOLUTION * WIDGET_SIZE
	var global_widget_scale: float = MolecularEditorContext.msep_editor_settings.ui_widget_scale
	custom_minimum_size = DEFAULT_WIDGET_SIZE * Vector2(x_factor, x_factor) * global_widget_scale


func set_working_area_rect_control(in_working_area_rect_control: Control) -> void:
	working_area_rect_control = in_working_area_rect_control


func manage_look(in_mouse_distance_from_center_offset: float, in_delta: float) -> void:
	if !BusyIndicator.visible:
		orbit_handle_pressed.visible = false
		orbit_handle_highlight.visible = true
		if !mouse_drag_in_widget_is_active:
			if !mouse_is_in_drag_radius:
				dim_non_active_elements(-1, in_delta * HIGHLIGHT_SPEED)
			else:
				if in_mouse_distance_from_center_offset < (size.x * 0.5):
					orbit_handle.self_modulate.a = lerp(orbit_handle.self_modulate.a, .0, \
							in_delta * HIGHLIGHT_SPEED)
					orbit_handle_highlight.self_modulate.a = \
					lerp(orbit_handle_highlight.self_modulate.a, 1.0, in_delta * HIGHLIGHT_SPEED)
					dim_non_active_elements(0, in_delta * HIGHLIGHT_SPEED)
		elif mouse_is_in_drag_radius:
			orbit_handle_highlight.visible = false
			orbit_handle_pressed.visible = true


func dim_non_active_elements(in_active_index: int, in_step: float) -> void:
	var handles: Array[Control] = [
	orbit_handle
	]
	var highlight_handles: Array[Control] = [
	orbit_handle_highlight
	]
	
	if in_active_index > -1:
		handles.remove_at(in_active_index)
		highlight_handles.remove_at(in_active_index)
	
	for handle in handles:
		handle.self_modulate.a = lerp(handle.self_modulate.a, 1.0, in_step)
	for handle in highlight_handles:
		handle.self_modulate.a = lerp(handle.self_modulate.a, .0, in_step)


func manage_continuous_input(in_delta: float) -> void:
	if AboutMsepOne.visible:
		mouse_is_in_drag_radius = false
		return
	
	var mouse_distance_from_center_offset: float = \
	mouse_position.distance_to(global_position + size * scale * .5 * scale.x)
	
	if !_editor_viewport.get_ring_menu().is_active():
		manage_look(mouse_distance_from_center_offset, in_delta)
	
	var mouse_in_drag_radius_distance: float = scale.x * size.x * .5 * scale.x
	if Engine.get_main_loop().root.gui_disable_input == true:
		# Sometimes GUI input is disabled while async jobs are running
		mouse_is_in_drag_radius = false
	elif mouse_distance_from_center_offset < mouse_in_drag_radius_distance:
		mouse_is_in_drag_radius = true
		# This is nice because we can then warp mouse to the center and it won't stay there after
		# transformation is finished.
		# But perhaps more importantly this works around Wayland issue, where mouse position after
		# capturing or confining mouse doesn't correspond with it's visual representation until
		# after mouse isn't moved at least slightly.
		restore_to_widget_mouse_position = mouse_position - global_position
	elif !mouse_drag_in_widget_is_active:
		mouse_is_in_drag_radius = false
	
	drag_rotate_camera()
	
	mouse_delta = mouse_delta.lerp(mouse_delta_goal, axes_widget_3d.clamped_delta_time * \
			CAMERA_SPEED_UP_COEFFICIENT)
	mouse_delta_goal = mouse_delta_goal.slerp(Vector2.ZERO, axes_widget_3d.clamped_delta_time * \
			CAMERA_SLOW_DOWN_COEFFICIENT)


func restore_mouse_position() -> void:
	await get_tree().process_frame
	warp_mouse(restore_to_widget_mouse_position)


func _has_point(_point: Vector2) -> bool:
	return mouse_is_in_drag_radius

func _gui_input(event: InputEvent) -> void:
	# HACK: This widget has to capture mouse to prevent events reaching the gizmo
	# however this also prevents events reaching Camera Input Handler
	# because of that we redirect this mouse inputs directly into the viewport
	if event is InputEventMouse:
		_editor_viewport.set_input_forwarding_enabled(true)
		_editor_viewport.forward_viewport_input(event)

func adjust_orbit(in_step : float) -> void:
	orbit_radius += in_step
	orbit_radius = max(orbit_radius, EPSILON)
	if in_step < .0:
		orbit_screen_vector = orbit_screen_vector.slerp(Vector3.ZERO, ORBIT_TO_CENTER_SPEED \
				* abs(in_step))


func rotate_to_orbit(in_orbit_delta : Vector2) -> void:
	if !orbiting_allowed:
		return
	
	if !is_orbiting:
		orbit_old_camera_position = _camera.global_position
		no_selection_reference_position = _camera.owner.no_selection_reference_position
		orbit_radius = get_orbit_pivot_position().distance_to(_camera.global_position)
		current_up = _camera.global_transform.basis.get_rotation_quaternion() * Vector3.UP
	
	var camera_quat : Quaternion = \
	_camera.global_transform.basis.get_rotation_quaternion()
	
	if !is_orbiting:
		in_orbit_delta = Vector2.ZERO
		
		orbit_rotation_current_sensitivity = ORBIT_ROTATION_START_SENSITIVITY
	else:
		orbit_rotation_current_sensitivity = lerp(orbit_rotation_current_sensitivity, \
				ORBIT_ROTATION_SENSITIVITY, axes_widget_3d.clamped_delta_time / \
				ORBIT_ROTATION_SENSITIVITY_SPEEDUP_TIME)
	
	# On a very large camera/orbit distance, there might not be enough information from the mouse
	# movement to produce smooth stepping, this makes orbiting smooth regardless even if the steps
	# are too far apart from each other (It's obviously only needed for mouse input).
	if axes_widget_3d.rotation_must_follow_mouse && is_orbiting:
		x_lerped_step = lerp(x_lerped_step, -in_orbit_delta.x * orbit_rotation_current_sensitivity, \
				ORBIT_SMOOTHING_FACTOR)
		y_lerped_step = lerp(y_lerped_step, in_orbit_delta.y * orbit_rotation_current_sensitivity, \
				ORBIT_SMOOTHING_FACTOR)
	else:
		x_lerped_step = -in_orbit_delta.x * orbit_rotation_current_sensitivity
		y_lerped_step = in_orbit_delta.y * orbit_rotation_current_sensitivity
	
	var msep_editor_settings: MSEPSettings = MolecularEditorContext.msep_editor_settings
	var rotation_direction: float = -1.0 if \
	msep_editor_settings.editor_camera_camera_orbit_x_inverted else 1.0
	var x_quat := Quaternion(camera_quat.inverse() * current_up, x_lerped_step * rotation_direction)
	rotation_direction = -1.0 if msep_editor_settings.editor_camera_camera_orbit_y_inverted else 1.0
	var y_quat := Quaternion(Vector3.LEFT, y_lerped_step * rotation_direction)
	
	camera_quat = (camera_quat * x_quat * y_quat).normalized()
	_camera.global_transform.basis = Basis(camera_quat).orthonormalized()
	
	var goal_position : Vector3 = get_orbit_pivot_position() - camera_quat * \
	Vector3.FORWARD * orbit_radius + calculate_screen_offset(orbit_radius)
	
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	if !is_orbiting:
		if no_selection_orbit_active:
			is_orbiting = true
			orbit_screen_vector = camera_quat.inverse() * orbit_old_camera_position - \
					camera_quat.inverse() * goal_position
		else:
			if workspace_has_transformable_selection:
				orbit_screen_vector = camera_quat.inverse() * orbit_old_camera_position - \
						camera_quat.inverse() * goal_position
				is_orbiting = true
	elif !no_selection_orbit_active || workspace_context.has_selection():
		orbit_screen_vector = orbit_screen_vector.slerp(Vector3.ZERO, ORBIT_TO_CENTER_SPEED)
	
	var screen_offset := camera_quat * orbit_screen_vector
	_camera.global_position = goal_position + screen_offset


func calculate_screen_offset(in_orbit_radius: float) -> Vector3:
	var center_of_viewport3D: Vector3 = _camera.project_position(_editor_viewport.size * .5,\
			in_orbit_radius)
	var rect_center: Vector2 = working_area_rect_control.get_global_rect().get_center()
	var center_of_rect3D: Vector3 = _camera.project_position(Vector2(rect_center.x + \
			RIGHT_PANEL_ADJUSTMENT, rect_center.y), in_orbit_radius)
	return center_of_viewport3D - center_of_rect3D


func drag_rotate_camera() -> void:
	if mouse_drag_in_widget_is_active:
		if !workspace_has_transformable_selection:
			no_selection_orbit_active = true
			var adjusted_speed : float = \
			axes_widget_3d.FASTER_TRANSFORM_COEFFICIENT if axes_widget_3d.transform_faster else 1.0
			rotate_to_orbit(mouse_delta * adjusted_speed)
		else:
			no_selection_orbit_active = false
			var adjusted_speed : float = \
			axes_widget_3d.FASTER_TRANSFORM_COEFFICIENT if axes_widget_3d.transform_faster else 1.0
			rotate_to_orbit(mouse_delta * adjusted_speed)


func update(in_delta_time : float) -> void:
	_camera = _editor_viewport.get_camera_3d()
	mouse_position = _editor_viewport.get_mouse_position()
	
	manage_continuous_input(in_delta_time)
	axes_widget_3d.update(in_delta_time)


func get_orbit_pivot_position() -> Vector3:
	if workspace_has_transformable_selection && is_instance_valid(GizmoRoot.selected_node):
		# This is better than orbiting around the center of selection AABB, because:
		# - No need to recalculate the AABB constantly while transformation happens.
		# - As the center of AABB will change if the selection is rotated with the gizmo it means
		#   the gizmo position would have to move to correspond with the new center which would be
		#   very confusing for the user.
		return GizmoRoot.selected_node.global_position
	else:
		# old_selection_position is set in camera_input_handler.gd, so that it's set before
		# any orbiting has happened in different scenarios and it will also happen only when input
		# is received.
		var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
		if workspace_context.has_selection():
			return workspace_context.get_selection_aabb().get_center()
		else:
			return old_selection_position
