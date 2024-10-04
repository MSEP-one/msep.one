extends Node

# Defines global behaviors for control nodes across the entire project


const SELECT_ALL_ON_FOCUS: bool = true
const UNFOCUS_ON_SUBMIT: bool = true


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is LineEdit or node is SpinBox:
		node.select_all_on_focus = SELECT_ALL_ON_FOCUS
	if node is LineEdit:
		node.text_submitted.connect(_on_line_edit_text_submitted.bind(node), CONNECT_DEFERRED)

func _on_line_edit_text_submitted(_new_text: String, in_line_edit: LineEdit) -> void:
	# unfocus the line edit
	if UNFOCUS_ON_SUBMIT and is_instance_valid(in_line_edit) and in_line_edit.has_focus():
		in_line_edit.release_focus()
