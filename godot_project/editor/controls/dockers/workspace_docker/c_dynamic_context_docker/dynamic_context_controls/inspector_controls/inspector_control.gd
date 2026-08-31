class_name InspectorControl extends MarginContainer

signal about_to_submit_value

func is_editable() -> bool:
	assert(false, "function needs to be implemented")
	return false

func notify_about_to_submit_value() -> void:
	about_to_submit_value.emit()
