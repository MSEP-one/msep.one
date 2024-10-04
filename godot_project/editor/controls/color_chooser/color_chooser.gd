@tool
class_name ColorChooser extends MarginContainer
# Simple control containing a pair of a [title] + [color picker]


signal color_picked(color: Color)


@export var title: String = "" : set = _set_title

var _title_label: Label
var _color_picker_btn: ColorPickerButton


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_title_label = $HBoxContainer/Title
		_color_picker_btn = $HBoxContainer/ColorPickerButton
	if what == NOTIFICATION_READY:
		_set_title(title)


func _set_title(new_title: String) -> void:
	title = new_title
	if is_inside_tree():
		_title_label.text = new_title


func set_color(new_color: Color) -> void:
	_color_picker_btn.color = new_color


func get_color() -> Color:
	return _color_picker_btn.color


func _on_color_picker_button_color_changed(in_color: Color) -> void:
	color_picked.emit(in_color)
