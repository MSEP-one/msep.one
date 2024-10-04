class_name MotorCycleParametersEditor extends VBoxContainer


var _parameters_wref: WeakRef = weakref(null) # WeakRef<NanoLinearMotorParameters>
var _is_linear: bool = false


var _button_continuous_cycle: Button
var _button_timed_cycle: Button
var _button_by_distance_cycle: Button
var _time_span_picker: TimeSpanPicker
var _linear_distance_spin_box: SpinBoxSlider
var _rotary_distance_spin_box: SpinBoxSlider
var _time_span_picker_pause_time: TimeSpanPicker
var _check_button_swap_polarity: CheckButton
var _stop_after_check_box: CheckBox
var _stop_after_spin_box: SpinBoxSlider
var _state_animation_player: AnimationPlayer


# when not null an snapshot in this workspace will be taken on change from UI
var _workspace_snapshot_target: WorkspaceContext = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_button_continuous_cycle = %ButtonContinuousCycle as Button
		_button_timed_cycle = %ButtonTimedCycle as Button
		_button_by_distance_cycle = %ButtonByDistanceCycle as Button
		_time_span_picker = %TimeSpanPicker as TimeSpanPicker
		_linear_distance_spin_box = %LinearDistanceSpinBox as SpinBoxSlider
		_rotary_distance_spin_box = %RotaryDistanceSpinBox as SpinBoxSlider
		_state_animation_player = $StateAnimationPlayer as AnimationPlayer
		_time_span_picker_pause_time = %TimeSpanPickerPauseTime as TimeSpanPicker
		_check_button_swap_polarity = %CheckButtonSwapPolarity as CheckButton
		_stop_after_check_box = %StopAfterCheckBox as CheckBox
		_stop_after_spin_box = %StopAfterSpinBox as SpinBoxSlider
		_button_continuous_cycle.button_group.pressed.connect(_on_cycle_type_button_pressed)
		_time_span_picker.time_span_changed.connect(_on_time_span_picker_time_span_changed)
		_linear_distance_spin_box.value_confirmed.connect(_on_linear_distance_spin_box_value_confirmed)
		_rotary_distance_spin_box.value_confirmed.connect(_on_rotary_distance_spin_box_value_confirmed)
		_time_span_picker_pause_time.time_span_changed.connect(_on_time_span_picker_pause_time_time_span_changed)
		_stop_after_check_box.toggled.connect(_on_stop_after_check_box_toggled)
		_stop_after_spin_box.value_confirmed.connect(_on_stop_after_spin_box_value_confirmed)
		_check_button_swap_polarity.toggled.connect(_on_check_button_swap_polarity_toggled)


func ensure_undo_redo_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_snapshot_target != in_workspace_context:
		_workspace_snapshot_target = in_workspace_context
		_workspace_snapshot_target.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)


func _take_snapshot_if_configured(in_modified_property: String) -> void:
	if is_instance_valid(_workspace_snapshot_target):
		_workspace_snapshot_target.snapshot_moment("Set: " + in_modified_property)


func _on_workspace_context_history_snapshot_applied() -> void:
	if is_instance_valid(_get_parameters()):
		# if instance is still valid refresh the UI
		_on_parameters_changed()


func track_parameters(in_motor_parameters: NanoVirtualMotorParameters) -> void:
	var old_parameters: NanoVirtualMotorParameters = _get_parameters()
	if is_instance_valid(old_parameters):
		old_parameters.changed.disconnect(_on_parameters_changed)
	_parameters_wref = weakref(in_motor_parameters)
	if is_instance_valid(in_motor_parameters):
		_is_linear = in_motor_parameters is NanoLinearMotorParameters
		in_motor_parameters.changed.connect(_on_parameters_changed)
		_button_by_distance_cycle.text = tr(&"By Distance") if _is_linear else tr(&"By Revolutions")
		_on_parameters_changed()
	else:
		_is_linear = false


func _get_parameters() -> NanoVirtualMotorParameters:
	return _parameters_wref.get_ref() as NanoVirtualMotorParameters


func _get_linear_parameters() -> NanoLinearMotorParameters:
	assert(_is_linear, "Queried linear motor parameters when current parameter are rotary")
	return _parameters_wref.get_ref() as NanoLinearMotorParameters


func _get_rotary_parameters() -> NanoRotaryMotorParameters:
	assert(not _is_linear, "Queried rotary motor parameters when current parameter are linear")
	return _parameters_wref.get_ref() as NanoRotaryMotorParameters


func _on_cycle_type_button_pressed(in_button: BaseButton) -> void:
	var parameters: NanoVirtualMotorParameters = _get_parameters()
	match in_button.button_group.get_pressed_button():
		_button_continuous_cycle:
			parameters.cycle_type = NanoVirtualMotorParameters.CycleType.CONTINUOUS
			_take_snapshot_if_configured(tr(&"Use Continuous Cycle"))
		_button_timed_cycle:
			parameters.cycle_type = NanoVirtualMotorParameters.CycleType.TIMED
			_take_snapshot_if_configured(tr(&"Use Timed Cycle"))
		_button_by_distance_cycle:
			parameters.cycle_type = NanoVirtualMotorParameters.CycleType.BY_DISTANCE
			_take_snapshot_if_configured(tr(&"Use Distance Based Cycle"))
	ScriptUtils.call_deferred_once(_update_controls_visibility)


func _on_time_span_picker_time_span_changed(in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoVirtualMotorParameters = _get_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	parameters.cycle_time_limit_in_femtoseconds = time_in_femtoseconds
	_take_snapshot_if_configured(tr(&"Cycle Time Limit"))


func _on_linear_distance_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoVirtualMotorParameters = _get_parameters()
	parameters.cycle_distance_limit = in_value
	_take_snapshot_if_configured(tr(&"Cycle Distance Limit"))


func _on_rotary_distance_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoVirtualMotorParameters = _get_parameters()
	parameters.cycle_distance_limit = in_value
	_take_snapshot_if_configured(tr(&"Cycle Revolutions Limit"))


func _on_time_span_picker_pause_time_time_span_changed(in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoVirtualMotorParameters = _get_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	parameters.cycle_pause_time_in_femtoseconds = time_in_femtoseconds
	_take_snapshot_if_configured(tr(&"Cycle Pause Time"))


func _on_stop_after_check_box_toggled(in_button_pressed: bool) -> void:
	var parameters: NanoVirtualMotorParameters = _get_parameters()
	parameters.cycle_eventually_stops = in_button_pressed
	_take_snapshot_if_configured(tr(&"Cycle Eventually Stops"))


func _on_stop_after_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoVirtualMotorParameters = _get_parameters()
	parameters.cycle_stop_after_n_cycles = int(in_value)
	_update_stop_cycles_suffix()
	_take_snapshot_if_configured(tr(&"Cycle Count To Stop"))


func _update_stop_cycles_suffix() ->  void:
	_stop_after_spin_box.suffix = tr_n(&"cycle", &"cycles", int(_stop_after_spin_box.value))



func _on_check_button_swap_polarity_toggled(in_button_pressed: bool) -> void:
	var parameters: NanoVirtualMotorParameters = _get_parameters()
	parameters.cycle_swap_polarity = in_button_pressed
	_take_snapshot_if_configured(tr(&"Swap Polarity"))


func _on_parameters_changed() -> void:
	var parameters: NanoVirtualMotorParameters = _get_parameters()
	assert(parameters != null)
	var is_countinuous: bool = parameters.cycle_type == NanoVirtualMotorParameters.CycleType.CONTINUOUS
	var is_timed_cycle: bool = parameters.cycle_type == NanoVirtualMotorParameters.CycleType.TIMED
	var is_distance_based_cycle: bool = parameters.cycle_type == NanoVirtualMotorParameters.CycleType.BY_DISTANCE
	_button_continuous_cycle.set_pressed_no_signal(is_countinuous)
	_button_timed_cycle.set_pressed_no_signal(is_timed_cycle)
	_button_by_distance_cycle.set_pressed_no_signal(is_distance_based_cycle)
	_time_span_picker.set_block_signals(true)
	_time_span_picker.time_span_femtoseconds = parameters.cycle_time_limit_in_femtoseconds
	_time_span_picker.set_block_signals(false)
	if _is_linear:
		_linear_distance_spin_box.set_value_no_signal(parameters.cycle_distance_limit)
	else:
		_rotary_distance_spin_box.set_value_no_signal(parameters.cycle_distance_limit)
	_stop_after_check_box.set_pressed_no_signal(parameters.cycle_eventually_stops)
	_stop_after_spin_box.editable = parameters.cycle_eventually_stops
	_stop_after_spin_box.set_value_no_signal(parameters.cycle_stop_after_n_cycles)
	ScriptUtils.call_deferred_once(_update_stop_cycles_suffix)
	ScriptUtils.call_deferred_once(_update_controls_visibility)


func _update_controls_visibility() -> void:
	var parameters: NanoVirtualMotorParameters = _get_parameters()
	if not is_instance_valid(parameters):
		return
	match parameters.cycle_type:
		NanoVirtualMotorParameters.CycleType.CONTINUOUS:
			_state_animation_player.play(&"continuous_cycle")
		NanoVirtualMotorParameters.CycleType.TIMED:
			_state_animation_player.play(&"timed_cycle")
		NanoVirtualMotorParameters.CycleType.BY_DISTANCE:
			if _is_linear:
				_state_animation_player.play(&"linear_distance_cycle")
			else:
				_state_animation_player.play(&"rotary_distance_cycle")
