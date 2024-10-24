extends Node2D

const EPSILON: float = .0001
const MIN_DISTANCE_FROM_SCREEN: float = 0.5
const DEFAULT_TEXTURE: Texture = preload("res://addons/runtimespatialgizmo/RuntimeSpatialGizmo/svg/UI_box_arrows_default.svg")
const HOVER_TEXTURE: Texture = preload("res://addons/runtimespatialgizmo/RuntimeSpatialGizmo/svg/UI_box_arrows_hover.svg")
const PRESSED_TEXTURE: Texture = preload("res://addons/runtimespatialgizmo/RuntimeSpatialGizmo/svg/UI_box_arrows_pressed.svg")

## To manually adjust size.
@export var custom_size: float = 1.0
## To manually adjust offset.
@export var custom_offset: Vector2 = Vector2(0.001, -.001)

## To preserve x and y dimensions relative scale.
var _relative_scale: Vector2 = Vector2.ONE
## To keep around dynamic drawn texture offset.
var _drawing_offset: Vector2 = Vector2.ZERO
## To keep around and re use mouse position.
var _mouse_position: Vector2 = Vector2.ZERO
## To keep relative grab distance from mouse to the center of gizmo.
var _initial_gizmo_unprojected_pos: Vector2 = Vector2.ZERO
var _mouse_grab_offset: Vector2 = Vector2.ZERO

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
	
	detect_collision()
	move_on_camera_local_xy_axis()


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
						if GizmoRoot.mouse_hover_detected.ortho_z_surface && GizmoRoot.grab_mode == \
						GizmoRoot.GrabMode.NONE:
							GizmoRoot.grab_mode = GizmoRoot.GrabMode.ORTHO_Z_SURFACE
			else:
				GizmoRoot.grab_mode = GizmoRoot.GrabMode.NONE


func detect_collision() -> void:
	var half_size: Vector2 = drawing.get_size() * .5
	var drawing_center: Vector2 = drawing.global_position + half_size
	
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.ORTHO_Z_SURFACE:
		drawing.texture = PRESSED_TEXTURE
		return
	
	if _mouse_position.distance_to(drawing_center) < half_size.x:
		if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
			GizmoRoot.collision_mode = GizmoRoot.CollisionMode.ORTHO_Z_SURFACE
			GizmoRoot.mouse_hover_detected.ortho_z_surface = true
			drawing.texture = HOVER_TEXTURE
	else:
		GizmoRoot.collision_mode = GizmoRoot.CollisionMode.NONE
		if GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
			GizmoRoot.mouse_hover_detected.ortho_z_surface = false
			drawing.texture = DEFAULT_TEXTURE


func move_on_camera_local_xy_axis() -> void:
	if GizmoRoot.grab_mode == GizmoRoot.GrabMode.ORTHO_Z_SURFACE:
		UIBlocker.block_current_frame_input_events()
		var distance_from_screen: float = -(camera.global_transform.affine_inverse() * \
				selected_node.global_position).z
		var mouse_clamped_position: Vector2 = _mouse_position
		if Input.is_key_pressed(KEY_SHIFT):
			if abs(_mouse_position.x - _initial_gizmo_unprojected_pos.x) < abs(_mouse_position.y - _initial_gizmo_unprojected_pos.y):
				mouse_clamped_position.x = _initial_gizmo_unprojected_pos.x
			else:
				mouse_clamped_position.y = _initial_gizmo_unprojected_pos.y
		var new_position: Vector3 = camera.project_position(mouse_clamped_position + _mouse_grab_offset, \
				distance_from_screen)
		selected_node.global_position = new_position
	else:
		_initial_gizmo_unprojected_pos = camera.unproject_position(selected_node.global_position)
		_mouse_grab_offset = camera.unproject_position(selected_node.global_position) - _mouse_position
