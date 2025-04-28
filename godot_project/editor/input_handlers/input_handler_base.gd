extends RefCounted
## Abstract class for handling mouse and keys events on the editor viewport
class_name InputHandlerBase


# region virtual

## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return false


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(_in_structure_context: StructureContext) -> bool:
	return false


## VIRTUAL: When [code]handles_empty_selection()[/code] or [code]
## handles_structure_context(in_structure_context)[/code]
## is true this method will be called for every mouse move, click, key press, etc.[br]
## Returns true if the input event was handled, avoiding other input handlers
## to continue
func forward_input(_in_input_event: InputEvent, _in_camera: Camera3D, _in_context: StructureContext) -> bool:
	assert(false)
	return false


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	assert(false)
	return BuiltinInputHandlerPriorities.DEFAULT_INPUT_PRIORITY


# region public api

func get_workspace_context() -> WorkspaceContext:
	return _workspace_context


## When returns true no other InputHandlerBase will receive any inputs until this function returns false again,
## which usually will not happen until user is done with current input sequence (eg. drawing drag and drop selection)
func is_exclusive_input_consumer() -> bool:
	return false


## Can be used to react to the fact other InputHandlerBase has started to exclusively consuming inputs
## Usually used to clean up internal state and prepare for fresh input sequence
func handle_inputs_end() -> void:
	pass


## This method is used to inform an exclusive input consumer ended consuming inputs
## This gives a chance to react to this fact and do some special initialization
func handle_inputs_resume() -> void:
	pass


## Can be overwritten to react to the fact that there was an input event which never has been
## delivered to this input handler.
## Similar to handle_inputs_end() but will happen even if handler serving the event is not an
## exclusive consumer.
func handle_input_omission() -> void:
	pass


## Called after an input has been served to the input_handlers, whether the event was actually
## handled or not.
## Can be used to update the state of the handler without having to wait for the next event.
func handle_input_served() -> void:
	pass


func input_has_modifiers(in_event: InputEvent) -> bool:
	if not in_event is InputEventWithModifiers:
		return false
	var alt_pressed: bool = in_event.alt_pressed
	var ctrl_pressed: bool = in_event.ctrl_pressed
	var shift_pressed: bool = in_event.shift_pressed
	# Meta key does not work like the rest of the modifiers, so we fallback to Input API
	var meta_pressed: bool = Input.is_key_pressed(KEY_META)
	if in_event is InputEventKey:
		# Key inputs for an XXX button (in example shift) will have the ev.XXX_pressed property
		# set to false instead of whatever `ev.pressed` is, because of that we need aditional checks
		# for InputEventKey
		if in_event.keycode == KEY_ALT:
			alt_pressed = in_event.pressed
		if in_event.keycode == KEY_CTRL:
			ctrl_pressed = in_event.pressed
		if in_event.keycode == KEY_SHIFT:
			shift_pressed = in_event.pressed
		if in_event.keycode == KEY_META:
			meta_pressed = in_event.pressed
	return shift_pressed || alt_pressed || ctrl_pressed || meta_pressed


func print_event_with_modifiers(in_event:InputEventWithModifiers, in_prefix: String = "") -> void:
	var text_to_print: String = in_prefix
	var alt_pressed: bool = in_event.alt_pressed
	var ctrl_pressed: bool = in_event.ctrl_pressed
	var shift_pressed: bool = in_event.shift_pressed
	# Meta key does not work like the rest of the modifiers, so we fallback to Input API
	var meta_pressed: bool = Input.is_key_pressed(KEY_META)
	if in_event is InputEventKey:
		if in_event.keycode == KEY_ALT:
			alt_pressed = in_event.pressed
		if in_event.keycode == KEY_CTRL:
			ctrl_pressed = in_event.pressed
		if in_event.keycode == KEY_SHIFT:
			shift_pressed = in_event.pressed
		if in_event.keycode == KEY_META:
			meta_pressed = in_event.pressed
	text_to_print += "[color=%s][ALT][/color]" % [Color.WEB_GREEN.to_html() if alt_pressed else Color.ORANGE_RED.to_html()]
	text_to_print += "[color=%s][CTRL][/color]" % [Color.WEB_GREEN.to_html() if ctrl_pressed else Color.ORANGE_RED.to_html()]
	text_to_print += "[color=%s][SHIFT][/color]" % [Color.WEB_GREEN.to_html() if shift_pressed else Color.ORANGE_RED.to_html()]
	text_to_print += "[color=%s][META][/color]" % [Color.WEB_GREEN.to_html() if meta_pressed else Color.ORANGE_RED.to_html()]
	text_to_print += in_event.to_string()
	print_rich(text_to_print)

# region internal
func _init(in_context: WorkspaceContext) -> void:
	assert(in_context)
	_workspace_context = in_context

# region members
var _workspace_context: WorkspaceContext


enum BuiltinInputHandlerPriorities {
	DEFAULT_INPUT_PRIORITY = 1,
	ADD_ATOM_INPUT_HANDLER_PRIORITY = 200,
	ADD_SPRINGS_INPUT_HANDLER_PRIORITY = 201,
	ADD_STRUCTURE_INPUT_HANDLER_PRIORITY = 202,
	CREATE_VIRTUAL_MOTORS_INPUT_HANDLER_PRIORITY = 204,
	CREATE_REFERENCE_SHAPE_INPUT_HANDLER_PRIORITY = 205,
	QUICK_SEARCH_MENU_HANDLER = 230,
	BOX_SELECTION = 250,
	SELECTION_ATOM_HANDLER = 300,
	ADD_POSING_ATOM_INPUT_HANDLER_PRIORITY = 310,
	DRAG_DROP_CREATE_OBJECTS = 350,
	TRANSFORM_SELECTION_HANDLER_PRIORITY = 400,
	DEFAULT_CAMERA_INPUT_PRIORITY = 500,
	ORIENTATION_WIDGET_PRIORITY = 900,
	RING_MENU_HANDLER = 1000,
	DIALOG_INPUT_HANDLER = 1050,
}
