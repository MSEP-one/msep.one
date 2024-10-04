extends Object
class_name Editor_Utils

static func get_editor() -> MolecularEditor:
	return Engine.get_main_loop().get_first_node_in_group(&"__MSEP_EDITOR__")


static func process_quit_request(in_event: InputEvent, in_called_from_node: Node) -> bool:
	if in_event.is_action_pressed(&"quit", false, true):
		in_called_from_node.get_viewport().set_input_as_handled()
		var focused_window: Window = in_called_from_node.get_last_exclusive_window()
		while focused_window != Engine.get_main_loop().root:
			if not focused_window.visible:
				focused_window = focused_window.get_parent().get_last_exclusive_window()
				continue
			focused_window.hide()
		Editor_Utils.get_editor().notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		return true
	return false


static func get_structure_thumbnail(_in_nano_structure: NanoStructure) -> Texture2D:
	# TODO: generate or load thumbnail
	return preload("uid://dsnljh3opu7ae")
