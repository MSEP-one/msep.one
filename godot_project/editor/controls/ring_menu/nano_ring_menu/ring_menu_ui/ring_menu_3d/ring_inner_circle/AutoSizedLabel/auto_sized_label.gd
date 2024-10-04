extends Label
# # # # # #
# Label which ensures it's never wider then given 'max_width' value
# It will try to assign it's words into new lines before performing any font shrinkage
# In order for it to do it's work the text should be set with 'apply_autosized_text'


@export var max_width: int = 175: set = set_max_width
@export var max_height: int = 175: set = set_max_height


var _label_size_processor: LabelSizeProcessor = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_label_size_processor = $LabelSizeProcessor


func set_max_width(new_max_width: int) -> void:
	max_width = new_max_width
	_label_size_processor.max_width = max_width


func set_max_height(new_max_height: int) -> void:
	max_height = new_max_height
	_label_size_processor.max_height = max_height


func _set(in_property: StringName, in_value: Variant) -> bool:
	if in_property == &"text":
		apply_autosized_text(in_value)
		return true
	return false


func apply_autosized_text(new_text: String) -> void:
	label_settings.font_size = _label_size_processor.calculate_size_for_text(new_text)
	text = new_text
