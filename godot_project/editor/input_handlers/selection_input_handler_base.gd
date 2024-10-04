class_name SelectionInputHandlerBase extends InputHandlerBase


func _user_is_selecting_on_mac_pressed(in_input_event: InputEvent, in_allow_echo: bool = false, in_exact_match: bool = false) -> bool:
	return OS.get_name() == &"macOS" and \
		in_input_event.is_action_pressed(&"select_mac", in_allow_echo, in_exact_match)


func _user_is_selecting_on_mac_released(in_input_event: InputEvent, in_exact_match: bool = false) -> bool:
	return OS.get_name() == &"macOS" and \
		in_input_event.is_action_released(&"select_mac", in_exact_match)


func _user_is_unselecting_on_mac_pressed(in_input_event: InputEvent, in_allow_echo: bool = false, in_exact_match: bool = false) -> bool:
	return OS.get_name() == &"macOS" and \
		in_input_event.is_action_pressed(&"unselect_mac", in_allow_echo, in_exact_match)


func _user_is_unselecting_on_mac_released(in_input_event: InputEvent, in_exact_match: bool = false) -> bool:
	return OS.get_name() == &"macOS" and \
		in_input_event.is_action_released(&"unselect_mac", in_exact_match)


func get_priority() -> int:
	return BuiltinInputHandlerPriorities.DEFAULT_INPUT_PRIORITY


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
