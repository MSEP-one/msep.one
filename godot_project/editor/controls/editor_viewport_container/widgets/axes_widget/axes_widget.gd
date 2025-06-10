class_name AxesWidget3D extends Node3D

# The idea is that camera transformation should ease it, but stop immediately on all keys release.
# Because then we get precise start of transformation and perfect end, where when both combined
# produces the best result.

const MOUSE_WHEEL_MOVE_DURATION: float = .2
# We have very unstable frame rate, so I am clamping delta time to prevent jitters.
const ORBIT_RADIUS_CHANGE_FACTOR = .1
const KEYBOARD_ORBIT_ROTATION_SPEED_FACTOR = 1000.0
const MOUSE_ORBIT_ROTATION_SPEED_FACTOR = 20.0
const SMOOTH_DELTA_BUFFER_SIZE = 5
const SMOOTH_MOUSE_DELTA_BUFFER_SIZE = 5
const SMOOTH_MOUSE_DELTA_SPEED_LIMIT = 200.0
const FPS_LIMITS = Vector2(.016, .033)
const STOP = 0
const FORWARD = 1
const BACK = -1
const LEFT = 1
const RIGHT = -1
const UP = -1
const DOWN = 1
const AXIS_WRAPPER_DISTANCE = 50.0
const KEYBOARD_MOVEMENT_SPEED = -4.0
const KEYBOARD_ROTATION_SPEED = .1
# Currently the objects that are on the surface of the imaginary sphere will implicitly move slower
# if they are closer. If needed could implmement an alhorithm that would rotate camera at a speed
# relative the the sphere size (the distance to a specific object). But current behavior seems a lot
# more intuitive.
const FOLLOW_ROTATION_SPEED = .6
const FASTER_TRANSFORM_COEFFICIENT = 5.0
const ADDITIONAL_FASTER_WHEEL_COEFFICIENT = 5.0
const CAMERA_EASE_COEFFICIENT = 3.0
const CAMERA_FOLLOW_EASE_COEFFICIENT = .1
const ORTHOGRAPHIC_ZOOM_SENSITIVITY = 0.4
const ORTHOGRAPHIC_ZOOM_MAX = 0.01 # Smaller number means larger zoom. Strictly greater than 0.
const CAMERA_ROTATION_FACTOR: float = .0001

var camera_move_direction : Vector3 = Vector3.ZERO
var camera_move_ease := Vector3.ZERO
var clamped_delta_time : float = FPS_LIMITS.x
var last_delta_times : Array = []
var last_mouse_deltas : Array = []
var transform_faster : bool = false
var camera_rotation := Quaternion.IDENTITY
var rotation_x_coefficient : int = 0
var rotation_y_coefficient : int = 0
var movement_x_coefficient : int = 0
var movement_y_coefficient : int = 0
var movement_z_coefficient : int = 0
var rotation_must_follow_mouse := false
var mouse_delta := Vector2.ZERO
var mouse_wheel_move_time_left: float = .0
var mouse_wheel_movement: bool = false
@onready var _editor_viewport: WorkspaceEditorViewport = _find_editor_viewport()
@onready var _camera : Camera3D = _find_editor_viewport_camera_3d()
@onready var gizmo : Control = owner


func _find_editor_viewport() -> WorkspaceEditorViewport:
	var ancestor: Node = get_parent()
	while not ancestor is SubViewportContainer:
		ancestor = ancestor.get_parent()
	return ancestor.get_child(0) as WorkspaceEditorViewport


func _find_editor_viewport_camera_3d() -> Camera3D:
	assert(_editor_viewport, "Invalid project hierarchy, could not find viewport!")
	return _editor_viewport.get_camera_3d()


func calculate_smooth_delta_time(in_delta_time : float) -> float:
	if last_delta_times.size() > SMOOTH_DELTA_BUFFER_SIZE - 1:
		last_delta_times.pop_front()
	last_delta_times.push_back(in_delta_time)
	var old_delta_sum := .0
	for old_delta: float in last_delta_times:
		old_delta_sum += old_delta
	return old_delta_sum / SMOOTH_DELTA_BUFFER_SIZE


func calculate_smooth_mouse_delta(in_mouse_delta : Vector2) -> Vector2:
	if last_mouse_deltas.size() > SMOOTH_MOUSE_DELTA_BUFFER_SIZE - 1:
		last_mouse_deltas.pop_front()
	last_mouse_deltas.push_back(in_mouse_delta)
	var old_delta_sum := Vector2.ZERO
	for old_delta: Vector2 in last_mouse_deltas:
		old_delta_sum += old_delta
	var result_raw := old_delta_sum / SMOOTH_MOUSE_DELTA_BUFFER_SIZE
	var result_x : float = sign(result_raw.x) * min(abs(result_raw.x), \
			SMOOTH_MOUSE_DELTA_SPEED_LIMIT)
	var result_y : float = sign(result_raw.y) * min(abs(result_raw.y), \
			SMOOTH_MOUSE_DELTA_SPEED_LIMIT)
	return Vector2(result_x, result_y)


func initiate_camera_orbit_on_mouse() -> void:
	movement_z_coefficient = STOP
	# To restore orbiting intertia check: 8c59342316b0407e60043b6a31772e39265e7275
	gizmo.rotate_to_orbit(mouse_delta)


func update(in_delta_time : float) -> void:
	var smooth_delta_time := calculate_smooth_delta_time(in_delta_time)
	clamped_delta_time = clamp(smooth_delta_time, FPS_LIMITS.x, FPS_LIMITS.y)
	if rotation_must_follow_mouse:
		if !gizmo.workspace_has_transformable_selection:
			gizmo.no_selection_orbit_active = true
			initiate_camera_orbit_on_mouse()
		else:
			gizmo.no_selection_orbit_active = false
			initiate_camera_orbit_on_mouse()
	else:
		if !gizmo.workspace_has_transformable_selection:
			gizmo.no_selection_orbit_active = true
			initiate_camera_orbit_on_keyboard()
		else:
			gizmo.no_selection_orbit_active = false
			initiate_camera_orbit_on_keyboard()
	if gizmo.is_orbiting:
		if mouse_wheel_movement:
			interrupt_mouse_wheel_movement()
		change_orbit_radius()
	else:
		move_camera(in_delta_time)
	position_axes_wrapper()
	ensure_orthographic_camera_outside_structure()
	mouse_delta = Vector2.ZERO
	camera_rotation = (_camera.global_transform.basis.get_rotation_quaternion()).normalized()


func set_mouse_delta(in_delta: Vector2) -> void:
	mouse_delta = in_delta * clamped_delta_time


func position_axes_wrapper() -> void:
	_camera = _find_editor_viewport_camera_3d()
	var camera_direction := _camera.global_transform.basis.get_rotation_quaternion() \
			* Vector3.FORWARD
	global_position = _camera.global_position + camera_direction * AXIS_WRAPPER_DISTANCE


func initiate_camera_orbit_on_keyboard() -> void:
	if rotation_x_coefficient != STOP || rotation_y_coefficient != STOP:
		var lerped_x_rotation_step : float = lerp(.0, \
				float(rotation_x_coefficient), CAMERA_ROTATION_FACTOR)
		var lerped_y_rotation_step : float = lerp(.0, \
				-float(rotation_y_coefficient), CAMERA_ROTATION_FACTOR)
		var orbit_delta := Vector2(lerped_x_rotation_step, lerped_y_rotation_step) * \
				KEYBOARD_ORBIT_ROTATION_SPEED_FACTOR
		gizmo.rotate_to_orbit(orbit_delta)


func start_mouse_wheel_movement_step() -> void:
	camera_move_ease.z = float(movement_z_coefficient)
	mouse_wheel_movement = true
	mouse_wheel_move_time_left = MOUSE_WHEEL_MOVE_DURATION


func interrupt_mouse_wheel_movement() -> void:
	mouse_wheel_movement = false
	camera_move_ease.z = .0


func manage_mouse_wheel_movement_state(_in_delta_time: float) -> void:
	# If we still want to re enable inertia, then check out this file how it worked here:
	# 6cb34309400c2fa4b47ad8956a78207480f562fb
	mouse_wheel_move_time_left -= mouse_wheel_move_time_left
	if mouse_wheel_movement && mouse_wheel_move_time_left < .0:
		interrupt_mouse_wheel_movement()


func move_camera(in_delta_time: float) -> void:
	if !MolecularEditorContext.get_current_workspace_context().has_visible_objects():
		return
	
	if mouse_wheel_movement and mouse_wheel_move_time_left <= .0:
		interrupt_mouse_wheel_movement()
		return
	
	if movement_x_coefficient != STOP || movement_y_coefficient != STOP || \
			movement_z_coefficient != STOP:
		var adjusted_speed := KEYBOARD_MOVEMENT_SPEED * (FASTER_TRANSFORM_COEFFICIENT \
				if transform_faster else 1.0)
		if mouse_wheel_movement:
			camera_move_direction = camera_move_ease
			adjusted_speed *= (ADDITIONAL_FASTER_WHEEL_COEFFICIENT if transform_faster else 1.0)
		else:
			camera_move_direction = camera_move_direction.slerp(camera_move_ease, \
					CAMERA_EASE_COEFFICIENT * clamped_delta_time)
		var final_camera_motion: Vector3 = camera_move_direction * adjusted_speed * clamped_delta_time
		if _camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
			_camera.translate(final_camera_motion)
		else:
			const VERTICAL_AND_HORIZONTAL_MASK := Vector3(1.0, 1.0, 0.0)
			const DEPTH_MASK := Vector3(0.0, 0.0, 1.0)
			var lateral_motion: Vector3 = final_camera_motion * VERTICAL_AND_HORIZONTAL_MASK
			var forward_motion: Vector3 = final_camera_motion * DEPTH_MASK
			_camera.translate(lateral_motion)
			_camera.size = max(_camera.size + forward_motion.z * ORTHOGRAPHIC_ZOOM_SENSITIVITY, ORTHOGRAPHIC_ZOOM_MAX)

	manage_mouse_wheel_movement_state(in_delta_time)


func change_orbit_radius() -> void:
	if movement_z_coefficient != STOP:
		var adjusted_speed := ORBIT_RADIUS_CHANGE_FACTOR * (FASTER_TRANSFORM_COEFFICIENT \
				if transform_faster else 1.0)
		camera_move_direction = camera_move_direction.slerp(camera_move_ease, \
				CAMERA_EASE_COEFFICIENT * clamped_delta_time)
		gizmo.adjust_orbit(-sign(movement_z_coefficient) * \
				camera_move_direction.length() * adjusted_speed)


## Moves the orthographic camera backward until it's outside of the project
## structures' volume, otherwise atoms behind the camera will be clipped.
func ensure_orthographic_camera_outside_structure() -> void:
	if not _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return
	var workspace_context: WorkspaceContext = _editor_viewport.get_workspace_context()
	if workspace_context.has_visible_objects():
		var workspace_aabb: AABB = WorkspaceUtils.get_visible_objects_aabb(workspace_context)
		if workspace_aabb.get_longest_axis_size() > workspace_context.get_camera().far:
			# This would affect rendering
			return
		WorkspaceUtils.move_camera_outside_of_aabb(workspace_context, workspace_aabb)
