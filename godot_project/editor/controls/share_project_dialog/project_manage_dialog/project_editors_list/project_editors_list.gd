class_name ProjectEditorsList extends VBoxContainer
## Presents the editors of an online project and lets the user add or remove editors.


var _loaded: bool = false
var _original_editors: Dictionary[String, bool] = {
	# editor_username<String>: true
	# (...)
}
var _editor_labels: Dictionary[String, TagLabel] = {
	# editor_username<String>: TagLabel
	# (...)
}

@onready var _editors_list_container: HFlowContainer = %EditorsListContainer
@onready var _new_editor_line_edit: LineEdit = %NewEditorLineEdit


func clear() -> void:
	_loaded = false
	hide()
	_new_editor_line_edit.text = ""
	_original_editors.clear()
	for editor_label: TagLabel in _editor_labels.values():
		editor_label.queue_free()
	_editor_labels.clear()


func show_editors(in_usernames: PackedStringArray) -> void:
	for username: String in in_usernames:
		_original_editors[username] = true
		_add_editor_label(username)
	_loaded = true
	show()


func is_loaded() -> bool:
	return _loaded


func get_added_usernames() -> PackedStringArray:
	var added: PackedStringArray = []
	for username: String in _editor_labels.keys():
		var is_added: bool = not _original_editors.has(username)
		if is_added:
			added.append(username)
	return added


func get_removed_usernames() -> PackedStringArray:
	var removed: PackedStringArray = []
	for username: String in _original_editors.keys():
		var is_removed: bool = not _editor_labels.has(username)
		if is_removed:
			removed.append(username)
	return removed


func mark_added(in_username: String) -> void:
	_original_editors[in_username] = true


func mark_removed(in_username: String) -> void:
	_original_editors.erase(in_username)


func _add_editor_label(in_username: String) -> void:
	var editor_label: TagLabel = TagLabel.create_tag(in_username)
	editor_label.erase_requested.connect(_on_editor_label_erase_requested.bind(in_username))
	_editors_list_container.add_child(editor_label)
	_editor_labels[in_username] = editor_label


func _on_editor_label_erase_requested(in_username: String) -> void:
	_editor_labels[in_username].queue_free()
	_editor_labels.erase(in_username)


func _on_add_editor_button_pressed() -> void:
	_add_new_editor()


func _add_new_editor() -> void:
	var username: String = _new_editor_line_edit.text.strip_edges()
	_new_editor_line_edit.text = ""
	var is_new_editor: bool = not username.is_empty() and not _editor_labels.has(username)
	if is_new_editor:
		_add_editor_label(username)


func _on_new_editor_line_edit_text_submitted(_in_text: String) -> void:
	_add_new_editor()
