@tool
class_name SpinBoxSlider extends SpinBox

## A spinbox control with a slider control on top.


## value_confirmed is only triggered once when the user is done editing the value
## instead of every frame like the value_changed signal
signal value_confirmed(new_value: float)

@export var spinbox_visible: bool = true:
	set = set_spinbox_visible
@export var slider_visible: bool = true:
	set = set_slider_visible

var _is_dragging: bool = false
var _old_value: float = NAN

@onready var slider: HSlider = %Slider

#static func instantiate() -> void:
#	var scn = preload("res://editor/controls/general/spin_box_slider.tscn")
#	var instance = scn.instantiate()
#	return instance

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		slider = %Slider
		share(slider)


func _ready() -> void:
	slider.drag_started.connect(_on_slider_drag_started)
	slider.drag_ended.connect(_on_slider_drag_ended)
	value_changed.connect(_on_value_changed)


## Spinbox control doesn't have a drag_started / drag_ended signal, so this
## methods listen to the mouse inputs to detect these events.
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.button_index == MOUSE_BUTTON_LEFT:
		return
	
	if mouse_event.pressed:
		# Drag action started
		_is_dragging = true
		_old_value = value
		return
	
	if _is_dragging:
		_is_dragging = false
		if is_equal_approx(value, _old_value):
			# Current value is equal to the old one, meaning the user only clicked
			# on the line edit to type a value instead of dragging.
			return
		
		# Drag action ended
		value_confirmed.emit(value)
		get_line_edit().release_focus()


func _set(property: StringName, val: Variant) -> bool:
	if property == &"editable":
		editable = val
		if not is_instance_valid(slider):
			slider = %Slider
		slider.editable = val
		return true
	
	return false


func _on_slider_drag_started() -> void:
	_is_dragging = true


func _on_slider_drag_ended(in_value_changed: bool) -> void:
	_is_dragging = false
	if in_value_changed:
		value_confirmed.emit(value)


# Called any time the slider or spinbox value changes, including when dragging
# the slider,
func _on_value_changed(in_value: float) -> void:
	if _is_dragging:
		return
	value_confirmed.emit(in_value)


func set_slider_visible(in_visible: bool) -> void:
	slider_visible = in_visible
	slider.visible = in_visible


func set_spinbox_visible(in_visible: bool) -> void:
	spinbox_visible = in_visible
	if in_visible:
		self_modulate.a = 1.0
		get_child(0, true).show()
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		# To maintain slider visible and spinbox invisible we play with some properties
		self_modulate.a = 0.0
		get_child(0, true).hide()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

