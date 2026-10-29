@tool
class_name ElementPickerButton extends Button


@export var element: int:
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
	_element_preview.disabled = true


func enable() -> void:
	disabled = false
	_element_preview.disabled = false


func highlight() -> void:
	_highlight.visible = true


func lowlight() -> void:
	_highlight.visible = false


func can_render() -> bool:
	var data: ElementData = PeriodicTable.get_by_atomic_number(element)
	return data.is_contact_radius_known or data.is_render_radius_known
