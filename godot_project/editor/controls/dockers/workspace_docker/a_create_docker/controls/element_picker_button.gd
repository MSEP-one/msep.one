@tool
class_name ElementPickerButton extends Button

const COLOR_DISABLE: Color = Color(0.4,0.4,0.4, 1.0)
const COLOR_ENABLE: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var element: int = 1:
	set(v):
		element = v
		if !is_instance_valid(_element_preview):
			await ready
		_element_preview.set_element_number(element)
		if can_render():
			enable()
		else:
			disable()

@onready var _element_preview: AspectRatioContainer = %ElementPreview
@onready var _highlight: Control = %Highlight


func disable() -> void:
	disabled = true
	modulate = COLOR_DISABLE


func enable() -> void:
	disabled = false
	modulate = COLOR_ENABLE


func highlight() -> void:
	_highlight.visible = true


func lowlight() -> void:
	_highlight.visible = false


func can_render() -> bool:
	var data: ElementData = PeriodicTable.get_by_atomic_number(element)
	return data.is_contact_radius_known or data.is_render_radius_known
