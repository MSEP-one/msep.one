@tool
class_name InspectorControlDirection extends InspectorControl

enum Mode {
	QUATERNION,
	NORMAL,
}

@export var editable: bool = true:
	get = is_editable, set = set_is_editable
@export var mode: Mode = Mode.QUATERNION

var _preview: Control
var _altitude_spin_box: SpinBoxSlider
var _azimuth_spin_box: SpinBoxSlider


var _property_changed_signal := Signal()
var _getter := Callable()
var _setter := Callable()


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_preview = %Preview as Control
		_altitude_spin_box = %AltitudeSpinBox as SpinBoxSlider
		_azimuth_spin_box = %AzimuthSpinBox as SpinBoxSlider
		_preview.draw.connect(_preview_draw)
		_altitude_spin_box.value_changed.connect(_on_spin_box_value_changed)
		_azimuth_spin_box.value_changed.connect(_on_spin_box_value_changed)
	elif in_what == NOTIFICATION_READY:
		if not Engine.is_editor_hint():
			assert(_getter != Callable(), "Needs to be initalized with setup() before adding to a tree")
			pass


func setup(in_getter: Callable, in_setter: Callable = Callable(), in_property_changed_signal: Signal = Signal()) -> void:
	assert(in_getter.is_valid())
	if not _property_changed_signal.is_null():
		# disconnect previous signal
		in_property_changed_signal.disconnect(_on_changed_signal_emitted)
	_property_changed_signal = in_property_changed_signal
	_getter = in_getter
	_setter = in_setter
	if !in_property_changed_signal.is_null():
		in_property_changed_signal.connect(_on_changed_signal_emitted)
	_on_changed_signal_emitted()


func is_editable() -> bool:
	return editable


func set_is_editable(in_editable: bool) -> void:
	editable = in_editable
	_azimuth_spin_box.editable = in_editable
	_altitude_spin_box.editable = in_editable


func _preview_draw() -> void:
	var smaller_size: float = min(_preview.size.x, _preview.size.y)
	var preview_size: Vector2 = Vector2(smaller_size, smaller_size)
	var drawn_rect: Rect2 = Rect2(
			(_preview.size.x - preview_size.x) * 0.5,
			(_preview.size.y - preview_size.y) * 0.5,
			preview_size.x,
			preview_size.y,
	)
	const POINT_COUNT: int = 60
	const ORIGIN: Vector2 = Vector2()
	_preview.draw_set_transform(drawn_rect.get_center(), 0.0, Vector2(1.0, 1.0))
	# globe
	_preview.draw_arc(ORIGIN, smaller_size * 0.5, 0.0, 2.0 * PI, POINT_COUNT, Color.WHITE, 2.0, true)
	# X and Y indicators
	_preview.draw_line(ORIGIN, Vector2.RIGHT * smaller_size * 0.3, Color.RED)
	_preview.draw_line(ORIGIN, Vector2.UP * smaller_size * 0.3, Color.GREEN)
	_preview.draw_set_transform(drawn_rect.get_center(), 0.0, Vector2(1.0, 0.3))
	# Horizon line around the globe
	_preview.draw_arc(ORIGIN, smaller_size * 0.5, 0.0, 2.0 * PI, POINT_COUNT, Color.WHITE, 2.0, true)
	# Z indicator
	_preview.draw_line(ORIGIN, Vector2.DOWN * smaller_size * 0.3, Color.BLUE)
	#line from center pointing to azimuth direction
	var azimuth_point: Vector2 = (Vector2.UP * smaller_size * 0.5).rotated(deg_to_rad(_azimuth_spin_box.value))
	_preview.draw_dashed_line(ORIGIN, azimuth_point, Color.WHITE, -1, 4.0, true)
	# arc cutting the globe at azimuth
	var azimuth_dir: Vector2 = Vector2.UP.slerp(Vector2.DOWN, _azimuth_spin_box.value / 180.0)
	_preview.draw_set_transform(drawn_rect.get_center(), 0.0, Vector2(azimuth_dir.x, 1.0))
	_preview.draw_arc(ORIGIN, smaller_size * 0.5, -PI * 0.5, PI * 0.5, int(POINT_COUNT * 0.5), Color.WHITE)
	# line indicating altitude
	var altitude_point: Vector2 = (azimuth_point * Vector2(1.0, 0.3)).normalized()
	if _altitude_spin_box.value > 0:
		altitude_point = altitude_point.slerp(Vector2.UP, _altitude_spin_box.value / 90.0)
	elif _altitude_spin_box.value < 0:
		altitude_point = altitude_point.slerp(Vector2.DOWN, abs(_altitude_spin_box.value) / 90.0)
	altitude_point = altitude_point * smaller_size * 0.5
	var altitude_dir: Vector2 = altitude_point.normalized()
	_preview.draw_line(ORIGIN, altitude_point, Color.WHITE, 0.33, true)
	var arrow_points: PackedVector2Array = [
		altitude_point + Vector2(altitude_dir.y, -altitude_dir.x * 5.0),
		altitude_point + Vector2(-altitude_dir.y, altitude_dir.x * 5.0),
		altitude_point,
	]
	var arrow_colors: PackedColorArray = [Color.WHITE, Color.WHITE, Color.WHITE]
	_preview.draw_polygon(arrow_points, arrow_colors)


func _on_spin_box_value_changed(_in_value: float) -> void:
	_preview.queue_redraw()
	if _setter != Callable():
		match mode:
			Mode.QUATERNION:
				var azimuth_quat := Quaternion(Vector3.UP, deg_to_rad(_azimuth_spin_box.value))
				var altitud_quat := Quaternion(Vector3.FORWARD, deg_to_rad(_altitude_spin_box.value))
				_setter.call(altitud_quat * azimuth_quat)
			Mode.NORMAL:
				var azimuth_dir := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(_azimuth_spin_box.value))
				var normal := azimuth_dir.rotated(azimuth_dir.cross(Vector3.UP), deg_to_rad(_altitude_spin_box.value))
				_setter.call(normal)


func _on_changed_signal_emitted(_ignored_1: Variant = null, _ignored_2: Variant = null, _ignored_3: Variant = null) -> void:
	var direction := Vector3.FORWARD
	match mode:
		Mode.QUATERNION:
			var quaternion: Quaternion = _getter.call() as Quaternion
			direction = quaternion * Vector3.FORWARD
		Mode.NORMAL:
			direction = _getter.call() as Vector3
		_:
			assert(false, "Unknown mode: %d" % mode)
			return
	var direction_in_horizon_plane: Vector3 = direction
	direction_in_horizon_plane.y = 0
	direction_in_horizon_plane = direction_in_horizon_plane.normalized()
	var altitude: float = direction.signed_angle_to(direction_in_horizon_plane, Vector3.UP)
	var azimuth: float = direction_in_horizon_plane.signed_angle_to(Vector3.FORWARD, Vector3.RIGHT)
	_azimuth_spin_box.set_value_no_signal(rad_to_deg(azimuth))
	_altitude_spin_box.set_value_no_signal(rad_to_deg(altitude))
