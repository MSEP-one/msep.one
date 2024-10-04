extends DynamicContextControl

# Type
var _rotary_motor_button: Button
var _linear_motor_button: Button

# Settings Containers
var _rotary_motor_parameters_editor: RotaryMotorParametersEditor
var _linear_motor_parameters_editor: LinearMotorParametersEditor
var _motor_cycle_parameters_editor: MotorCycleParametersEditor

var _create_object_parameters_wref: WeakRef = weakref(null)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		# Type
		_rotary_motor_button = %RotaryMotorButton as Button
		_linear_motor_button = %LinearMotorButton as Button
		# Settings Containers
		_rotary_motor_parameters_editor = %RotaryMotorParametersEditor as RotaryMotorParametersEditor
		_linear_motor_parameters_editor = %LinearMotorParametersEditor as LinearMotorParametersEditor
		_motor_cycle_parameters_editor = %MotorCycleParametersEditor as MotorCycleParametersEditor
		# Type Signals
		_rotary_motor_button.pressed.connect(_on_rotary_motor_button_pressed)
		_linear_motor_button.pressed.connect(_on_linear_motor_button_pressed)
		_rotary_motor_button.set_pressed_no_signal(true)
		_rotary_motor_parameters_editor.show()
		_linear_motor_parameters_editor.hide()


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	var structure_context: StructureContext = in_workspace_context.get_current_structure_context()
	if !is_instance_valid(structure_context) || !is_instance_valid(structure_context.nano_structure):
		return false
	_ensure_initialized(in_workspace_context)
	
	var check_object_being_created: Callable = func(in_struct: NanoStructure) -> bool:
		return in_struct is NanoVirtualMotor
	
	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_VIRTUAL_MOTORS:
		if in_workspace_context.is_creating_object() and \
				in_workspace_context.peek_object_being_created(check_object_being_created):
			in_workspace_context.abort_creating_object()
		return false
	
	if in_workspace_context.is_creating_object() and \
			not in_workspace_context.peek_object_being_created(check_object_being_created):
		# Another object is being created
		in_workspace_context.abort_creating_object()
	
	if not in_workspace_context.is_creating_object():
		in_workspace_context.start_creating_object(NanoVirtualMotor.new())
	
	return true


func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _create_object_parameters_wref.get_ref() == null:
		_create_object_parameters_wref = weakref(in_workspace_context.create_object_parameters)
		in_workspace_context.create_object_parameters.selected_virtual_motor_parameters_changed.connect(_on_create_object_parameters_selected_virtual_motor_parameters_changed)
		# Create Panel doesn't need Undo/Redo. Because of this we dont execute
		# `xxx_parameters_editor.ensure_undo_redo_initialized(in_workspace_context)`
		_rotary_motor_parameters_editor.track_parameters(in_workspace_context.create_object_parameters.new_rotary_motor_parameters)
		_linear_motor_parameters_editor.track_parameters(in_workspace_context.create_object_parameters.new_linear_motor_parameters)
		_motor_cycle_parameters_editor.track_parameters(in_workspace_context.create_object_parameters.new_rotary_motor_parameters)


func _on_create_object_parameters_selected_virtual_motor_parameters_changed(in_parameters: NanoVirtualMotorParameters) -> void:
	_rotary_motor_button.set_pressed_no_signal(in_parameters.motor_type == NanoVirtualMotorParameters.Type.ROTARY)
	_rotary_motor_parameters_editor.visible = in_parameters.motor_type == NanoVirtualMotorParameters.Type.ROTARY
	_linear_motor_button.set_pressed_no_signal(in_parameters.motor_type == NanoVirtualMotorParameters.Type.LINEAR)
	_linear_motor_parameters_editor.visible = in_parameters.motor_type == NanoVirtualMotorParameters.Type.LINEAR
	_motor_cycle_parameters_editor.track_parameters(in_parameters)


func _on_rotary_motor_button_pressed() -> void:
	_get_create_object_parameters().set_selected_virtual_motor_parameters(_get_rotary_parameters())


func _on_linear_motor_button_pressed() -> void:
	_get_create_object_parameters().set_selected_virtual_motor_parameters(_get_linear_parameters())



func _get_create_object_parameters() -> CreateObjectParameters:
	return _create_object_parameters_wref.get_ref() as CreateObjectParameters


func _get_rotary_parameters() -> NanoRotaryMotorParameters:
	return _get_create_object_parameters().new_rotary_motor_parameters


func _get_linear_parameters() -> NanoLinearMotorParameters:
	return _get_create_object_parameters().new_linear_motor_parameters
