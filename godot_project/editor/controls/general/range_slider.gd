class_name RangeSlider
extends Control

## Regular slider with two extra controls to limit the valid values.
## min_value and max_value works as usual and limit the absolute slider values.
## range_start and range_end is a smaller interval within the absolute range,
## and value is always between these two. 


const COLOR_DEFAULT: Color = Color.GHOST_WHITE
const COLOR_HOVER: Color = Color.YELLOW
const COLOR_PRESSED: Color = Color("BB9AFFFF")


signal value_changed(value: float)


@export var min_value: float = 0.0: set = set_min_value
@export var max_value: float = 1.0: set = set_max_value
@export var value: float = 0.0: set = set_value
@export var step: float = 0.001: set = set_step
@export var range_start: float = 0.0: set = set_range_start
@export var range_end: float = 1.0: set = set_range_end

var _is_dragging_start: bool = false
var _is_dragging_end: bool = false
var _click_offset_x: float

@onready var _slider_container: HBoxContainer = %SliderContainer
@onready var _slider: HSlider = %HSlider
@onready var _marker_start: VSeparator = %MarkerStart
@onready var _marker_end: VSeparator = %MarkerEnd
@onready var _grabber_start: PanelContainer = %GrabberStart
@onready var _grabber_end: PanelContainer = %GrabberEnd
@onready var _spacer_start: TextureRect = %SpacerStart
@onready var _spacer_end: TextureRect = %SpacerEnd


func _ready() -> void:
	_slider.value_changed.connect(_on_slider_value_changed)
	resized.connect(refresh_ui, CONNECT_DEFERRED)
	refresh_ui()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if not mouse_event.pressed:
				# Mouse released
				_is_dragging_start = false
				_is_dragging_end = false
			else:
				# Check if the user clicked a grabber.
				# The click offset is to avoid a visual jump when moving the mouse.
				var mouse_position: Vector2 = mouse_event.global_position
				if _grabber_start.get_global_rect().has_point(mouse_position):
					_is_dragging_start = true
					_click_offset_x = mouse_position.x - _marker_start.global_position.x 
				elif _grabber_end.get_global_rect().has_point(mouse_position):
					_is_dragging_end = true
					_click_offset_x = mouse_position.x - _marker_end.global_position.x
			_update_grabbers_color(event.global_position)
		return
	
	if event is InputEventMouseMotion:
		_update_grabbers_color(event.global_position)
		if not _is_dragging_start and not _is_dragging_end:
			return
		# Logic for moving a grabber.
		var motion_event: InputEventMouseMotion = event
		var min_grab_position: float = 0.0
		var max_grab_position: float = _slider_container.size.x
		var drag_position: float = motion_event.position.x - _click_offset_x
		drag_position -= _grabber_start.size.x # Make it relative to the SliderContainer position
		var final_value: float = remap(drag_position, min_grab_position, max_grab_position, min_value, max_value)
		if _is_dragging_start:
			range_start = final_value
		elif _is_dragging_end:
			range_end = final_value


func share(with: Node) -> void:
	_slider.share(with)


func refresh_ui() -> void:
	_slider.min_value = min_value
	_slider.max_value = max_value
	_slider.value = value
	set_range_start(range_start)
	set_range_end(range_end)


func get_value() -> float:
	if _slider:
		return _slider.get_value()
	return value


func set_value(val: float) -> void:
	value = clamp(snapped(val, step), range_start, range_end)
	if _slider and _slider.value != value:
		_slider.value = value


func set_step(val: float) -> void:
	step = val
	if _slider:
		_slider.step = step


func set_min_value(val: float) -> void:
	min_value = val
	if min_value > range_start:
		range_start = min_value
	if _slider:
		_slider.min_value = val


func set_max_value(val: float) -> void:
	max_value = val
	if max_value < range_end:
		range_end = max_value
	if _slider:
		_slider.max_value = val


func set_range_start(val: float) -> void:
	range_start = clamp(val, min_value, range_end)
	if value < range_start:
		value = range_start
	if not _slider or not _marker_start:
		return
	_slider.min_value = range_start
	_slider.value = value
	_marker_start.position.x = remap(range_start, min_value, max_value, 0.0, _slider_container.size.x)
	_update_slider_width()


func set_range_end(val: float) -> void:
	range_end = clamp(val, range_start, max_value)
	if value > range_end:
		value = range_end
	if not _slider or not _marker_end:
		return
	_slider.max_value = range_end
	_marker_end.position.x = remap(range_end, min_value, max_value, 0.0, _slider_container.size.x)
	_update_slider_width()


func _update_slider_width() -> void:
	_spacer_start.size_flags_stretch_ratio = range_start - min_value
	_slider.size_flags_stretch_ratio = range_end - range_start
	_slider.visible = _slider.size_flags_stretch_ratio > 0
	_spacer_end.size_flags_stretch_ratio = max_value - range_end
	# Shrinking the range completely resets the slider step value and needs to be reapplied.
	_slider.step = step


func _update_grabbers_color(mouse_global_position: Vector2) -> void:
	if _is_dragging_start:
		_marker_start.modulate = COLOR_PRESSED
		return
	if _is_dragging_end:
		_marker_end.modulate = COLOR_PRESSED
		return
	for marker: Control in [_marker_start, _marker_end]:
		var grabber: Control = marker.get_child(0)
		if grabber.get_global_rect().has_point(mouse_global_position):
			marker.modulate = COLOR_HOVER
		else:
			marker.modulate = COLOR_DEFAULT


func _on_slider_value_changed(val: float) -> void:
	value = val
	value_changed.emit(value)
