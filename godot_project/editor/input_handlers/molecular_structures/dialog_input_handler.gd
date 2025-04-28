extends InputHandlerBase


func get_priority() -> int:
	return BuiltinInputHandlerPriorities.DIALOG_INPUT_HANDLER


func handles_empty_selection() -> bool:
	return true


func handles_structure_context(_in_structure_context: StructureContext) -> bool:
	return true


func is_exclusive_input_consumer() -> bool:
	for child: Node in Editor_Utils.get_editor().get_children():
		if child is Window and child.visible:
			return true
	return false


func forward_input(_in_input_event: InputEvent, _in_camera: Camera3D, _in_context: StructureContext) -> bool:
	if is_exclusive_input_consumer():
		return true
	return false

