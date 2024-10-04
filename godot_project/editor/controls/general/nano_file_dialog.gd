class_name NanoFileDialog extends FileDialog

var _block_next_input: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# 1. Update when application regains focus
		if visible:
			invalidate()
	elif what == NOTIFICATION_READY:
		# 2. Select file when text changes
		var line_edit: LineEdit = _get_file_dialog_line_edit()
		if not line_edit.text_changed.is_connected(_on_file_dialog_line_edit_text_changed):
			line_edit.gui_input.connect(_on_file_dialog_line_edit_gui_input.bind(line_edit))
			line_edit.text_changed.connect(_on_file_dialog_line_edit_text_changed.bind(line_edit))
		window_input.connect(_on_window_input)



func _on_file_dialog_line_edit_gui_input(in_event: InputEvent, in_line_edit: LineEdit) -> void:
	_block_next_input = false
	if in_event is InputEventKey and in_event.is_pressed() and in_event:
		var key_event := in_event as InputEventKey
		# HACK prevent _on_file_dialog_line_edit_text_changed from being executed
		# This allows to erase text without the code in that function rewriting it
		if key_event.keycode == KEY_DELETE:
			_block_next_input = true
		elif key_event.keycode == KEY_BACKSPACE and in_line_edit.text.length() <= 1:
			in_line_edit.clear()
			in_line_edit.get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_BACKSPACE and in_line_edit.has_selection():
			# Delete an extra character and autocomplete, this will efectively select one extra char
			var delete_from: int = max(0, in_line_edit.get_selection_from_column() - 1)
			var delete_to: int = max(0, in_line_edit.get_selection_to_column())
			in_line_edit.delete_text(delete_from, delete_to)
			in_line_edit.get_viewport().set_input_as_handled()

func _on_file_dialog_line_edit_text_changed(new_text: String, in_line_edit: LineEdit) -> void:
	if _block_next_input:
		return
	var file_tree: Tree = _get_file_dialog_tree()
	if new_text.is_empty():
		file_tree.deselect_all()
		in_line_edit.set_block_signals(true)
		in_line_edit.text = ""
		in_line_edit.set_block_signals(false)
		return
	var root: TreeItem = file_tree.get_root()
	# backup line_edit state
	var old_caret: int = in_line_edit.caret_column
	var sorted_tree_items: Array[TreeItem] = root.get_children()
	sorted_tree_items.sort_custom(_sort_tree_items_alphabetically)
	
	for tree_item in sorted_tree_items:
		var item_text: String = tree_item.get_text(0)
		if item_text.to_lower().begins_with(new_text.to_lower()):
			# Selecting file from list automatically changes text in line edit,
			# prevent text_changed signal from executing recursively
			in_line_edit.set_block_signals(true)
			file_tree.set_selected(tree_item, 0)
			file_tree.scroll_to_item(tree_item, true)
			# Revert caret position to it's original state, but also select what is added after it
			# this way the user can continue typing to find another candidate
			in_line_edit.set_deferred(&"text", item_text)
			in_line_edit.set_deferred(&"caret_column", old_caret)
			in_line_edit.select.call_deferred(old_caret, len(item_text))
			in_line_edit.set_block_signals.call_deferred(false)
			return


func _sort_tree_items_alphabetically(in_item_a: TreeItem, in_item_b: TreeItem) -> bool:
	return in_item_a.get_text(0).to_lower() < in_item_b.get_text(0).to_lower()


func _get_file_dialog_line_edit() -> LineEdit:
	var body_container: VBoxContainer = get_child(3, true) as VBoxContainer
	assert(is_instance_valid(body_container), "Invalid child of FileDialog, Did engine version change from 4.1.1?")
	var footer_container: HBoxContainer = body_container.get_child(3, true) as HBoxContainer
	assert(is_instance_valid(footer_container), "Invalid child of body_container, Did engine version change from 4.1.1?")
	var line_edit: LineEdit = footer_container.get_child(1, true) as LineEdit
	assert(is_instance_valid(line_edit), "Invalid child of footer_container, Did engine version change from 4.1.1?")
	return line_edit


func _get_file_dialog_tree() -> Tree:
	var body_container: VBoxContainer = get_child(3, true) as VBoxContainer
	assert(is_instance_valid(body_container), "Invalid child of FileDialog, Did engine version change from 4.1.1?")
	var margin_container: MarginContainer = body_container.get_child(2, true) as MarginContainer
	assert(is_instance_valid(margin_container), "Invalid child of body_container, Did engine version change from 4.1.1?")
	var tree: Tree = margin_container.get_child(0, true) as Tree
	assert(is_instance_valid(tree), "Invalid child of margin_container, Did engine version change from 4.1.1?")
	return tree


func _on_window_input(in_event: InputEvent) -> void:
	if Editor_Utils.process_quit_request(in_event, self):
		return
	if in_event.is_action_pressed(&"close_view", false, true):
		hide()
