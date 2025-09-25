extends Control

@onready var _camera: Camera3D = _find_editor_viewport_camera_3d()
@onready var _radius: float = min(size.x, size.y) / 2.0 - 3.0

var _hovered: bool = false
var _rolling: bool = false
var _start_roll_angle: float
var _current_roll_angle: float
var _start_transform: Transform3D


func _ready() -> void:
	assert(get_parent().has_method("get_orbit_pivot_position"),
		"Node hierarchy changed, this node is no longer child of AxesWidget, or method was remored/renamed")
	pass


func _has_point(point: Vector2) -> bool:
	if _rolling:
		return true
	var center: Vector2 = size / 2
	var distance: float = center.distance_to(point)
	var hovered: bool = abs(_radius-distance) < 6.0
	if hovered != _hovered:
		_hovered = hovered
		queue_redraw()
	return _hovered


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var width: float = 5 if _hovered else 2
	draw_circle(center, _radius, Color.WHITE, false, width)
	if not _rolling:
		return
	var line1_p2: Vector2 = center + Vector2.RIGHT.rotated(_start_roll_angle) * _radius
	draw_line(center, line1_p2, Color.WHITE, 2)
	var mouse_pos: Vector2 = get_local_mouse_position()
	var line2_p2: Vector2 = mouse_pos
	if center.distance_squared_to(mouse_pos) < _radius * _radius:
		# mouse is inside of the cicle, let's snap to the radius
		line2_p2 = center + Vector2.RIGHT.rotated(_current_roll_angle) * _radius
	draw_line(center, line2_p2, Color.WHITE, 2)
	if not is_equal_approx(_start_roll_angle, _current_roll_angle):
		var diff: float = _current_roll_angle - _start_roll_angle
		var point_count: int = max(2,abs(ceil(rad_to_deg(diff))) / 5)
		var angle_step: float = 1.0 / (point_count - 1)
		const FILL_COLOR := Color(1.0, 1.0, 1.0, 0.6)
		var arc_points := PackedVector2Array()
		var arc_colors := PackedColorArray()
		var arc_from: Vector2 = Vector2.RIGHT.rotated(_start_roll_angle)
		var arc_to: Vector2 = Vector2.RIGHT.rotated(_current_roll_angle)
		for i: int in point_count:
			var slerp_factor: float = angle_step * i
			var point: Vector2 = (arc_from).slerp(arc_to, slerp_factor)
			arc_points.append(center + point * _radius)
			arc_colors.append(FILL_COLOR)
		arc_points.append(center)
		arc_colors.append(FILL_COLOR)
		draw_polygon(arc_points, arc_colors)
	


func _gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseMotion and _rolling:
		_update_roll(in_event.position)
		queue_redraw()
	if in_event is InputEventMouseButton:
		if not _hovered:
			return
		var match_event: Array = [
			_rolling,
			in_event.button_index,
			in_event.is_pressed(),
		]
		match match_event:
			#[rolling_already_started, what_button, is_pressed]
			[false, MOUSE_BUTTON_LEFT, true]:
				# LMB pressed when rolling is not ongoing
				_start_roll()
				queue_redraw()
			[true, MOUSE_BUTTON_LEFT, false]:
				# LMB released when rolling,
				_complete_roll()
				queue_redraw()
			[true, MOUSE_BUTTON_RIGHT, true]:
				# RMB pressed when rolling is ongoing
				_abort_roll()
				queue_redraw()


func _start_roll() -> void:
	_rolling = true
	var center: Vector2 = size / 2
	var mouse_pos: Vector2 = get_local_mouse_position()
	assert(not center.is_equal_approx(mouse_pos), "Should not be possible to start rolling when the mouse is placed in the center of the control")
	var mouse_dir: Vector2 = mouse_pos - center
	_start_roll_angle = Vector2.RIGHT.angle_to_point(mouse_dir)
	if _start_roll_angle < 0:
		_start_roll_angle += 2 * PI
	_current_roll_angle = _start_roll_angle
	_start_transform = _camera.global_transform


func _update_roll(in_mouse_local_position: Vector2) -> void:
	var center: Vector2 = size / 2
	if in_mouse_local_position.distance_squared_to(center) < 15*15:
		# Too close to the center, let's disable the roll
		_current_roll_angle = _start_roll_angle
	else:
		var mouse_dir: Vector2 = in_mouse_local_position - center
		_current_roll_angle = Vector2.RIGHT.angle_to_point(mouse_dir)
		if _current_roll_angle < 0:
			_current_roll_angle += 2 * PI
	var orbit_pivot_position: Vector3 = get_parent().get_orbit_pivot_position()
	var roll_axis: Vector3 = _start_transform.origin.direction_to(orbit_pivot_position)
	var roll_amount: float = _current_roll_angle - _start_roll_angle
	if Input.is_key_pressed(KEY_SHIFT):
		const SNAP_STEP = deg_to_rad(15)
		roll_amount = snappedf(roll_amount, SNAP_STEP)
	# We invert roll_amount here because is more intuitive,
	# the movement of the objects will reflect the movement of the mouse
	_camera.basis = _start_transform.basis.rotated(roll_axis, -roll_amount)


func _complete_roll() -> void:
	_rolling = false
	_hovered = false


func _abort_roll() -> void:
	_rolling = false
	_hovered = false
	_camera.global_transform = _start_transform


func _find_editor_viewport_camera_3d() -> Camera3D:
	var ancestor: Node = get_parent()
	while not ancestor is SubViewportContainer:
		ancestor = ancestor.get_parent()
	var viewport: WorkspaceEditorViewport = ancestor.get_child(0) as WorkspaceEditorViewport
	assert(viewport, "Invalid project hierarchy, could not find viewport!")
	return viewport.get_camera_3d()
