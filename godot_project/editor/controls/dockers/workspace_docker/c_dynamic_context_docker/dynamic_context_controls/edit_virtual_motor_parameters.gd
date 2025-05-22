extends DynamicContextControl


var _select_one_info_label: InfoLabel
var _rotary_motor_parameters_editor: RotaryMotorParametersEditor
var _linear_motor_parameters_editor: LinearMotorParametersEditor
var _motor_cycle_parameters_editor: MotorCycleParametersEditor

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_select_one_info_label = %SelectOneInfoLabel as InfoLabel
		_rotary_motor_parameters_editor = %RotaryMotorParametersEditor as RotaryMotorParametersEditor
		_linear_motor_parameters_editor = %LinearMotorParametersEditor as LinearMotorParametersEditor
		_motor_cycle_parameters_editor = %MotorCycleParametersEditor as MotorCycleParametersEditor


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_rotary_motor_parameters_editor.ensure_undo_redo_initialized(in_workspace_context)
	_linear_motor_parameters_editor.ensure_undo_redo_initialized(in_workspace_context)
	_motor_cycle_parameters_editor.ensure_undo_redo_initialized(in_workspace_context)
	var check_motor_selected: Callable = func(in_structure_context: StructureContext) -> bool:
		return in_structure_context.nano_structure is NanoVirtualMotor
	
	var selected_structures: Array[StructureContext] = in_workspace_context.get_structure_contexts_with_selection()
	
	if selected_structures.any(check_motor_selected):
		_update_contents(selected_structures)
		return true
	
	return false


func _update_contents(in_selected_structures: Array[StructureContext] ) -> void:
	var selected_motors_count: int = 0
	var parameters_to_track: NanoVirtualMotorParameters = null
	for context: StructureContext in in_selected_structures:
		if context.nano_structure is NanoVirtualMotor:
			selected_motors_count += 1
			parameters_to_track = context.nano_structure.get_parameters()
			if selected_motors_count > 1:
				break # early stop
	if selected_motors_count > 1:
		# More than 1 motor selected, show message label
		_select_one_info_label.show()
		_rotary_motor_parameters_editor.hide()
		_rotary_motor_parameters_editor.track_parameters(null)
		_linear_motor_parameters_editor.hide()
		_linear_motor_parameters_editor.track_parameters(null)
		_motor_cycle_parameters_editor.hide()
		_motor_cycle_parameters_editor.track_parameters(null)
	elif selected_motors_count == 0:
		# Entire editor should not be shown, just stop tracking any parameter if this was the case
		_rotary_motor_parameters_editor.track_parameters(null)
		_linear_motor_parameters_editor.track_parameters(null)
		_motor_cycle_parameters_editor.track_parameters(null)
	elif parameters_to_track.motor_type == NanoVirtualMotorParameters.Type.ROTARY:
		# Selected unique rotary motor
		_select_one_info_label.hide()
		_rotary_motor_parameters_editor.track_parameters(parameters_to_track)
		_rotary_motor_parameters_editor.show()
		_linear_motor_parameters_editor.track_parameters(null)
		_linear_motor_parameters_editor.hide()
		_motor_cycle_parameters_editor.show()
		_motor_cycle_parameters_editor.track_parameters(parameters_to_track)
	elif parameters_to_track.motor_type == NanoVirtualMotorParameters.Type.LINEAR:
		# Selected unique linear motor
		_select_one_info_label.hide()
		_rotary_motor_parameters_editor.track_parameters(null)
		_rotary_motor_parameters_editor.hide()
		_linear_motor_parameters_editor.track_parameters(parameters_to_track)
		_linear_motor_parameters_editor.show()
		_motor_cycle_parameters_editor.show()
		_motor_cycle_parameters_editor.track_parameters(parameters_to_track)
	else:
		# should never happen
		assert(false, "Impossible condition has occurred")
		pass
