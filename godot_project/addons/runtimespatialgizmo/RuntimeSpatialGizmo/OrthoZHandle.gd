extends Node2D

const EPSILON: float = .0001
const MIN_DISTANCE_FROM_SCREEN: float = 0.5
const MAX_DISTANCE_FROM_SCREEN_FACTOR: float = 0.1
const MAX_DISTANCE_FROM_START_POSITION: float = 100
const MOUSE_SENSITIVITY: float = 0.1
const DEFAULT_TEXTURE: Texture = preload("res://addons/runtimespatialgizmo/RuntimeSpatialGizmo/svg/UI_transformGizmo_Z_control_default.svg")
const HOVER_TEXTURE: Texture = preload("res://addons/runtimespatialgizmo/RuntimeSpatialGizmo/svg/UI_transformGizmo_Z_control_hover.svg")
const PRESSED_TEXTURE: Texture = preload("res://addons/runtimespatialgizmo/RuntimeSpatialGizmo/svg/UI_transformGizmo_Z_control_pressed.svg")

## To manually adjust size.
@export var custom_size: float = 1.0
## To manually adjust offset.
@export var custom_offset: Vector2 = Vector2(-0.001, .0)

## To move at this relative speed, when dragging.
var _movement_speed: float = .01
## To preserve x and y dimensions relative scale.
var _relative_scale: Vector2 = Vector2.ONE
## To keep around dynamic drawn texture offset.
var _drawing_offset: Vector2 = Vector2.ZERO
## To calculate the movement step.
var _mouse_old_position: Vector2 = Vector2.ZERO
## To keep around and re use mouse position.
var _mouse_position: Vector2 = Vector2.ZERO
## To move the selection towards or away camera orthographically.
var _z_direction: Vector3 = Vector3.ZERO
## To prevent moving the selection too far in a single action
var _start_global_position: Vector3 = Vector3.ZERO

# get_child(0) is intentional we want to know if structure changed.
## For user to see anything.
@onready var drawing: TextureRect = get_child(0)
## To get common gizmo settings.
@onready var gizmo: Node3D = owner
## To calculate size relative changes.
@onready var x_axis: Node3D = %X

## To perform projection calculations.
var camera: Camera3D:
	get:
		return GizmoRoot.camera_3D
## To know where to place the drawing.
var selected_node: Node3D:
	get:
		return GizmoRoot.selected_node

func _draw() -> void:
	if GizmoRoot.transform_init_counter > 0:
		drawing.visible = false
		return
	else:
		drawing.visible = true
	
	if !is_instance_valid(camera) || !is_instance_valid(selected_node):
		return
	
	var x_axis_position: Vector3 = gizmo.global_position + \
		camera.global_transform.basis.get_rotation_quaternion() * Vector3.RIGHT * x_axis.position.x
	var axis_delta: float = (camera.unproject_position(gizmo.global_position) - \
			camera.unproject_position(x_axis_position)).length()
	var relative_delta_size: Vector2 = _relative_scale * axis_delta
	_drawing_offset = relative_delta_size * custom_size
	drawing.set_size(_drawing_offset)
	drawing.position = custom_offset * relative_delta_size


func update_drawing() -> void:
	global_position = camera.unproject_position(selected_node.global_position)
	queue_redraw()


func preserve_dimensions() -> void:
	var rs: Vector2 = gizmo.calculate_relative_scale()
	var rsx: float = rs.x if abs(rs.x) > EPSILON else EPSILON * sign(rs.x)
	var rsy: float = rs.y if abs(rs.y) > EPSILON else EPSILON * sign(rs.y)
	_relative_scale = Vector2.ONE / Vector2(rsx, rsy)
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_relative_scale *= camera.size * gizmo.ORTHOGRAPHIC_SCALE


func _process(_in_delta: float) -> void:
	if !is_instance_valid(selected_node) || !is_instance_valid(camera):
		return
	
	_mouse_position = get_viewport().get_mouse_position()
	
	preserve_dimensions()
	
	detect_collision(get_viewport().get_mouse_position())
	move_on_camera_local_z_axis()
	
	_mouse_old_position = _mouse_position


func gizmo_input(event: InputEvent) -> void:
	if GizmoRoot.input_is_allowed and event is InputEventMouse:
		var viewport_rect = get_viewport_rect()
		if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE && !viewport_rect.has_point(_mouse_position):
			return
		if event is InputEventMouseButton:
			GizmoRoot.input_is_being_consumed = true
			if event.is_pressed():
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						if GizmoRoot.mouse_hover_detected.ortho_z_handle && GizmoRoot.grab_mode == \
						GizmoRoot.GrabMode.NONE:
							GizmoRoot.grab_mode = GizmoRoot.GrabMode.ORTHO_Z_HANDLE
							_start_global_position = selected_node.global_position
			else:
				GizmoRoot.grab_mode = GizmoRoot.GrabMode.NONE


func detect_collision(in_mouse_position: Vector2) -> void:
	var half_size: Vector2 = drawing.get_size() * .5
	var drawing_center: Vector2 = drawing.global_position + half_size
	
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.ORTHO_Z_HANDLE:
		drawing.texture = PRESSED_TEXTURE
		return
	
	if in_mouse_position.distance_to(drawing_center) < half_size.x:
		if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
			GizmoRoot.collision_mode = GizmoRoot.CollisionMode.ORTHO_Z_HANDLE
			GizmoRoot.mouse_hover_detected.ortho_z_handle = true
			drawing.texture = HOVER_TEXTURE
	else:
		GizmoRoot.collision_mode = GizmoRoot.CollisionMode.NONE
		if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
			GizmoRoot.mouse_hover_detected.ortho_z_handle = false
			drawing.texture = DEFAULT_TEXTURE


func move_on_camera_local_z_axis() -> void:
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.ORTHO_Z_HANDLE:
		UIBlocker.block_input()
		var mouse_delta: Vector2 = _mouse_position - _mouse_old_position
		var camera_relative_movement_speed: float = _movement_speed * \
		selected_node.global_position.distance_to(camera.global_position)
		var move_step: Vector3 = _z_direction * camera_relative_movement_speed * mouse_delta.y * MOUSE_SENSITIVITY
		var new_position: Vector3 = selected_node.global_position + move_step
		var distance_from_screen: float = -(camera.global_transform.affine_inverse() * new_position).z
		var total_travel: float = new_position.distance_to(_start_global_position)
		if total_travel > MAX_DISTANCE_FROM_START_POSITION:
			return
		
		# Clamp the allowed min and max distance from the screen to ensure that it's not confusing
		# for the user to use the gizmo and so that the molecular structure isn't collapsing after
		# moved too far.
		if distance_from_screen > MIN_DISTANCE_FROM_SCREEN && \
		distance_from_screen < camera.far * MAX_DISTANCE_FROM_SCREEN_FACTOR:
			selected_node.global_position = new_position
	else:
		_z_direction = (camera.global_position - selected_node.global_position).normalized()
