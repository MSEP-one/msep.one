class_name CameraWidget extends Control

signal camera_movement_started()
signal camera_movement_ended()

# State
enum MoveDirection {
	NONE,
	LEFT,
	RIGHT,
	UP,
	DOWN,
	FORWARD,
	BACK
}

const MAX_RESOLUTION: float = 16384.0
const WIDGET_SIZE: float = 8.0
const _EPSILON: float = .001
const _DEFAULT_SPEED_FACTOR: float = 1.0
const _NORMALIZED_PROGRESS_MAX: float = 1.0
const _NORMALIZED_PROGRESS_MIN: float = .0
const _NO_TIME_LEFT: float = .0
const _DEFAULT_WIDGET_SIZE: Vector2 = Vector2(309, 309)

@export var _movement_speed_on_click: float = 5.0
@export var _movement_distance_on_click: float = .25
@export var _detect_hold_time: float = .25
@export var _highlight_speed: float = 10.0
@export var _click_move_curve: Curve = null
@export var _hold_movement_speed: float = 1.0
@export var _hold_acceleration_curve: Curve = null
@export var _hold_acceleration_speed: float = 10.0
@export var _hold_acceleration_time: float = 2.0
@export var _faster_movement_factor: float = 5.0
@export var _zoom_sensitivity: float = 0.01

var _detect_hold_time_left: float = _detect_hold_time
var _hold_is_active: bool = false
var _move_direction: MoveDirection = MoveDirection.NONE
var _previous_move_direction: MoveDirection = MoveDirection.NONE
var _movement_translation_goal: Vector3 = Vector3.ZERO
var _click_movement_lerp_progress: float = _NORMALIZED_PROGRESS_MAX
var _movement_start_position: Vector3 = Vector3.ZERO
var _move_faster_factor: float = _DEFAULT_SPEED_FACTOR
var _hold_movement_acceleration_progress: float = _NORMALIZED_PROGRESS_MIN
var _initial_scale_factor: Vector2 = Vector2.ONE


var workspace_tools_container : Control = null

# Just to avoid the need to maintain and jump between 6 scripts.
@onready var _handle_control_to_move_handle_data: Dictionary = {
	# _handle: TextureRect = data<MoveHandleData>
	%UpArrow:      MoveHandleData.new(false, %UpArrow.self_modulate, Color.TRANSPARENT),
	%DownArrow:    MoveHandleData.new(false, %DownArrow.self_modulate, Color.TRANSPARENT),
	%LeftArrow:    MoveHandleData.new(false, %LeftArrow.self_modulate, Color.TRANSPARENT),
	%RightArrow:   MoveHandleData.new(false, %RightArrow.self_modulate, Color.TRANSPARENT),
	%ForwardArrow: MoveHandleData.new(false, %ForwardArrow.self_modulate, Color.TRANSPARENT),
	%BackArrow:    MoveHandleData.new(false, %BackArrow.self_modulate, Color.TRANSPARENT)
}
@onready var _editor_viewport: WorkspaceEditorViewport = _find_editor_viewport()
@onready var _camera : Camera3D = _find_editor_viewport_camera_3d()
@onready var _scale_control: Control = %ScaleControl

# End State


func _ready() -> void:
	assert(_click_move_curve != null, "Please assign _click_move_curve, it must not be null")
	assert(_hold_acceleration_curve != null, "Please assign _hold_acceleration_curve, it must not be null")
	_initial_scale_factor = _scale_control.scale
	_editor_viewport.size_changed.connect(_adjust_relative_to_resolution)
	MolecularEditorContext.msep_editor_settings.changed.connect(_adjust_relative_to_resolution)
	_adjust_relative_to_resolution()


func _process(_delta: float) -> void:
	# Clicks are managed in _gui_event functions.
	_manage_detect_hold_time()
	_manage_handle_highlight()
	_manage_pressed_visuals()
	_move_towards_the_goal()
	
	_previous_move_direction = _move_direction


# Tools
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


func _adjust_relative_to_resolution() -> void:
	var current_screen_size: Vector2 = DisplayServer.screen_get_size()
	var x_factor: float = current_screen_size.x / MAX_RESOLUTION * WIDGET_SIZE
	var global_widget_scale: float = MolecularEditorContext.msep_editor_settings.ui_widget_scale
	_scale_control.scale = Vector2(x_factor, x_factor) * _initial_scale_factor * global_widget_scale
	custom_minimum_size = _DEFAULT_WIDGET_SIZE * _scale_control.scale


func _reset_input() -> void:
	# It's fine to do this in each event, because releases won't overlap.
	_move_direction = MoveDirection.NONE
	# To prevent any hypothetical/potential floating point errors.
	_hold_is_active = false
	_hold_movement_acceleration_progress = _NORMALIZED_PROGRESS_MIN
# End Tools


# Hold section
func _manage_left_hold_direction() -> void:
	if _detect_hold_time_left < _NO_TIME_LEFT:
		_hold_is_active = true
		_move_left_on_hold()


func _manage_right_hold_direction() -> void:
	if _detect_hold_time_left < _NO_TIME_LEFT:
		_hold_is_active = true
		_move_right_on_hold()


func _manage_up_hold_direction() -> void:
	if _detect_hold_time_left < _NO_TIME_LEFT:
		_hold_is_active = true
		_move_up_on_hold()


func _manage_down_hold_direction() -> void:
	if _detect_hold_time_left < _NO_TIME_LEFT:
		_hold_is_active = true
		_move_down_on_hold()


func _manage_forward_hold_direction() -> void:
	if _detect_hold_time_left < _NO_TIME_LEFT:
		_hold_is_active = true
		_move_forward_on_hold()


func _manage_back_hold_direction() -> void:
	if _detect_hold_time_left < _NO_TIME_LEFT:
		_hold_is_active = true
		_move_back_on_hold()


func _manage_detect_hold_time() -> void:
	var delta_time: float = get_process_delta_time()
	_detect_hold_time_left -= delta_time
	match _move_direction:
		MoveDirection.LEFT:
			_manage_left_hold_direction()
		MoveDirection.RIGHT:
			_manage_right_hold_direction()
		MoveDirection.UP:
			_manage_up_hold_direction()
		MoveDirection.DOWN:
			_manage_down_hold_direction()
		MoveDirection.FORWARD:
			_manage_forward_hold_direction()
		MoveDirection.BACK:
			_manage_back_hold_direction()
# End Hold section


# Click section
func _manage_left_click_direction() -> void:
	if !_hold_is_active:
		_start_movement_left_on_click()


func _manage_right_click_direction() -> void:
	if !_hold_is_active:
		_start_movement_right_on_click()


func _manage_up_click_direction() -> void:
	if !_hold_is_active:
		_start_movement_up_on_click()


func _manage_down_click_direction() -> void:
	if !_hold_is_active:
		_start_movement_down_on_click()


func _manage_forward_click_direction() -> void:
	if !_hold_is_active:
		_start_movement_forward_on_click()


func _manage_back_click_direction() -> void:
	if !_hold_is_active:
		_start_movement_back_on_click()
# End Click section


# Input
func _input(in_event: InputEvent) -> void:
	if in_event is InputEventKey:
		if in_event.is_action_pressed(&"faster_camera"):
			_move_faster_factor = _faster_movement_factor
		elif in_event.is_action_released(&"faster_camera"):
			_move_faster_factor = _DEFAULT_SPEED_FACTOR


# _gui_event functions
func _on_up_arrow_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseButton:
		if in_event.is_pressed():
			if in_event.button_index == MOUSE_BUTTON_LEFT:
				_detect_hold_time_left = _detect_hold_time
				_move_direction = MoveDirection.UP
				camera_movement_started.emit()
		else:
			_manage_up_click_direction()
			_reset_input()
			camera_movement_ended.emit()


func _on_down_arrow_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseButton:
		if in_event.is_pressed():
			if in_event.button_index == MOUSE_BUTTON_LEFT:
				_detect_hold_time_left = _detect_hold_time
				_move_direction = MoveDirection.DOWN
				camera_movement_started.emit()
		else:
			_manage_down_click_direction()
			_reset_input()
			camera_movement_ended.emit()


func _on_left_arrow_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseButton:
		if in_event.is_pressed():
			if in_event.button_index == MOUSE_BUTTON_LEFT:
				_detect_hold_time_left = _detect_hold_time
				_move_direction = MoveDirection.LEFT
				camera_movement_started.emit()
		else:
			_manage_left_click_direction()
			_reset_input()
			camera_movement_ended.emit()


func _on_right_arrow_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseButton:
		if in_event.is_pressed():
			if in_event.button_index == MOUSE_BUTTON_LEFT:
				_detect_hold_time_left = _detect_hold_time
				_move_direction = MoveDirection.RIGHT
				camera_movement_started.emit()
		else:
			_manage_right_click_direction()
			_reset_input()
			camera_movement_ended.emit()


func _on_forward_arrow_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseButton:
		if in_event.is_pressed():
			if in_event.button_index == MOUSE_BUTTON_LEFT:
				_detect_hold_time_left = _detect_hold_time
				_move_direction = MoveDirection.FORWARD
				camera_movement_started.emit()
		else:
			_manage_forward_click_direction()
			_reset_input()
			camera_movement_ended.emit()


func _on_back_arrow_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseButton:
		if in_event.is_pressed():
			if in_event.button_index == MOUSE_BUTTON_LEFT:
				_detect_hold_time_left = _detect_hold_time
				_move_direction = MoveDirection.BACK
				camera_movement_started.emit()
		else:
			_manage_back_click_direction()
			_reset_input()
			camera_movement_ended.emit()
# End _gui_event functions
# End Input


# Visuals
func _manage_pressed_visuals() -> void:
	for default_texture_rect: TextureRect in _handle_control_to_move_handle_data.keys():
		if _handle_control_to_move_handle_data[default_texture_rect].is_mouse_inside:
			var hover_texture_rect: TextureRect = default_texture_rect.get_child(1)
			if _move_direction != MoveDirection.NONE:
				default_texture_rect.self_modulate = Color.TRANSPARENT
				hover_texture_rect.self_modulate = Color.TRANSPARENT
			else:
				hover_texture_rect.self_modulate = Color.WHITE
				
			break


func _manage_handle_highlight() -> void:
	var delta_time: float = get_process_delta_time()
	for default_texture_rect: TextureRect in _handle_control_to_move_handle_data.keys():
		if _handle_control_to_move_handle_data[default_texture_rect].is_mouse_inside:
			if _move_direction == MoveDirection.NONE:
				default_texture_rect.self_modulate = \
				default_texture_rect.self_modulate.\
				lerp(_handle_control_to_move_handle_data[default_texture_rect].highlight_self_modulate, \
						_highlight_speed * delta_time)
		else:
			default_texture_rect.self_modulate = \
			default_texture_rect.self_modulate.\
			lerp(_handle_control_to_move_handle_data[default_texture_rect].original_self_modulate, _highlight_speed * \
					delta_time)


func _on_up_arrow_mouse_entered() -> void:
	_handle_control_to_move_handle_data[%UpArrow].is_mouse_inside = true


func _on_up_arrow_mouse_exited() -> void:
	_handle_control_to_move_handle_data[%UpArrow].is_mouse_inside = false


func _on_down_arrow_mouse_entered() -> void:
	_handle_control_to_move_handle_data[%DownArrow].is_mouse_inside = true


func _on_down_arrow_mouse_exited() -> void:
	_handle_control_to_move_handle_data[%DownArrow].is_mouse_inside = false


func _on_left_arrow_mouse_entered() -> void:
	_handle_control_to_move_handle_data[%LeftArrow].is_mouse_inside = true


func _on_left_arrow_mouse_exited() -> void:
	_handle_control_to_move_handle_data[%LeftArrow].is_mouse_inside = false


func _on_right_arrow_mouse_entered() -> void:
	_handle_control_to_move_handle_data[%RightArrow].is_mouse_inside = true


func _on_right_arrow_mouse_exited() -> void:
	_handle_control_to_move_handle_data[%RightArrow].is_mouse_inside = false


func _on_forward_arrow_mouse_entered() -> void:
	_handle_control_to_move_handle_data[%ForwardArrow].is_mouse_inside = true


func _on_forward_arrow_mouse_exited() -> void:
	_handle_control_to_move_handle_data[%ForwardArrow].is_mouse_inside = false


func _on_back_arrow_mouse_entered() -> void:
	_handle_control_to_move_handle_data[%BackArrow].is_mouse_inside = true


func _on_back_arrow_mouse_exited() -> void:
	_handle_control_to_move_handle_data[%BackArrow].is_mouse_inside = false
# End Visuals


# Camera Movement
func _prepare_click_movement_direction(in_direction: Vector3) -> void:
	_click_movement_lerp_progress = _NORMALIZED_PROGRESS_MIN
	_movement_start_position = _camera.global_position
	_movement_translation_goal = _camera.global_position + \
	_camera.global_basis.get_rotation_quaternion() \
			* in_direction * _movement_distance_on_click * _move_faster_factor


func _move_towards_the_goal() -> void:
	var delta_time: float = get_process_delta_time()
	if _click_movement_lerp_progress < _NORMALIZED_PROGRESS_MAX - _EPSILON:
		_click_movement_lerp_progress += (_movement_speed_on_click * delta_time) * \
				_click_move_curve.sample(_click_movement_lerp_progress)
		_camera.global_position = _movement_start_position.lerp(_movement_translation_goal, \
				_click_movement_lerp_progress)


# Move on click
func _start_movement_up_on_click() -> void:
	_prepare_click_movement_direction(Vector3.UP)


func _start_movement_down_on_click() -> void:
	_prepare_click_movement_direction(Vector3.DOWN)


func _start_movement_left_on_click() -> void:
	_prepare_click_movement_direction(Vector3.LEFT)


func _start_movement_right_on_click() -> void:
	_prepare_click_movement_direction(Vector3.RIGHT)


func _start_movement_forward_on_click() -> void:
	_prepare_click_movement_direction(Vector3.FORWARD)


func _start_movement_back_on_click() -> void:
	_prepare_click_movement_direction(Vector3.BACK)
# End Move on click


# Move on hold
func _move_on_hold(in_direction: Vector3) -> void:
	var delta_time: float = get_process_delta_time()
	_hold_movement_acceleration_progress = min(_hold_movement_acceleration_progress + \
			delta_time / max(_hold_acceleration_time, _EPSILON), _NORMALIZED_PROGRESS_MAX)
	var curve_acceleration_factor: float = \
	_hold_acceleration_curve.sample(_hold_movement_acceleration_progress)
	var hold_acceleration: float = _hold_movement_acceleration_progress * \
	curve_acceleration_factor * _hold_acceleration_speed
	_camera.translate(in_direction * _hold_movement_speed * delta_time * _move_faster_factor * \
			hold_acceleration)


func _zoom_on_hold(in_ratio: float) -> void:
	_camera.size *= in_ratio


func _move_up_on_hold() -> void:
	_move_on_hold(Vector3.UP)


func _move_down_on_hold() -> void:
	_move_on_hold(Vector3.DOWN)


func _move_left_on_hold() -> void:
	_move_on_hold(Vector3.LEFT)


func _move_right_on_hold() -> void:
	_move_on_hold(Vector3.RIGHT)


func _move_forward_on_hold() -> void:
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_zoom_on_hold(1.0 - _zoom_sensitivity)
	else:
		_move_on_hold(Vector3.FORWARD)


func _move_back_on_hold() -> void:
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_zoom_on_hold(1.0 + _zoom_sensitivity)
	else:
		_move_on_hold(Vector3.BACK)
# Move on hold
# End Camera Movement


class MoveHandleData:
	var is_mouse_inside: bool
	var original_self_modulate: Color
	var highlight_self_modulate: Color
	
	func _init(in_is_mouse_inside: bool, in_original_self_modulate: Color, in_highlight_self_modulate: Color) -> void:
		is_mouse_inside = in_is_mouse_inside
		original_self_modulate = in_original_self_modulate
		highlight_self_modulate = in_highlight_self_modulate
