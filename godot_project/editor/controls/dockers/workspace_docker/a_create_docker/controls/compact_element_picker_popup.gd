class_name CompactElementPickerPopup extends PopupPanel

var _element_picker: CompactElementPicker


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_element_picker = $ElementPicker as CompactElementPicker
		_element_picker.extended_element_picker_shown.connect(_on_element_picker_extended_element_picker_shown)


func popup_attached_to_control(in_control: Control) -> void:
	var screen_size: Vector2 = in_control.get_window().size
	var popup_separation: int = 4
	var button_rect: Rect2 = in_control.get_global_rect().grow(popup_separation)
	var desired_position: Vector2 = button_rect.end - Vector2(button_rect.size.x, 0)
	if desired_position.x + size.x > screen_size.x:
		desired_position.x -= (size.x - button_rect.size.x)
	if desired_position.y + size.y > screen_size.y:
		desired_position.y -= button_rect.size.y + size.y
	position = desired_position
	popup()


func get_element_picker() -> CompactElementPicker:
	return _element_picker


func _on_element_picker_extended_element_picker_shown() -> void:
	hide()
