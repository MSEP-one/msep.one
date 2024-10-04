extends InputHandlerBase


func get_priority() -> int:
	return BuiltinInputHandlerPriorities.QUICK_SEARCH_MENU_HANDLER


func handles_empty_selection() -> bool:
	return true


func handles_structure_context(_in_structure_context: StructureContext) -> bool:
	return true


func is_exclusive_input_consumer() -> bool:
	return false


func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, _in_context: StructureContext) -> bool:
	if in_input_event.is_action_pressed(&"open_quick_search", false, true):
		WorkspaceUtils.open_quick_search_dialog(_in_context.workspace_context)
		return true
	return false
