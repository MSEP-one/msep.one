extends TextureRect

const OVERLAY_COLOR: Color = Color(1.0, 1.0, 1.0, .25)

signal crop_rect_changed(new_rect: Rect2)


var crop_width: float:
	set = _set_crop_width
var crop_height: float:
	set = _set_crop_height
var crop_enabled: bool = false:
	set = _set_crop_enabled
var crop_h_offset: float = .0:
	set = _set_crop_h_offset
var crop_v_offset: float = .0:
	set = _set_crop_v_offset


var _start_position: Vector2 = Vector2.ZERO
var _end_position: Vector2 = Vector2.ZERO
var _is_dragging: bool = false


func _set_crop_width(in_new_width: float) -> void:
	crop_width = in_new_width
	queue_redraw()


func _set_crop_height(in_new_height: float) -> void:
	crop_height = in_new_height
	queue_redraw()


func _set_crop_enabled(in_new_value: bool) -> void:
	crop_enabled = in_new_value
	queue_redraw()


func _set_crop_h_offset(in_new_offset: float) -> void:
	crop_h_offset = in_new_offset
	queue_redraw()


func _set_crop_v_offset(in_new_offset: float) -> void:
	crop_v_offset = in_new_offset
	queue_redraw()


func _gui_input(in_event: InputEvent) -> void:
	if not crop_enabled:
		return
	if in_event is InputEventMouseButton and \
		in_event.button_index == MOUSE_BUTTON_LEFT:
		if in_event.pressed:
			_is_dragging = true
			_start_position = _get_texture_coordinates(in_event.position)
			_end_position = _start_position
			_update_crop_rect()
		else:
			_is_dragging = false
	
	if in_event is InputEventMouseMotion and _is_dragging:
		_end_position = _get_texture_coordinates(in_event.position)
		_update_crop_rect()


func _draw() -> void:
	if !crop_enabled:
		return
	var crop_rect_position: Vector2 = _get_control_coordinates(
		Vector2(crop_h_offset, crop_v_offset))
	var crop_rect_end: Vector2 = _get_control_coordinates(
		Vector2(crop_width + crop_h_offset, crop_v_offset + crop_height))
	var crop_rect_size: Vector2 = crop_rect_end - crop_rect_position
	
	var texture_begin_position: Vector2 = _get_control_coordinates(Vector2.ZERO)
	var texture_end_position: Vector2 = _get_control_coordinates(texture.get_size())
	var crop_begin_position: Vector2 = crop_rect_position
	var crop_end_position: Vector2 = crop_rect_end
	# Draw dark overlays outside crop region
	var dark_overlay_top: Rect2 = Rect2(texture_begin_position, Vector2.ZERO)\
		.expand(Vector2(texture_end_position.x, crop_begin_position.y))
	draw_rect(dark_overlay_top, OVERLAY_COLOR)
	var overlay_left: Rect2 = Rect2(texture_begin_position.x, crop_begin_position.y,
		crop_begin_position.x - texture_begin_position.x, crop_rect_size.y)
	draw_rect(overlay_left, OVERLAY_COLOR)
	var overlay_right: Rect2 = Rect2(crop_end_position.x, crop_begin_position.y,
		texture_end_position.x - crop_end_position.x, crop_rect_size.y)
	draw_rect(overlay_right, OVERLAY_COLOR)
	var overlay_bottom: Rect2 = Rect2(texture_begin_position.x, crop_end_position.y,
		texture_end_position.x - texture_begin_position.x, texture_end_position.y - crop_end_position.y)
	draw_rect(overlay_bottom, OVERLAY_COLOR)
	# Draw crop selection rectangle
	draw_rect(Rect2(crop_rect_position, crop_rect_size), \
		Color.AQUAMARINE, false, 2.0)

func _get_texture_coordinates(in_mouse_position: Vector2) -> Vector2:
	var texture_size: Vector2 = texture.get_size()
	
	if stretch_mode == STRETCH_SCALE:
		in_mouse_position.x = clamp(in_mouse_position.x, 0.0, texture_size.x)
		in_mouse_position.y = clamp(in_mouse_position.y, 0.0, texture_size.y)
		return in_mouse_position
	
	var control_size: Vector2 = get_rect().size
	var scale_ratio: Vector2 = texture_size / control_size
	var aspect_ratio: float = max(scale_ratio.x, scale_ratio.y)
	var scaled_texture_size: Vector2 = texture_size / aspect_ratio
	var offset: Vector2 = (control_size - scaled_texture_size) * 0.5
	var texture_coordinates: Vector2 = (in_mouse_position - offset) * aspect_ratio
	texture_coordinates.x = clamp(texture_coordinates.x, 0, texture_size.x)
	texture_coordinates.y = clamp(texture_coordinates.y, 0, texture_size.y)
	return texture_coordinates


func _get_control_coordinates(in_pixel_position: Vector2) -> Vector2:
	if stretch_mode == STRETCH_SCALE:
		return in_pixel_position
	
	var texture_size: Vector2 = texture.get_size()
	var control_size: Vector2 = get_rect().size
	var scale_ratio: Vector2 = control_size / texture_size
	var aspect_ratio: float = min(scale_ratio.x, scale_ratio.y)
	var scaled_texture_size: Vector2 = texture_size * aspect_ratio
	var offset: Vector2 = (control_size - scaled_texture_size) * 0.5
	var control_coordinates: Vector2 = in_pixel_position * aspect_ratio + offset
	return control_coordinates


func _update_crop_rect() -> void:
	var crop_rect: Rect2 = Rect2()
	crop_rect.position = _start_position
	crop_rect = crop_rect.expand(_end_position).abs()
	crop_rect_changed.emit(crop_rect)
	queue_redraw()
