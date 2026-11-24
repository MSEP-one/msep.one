class_name AvatarPicker extends HBoxContainer


signal avatar_selected(path: String)


@onready var _path_label: Label = %PathLabel
@onready var _file_dialog: FileDialog = %FileDialog


func reset() -> void:
	_path_label.text = tr("No new avatar selected")


func _on_choose_button_pressed() -> void:
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_dialog_file_selected(in_path: String) -> void:
	_path_label.text = in_path.get_file()
	avatar_selected.emit(in_path)
