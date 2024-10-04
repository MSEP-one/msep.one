extends InputHandlerBase

var _orientation_widget : Control = null


## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return true


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(_in_structure_context: StructureContext) -> bool:
	return true


func is_exclusive_input_consumer() -> bool:
	return false


func _init(in_context: WorkspaceContext) -> void:
	super(in_context)


## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input in_input_event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, in_camera: Camera3D, \
		_in_context: StructureContext) -> bool:
	
	if _orientation_widget == null:
		var orientation_widget: Node3D = in_camera.get_viewport().get_orientation_widget()
		if !orientation_widget:
			return false
		
		_orientation_widget = orientation_widget.get_node_or_null("DrawOrientationWidget")
	
	if _orientation_widget == null:
		return false
	
	_orientation_widget.creation_distance = \
	_in_context.workspace_context.create_object_parameters.drop_distance
	
	var is_hovering: bool = true if _orientation_widget.colliding_axis_index > -1 else false
	
	if is_hovering:
		if in_input_event is InputEventMouse:
			if in_input_event is InputEventMouseButton:
				if in_input_event.is_pressed():
					_orientation_widget.manage_mouse_click(in_input_event)
					return true
	
	
	return false


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.ORIENTATION_WIDGET_PRIORITY
