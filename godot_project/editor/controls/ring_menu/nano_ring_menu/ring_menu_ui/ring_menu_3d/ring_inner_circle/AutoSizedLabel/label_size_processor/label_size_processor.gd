class_name LabelSizeProcessor extends Node
# # # #
# Responsible for calculating new font size for a label to ensure it fits in given width
# It also adds new line character between the words to avoid unnecessary font shrinkage


const FONT_RESIZE_STEP: int = 1


@export var target_label: Label = null
@export var max_width: int = 100
@export var max_height: int = 100

var _default_font_size: int


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		pass
	if what == NOTIFICATION_READY:
		assert(is_instance_valid(target_label), "target_label needs to be defined")
		_default_font_size = target_label.label_settings.font_size


func calculate_size_for_text(in_text: String) -> int:
	return _determine_font_size(in_text, _default_font_size)


func _determine_font_size(in_text: String, in_font_size: int) -> int:
	var out_size: int = in_font_size
	var too_wide: bool = _get_text_size(in_text, out_size).x > max_width
	while too_wide:
		out_size -= FONT_RESIZE_STEP
		too_wide = _get_text_size(in_text, out_size).x > max_width
	
	var is_too_high: bool = _get_text_size(in_text, out_size).y > max_height
	while is_too_high:
		out_size -= FONT_RESIZE_STEP
		is_too_high = _get_text_size(in_text, out_size).y > max_height
	
	return out_size


func _get_text_size(in_text: String, in_size: int) -> Vector2:
	return target_label.label_settings.font.get_multiline_string_size(in_text, HORIZONTAL_ALIGNMENT_CENTER,
			max_width, in_size, -1, TextServer.LineBreakFlag.BREAK_WORD_BOUND)
