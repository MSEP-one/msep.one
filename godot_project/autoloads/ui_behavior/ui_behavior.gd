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
		if node.text_submitted.is_connected(_on_line_edit_text_submitted):
			return
		node.text_submitted.connect(_on_line_edit_text_submitted.bind(node), CONNECT_DEFERRED)
	if node is AcceptDialog:
		var child_count: int = node.get_child_count(true)
		var buttons_container: HBoxContainer
		for i in range(child_count-1, -1, -1):
			if node.get_child(i, true) is HBoxContainer:
				buttons_container = node.get_child(i, true)
				break
		for child in buttons_container.get_children(true):
			if child is Button:
				child.theme_type_variation = &"CrystalButton"

func _on_line_edit_text_submitted(_new_text: String, in_line_edit: LineEdit) -> void:
	# unfocus the line edit
	if UNFOCUS_ON_SUBMIT and is_instance_valid(in_line_edit) and in_line_edit.has_focus():
		in_line_edit.release_focus()
