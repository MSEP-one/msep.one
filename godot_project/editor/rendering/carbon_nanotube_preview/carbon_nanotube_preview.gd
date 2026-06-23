class_name CarbonNanotubePreview
extends Node

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _axis_preview: Control = $AxisPreview
@onready var _camera: Camera3D = get_viewport().get_camera_3d()

var _tube_start: Vector3
var _tube_end: Vector3
var _valid: bool = false
var _visible: bool = false


func _ready() -> void:
	_axis_preview.draw.connect(_on_axis_preview_draw)


func show() -> void:
	_visible = true
	if _valid:
		_mesh.show()
		_axis_preview.queue_redraw()


func hide() -> void:
	_visible = false
	_mesh.hide()
	_axis_preview.queue_redraw()


func is_visible() -> bool:
	return _visible


func is_visible_and_valid() -> bool:
	return _visible and _valid


func set_start_pos(in_start_pos: Vector3) -> void:
	_tube_start = in_start_pos
	_tube_end = in_start_pos
	_update()


func set_end_pos(in_end_pos: Vector3) -> void:
	_tube_end = in_end_pos
	_update()


func _update() -> void:
	const MIN_TUBE_LENGTH_SQRD = 0.4 * 0.4
	_valid = _tube_start.distance_squared_to(_tube_end) >= MIN_TUBE_LENGTH_SQRD
	# TODO: update mesh
	_axis_preview.queue_redraw()

func _on_axis_preview_draw() -> void:
	if not _visible:
		return
	var from: Vector2 = _camera.unproject_position(_tube_start)
	var to: Vector2 = _camera.unproject_position(_tube_end)
	var color: Color = Color.WHITE if _valid else Color.LIGHT_CORAL
	_axis_preview.draw_line(from, to, color, 4)
	_axis_preview.draw_circle(from, 8, color)
	_axis_preview.draw_circle(to, 8, color)
	var txt: String = tr(&"Too short")
	if _valid:
		var length: float = (_tube_end - _tube_start).length()
		txt = tr(&"Length %.3f nm") % length
	var mid_point: Vector2 = from + (to - from) / 2.0
	var font: Font = _axis_preview.get_theme_font("font")
	var font_size: int = _axis_preview.get_theme_font_size("font")
	var text_offset: Vector2 = font.get_string_size(txt)
	text_offset.x /= 2.0
	_axis_preview.draw_string_outline(
		font, mid_point - text_offset, txt, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size, 4, Color.BLACK)
	_axis_preview.draw_string(
		font, mid_point - text_offset, txt, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size)
