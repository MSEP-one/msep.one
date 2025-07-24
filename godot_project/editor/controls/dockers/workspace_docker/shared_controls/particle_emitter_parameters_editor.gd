class_name ParticleEmitterParametersEditor extends VBoxContainer


var _initial_delay_time_picker: TimeSpanPicker
var _molecules_per_instance_spin_box: SpinBoxSlider
var _instance_rate_time_picker: TimeSpanPicker
var _initial_speed_spin_box: SpinBoxSlider
var _spin_speed_spin_box: SpinBoxSlider
var _spin_direction_label: Label
var _spin_clockwise_button: Button
var _spin_counter_clockwise_button: Button
var _spread_angle_spin_box: SpinBoxSlider
var _stop_never_button: Button
var _stop_count_button: Button
var _stop_time_button: Button
var _limit_label: Label
var _limit_instances_spin_box: SpinBoxSlider
var _limit_nanoseconds_time_picker: TimeSpanPicker

# when not null an snapshot in this workspace will be taken on change from UI
var _workspace_snapshot_target: WorkspaceContext = null
var _parameters_wref: WeakRef = weakref(null) # WeakRef<NanoParticleEmitterParameters>


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_initial_delay_time_picker = %InitialDelayTimePicker as TimeSpanPicker
		_molecules_per_instance_spin_box = %MoleculesPerInstanceSpinBox as SpinBoxSlider
		_instance_rate_time_picker = %InstanceRateTimePicker as TimeSpanPicker
		_initial_speed_spin_box = %InitialSpeedSpinBox as SpinBoxSlider
		_spin_speed_spin_box = %SpinSpeedSpinBox as SpinBoxSlider
		_spin_direction_label = %SpinDirectionLabel as Label
		_spin_clockwise_button = %SpinClockwiseButton as Button
		_spin_counter_clockwise_button = %SpinCounterClockwiseButton as Button
		_spread_angle_spin_box = %SpreadAngleSpinBox as SpinBoxSlider
		_stop_never_button = %StopNeverButton as Button
		_stop_count_button = %StopCountButton as Button
		_stop_time_button = %StopTimeButton as Button
		_limit_label = %LimitLabel as Label
		_limit_instances_spin_box = %LimitInstancesSpinBox as SpinBoxSlider
		_limit_nanoseconds_time_picker = %LimitNanosecondsTimePicker as TimeSpanPicker
		_initial_delay_time_picker.time_span_changed.connect(_on_initial_delay_time_picker_time_span_changed)
		_molecules_per_instance_spin_box.value_confirmed.connect(_on_molecules_per_instance_spin_box_value_confirmed)
		_instance_rate_time_picker.time_span_changed.connect(_on_instance_rate_time_picker_time_span_changed)
		_initial_speed_spin_box.value_confirmed.connect(_on_initial_speed_spin_box_value_confirmed)
		_spin_speed_spin_box.value_confirmed.connect(_on_spin_speed_spin_box_value_confirmed.unbind(1))
		_spin_clockwise_button.button_group.pressed.connect(_on_spin_direction_button_group_pressed.unbind(1))
		_spread_angle_spin_box.value_confirmed.connect(_on_spread_angle_spin_box_value_confirmed)
		_stop_never_button.button_group.pressed.connect(_on_stop_condition_button_group_pressed)
		_limit_instances_spin_box.value_confirmed.connect(_on_limit_instances_spin_box_value_confirmed)
		_limit_nanoseconds_time_picker.time_span_changed.connect(_on_limit_nanoseconds_time_picker_time_span_changed)
		FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
		var use_emmit_count: bool = FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_EMITTERS_WITH_EMMIT_COUNT)
		_on_feature_flag_toggled(FeatureFlagManager.FEATURE_FLAG_EMITTERS_WITH_EMMIT_COUNT, use_emmit_count)


func track_parameters(out_emitter_parameters: NanoParticleEmitterParameters) -> void:
	var old_parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	if is_instance_valid(old_parameters):
		old_parameters.changed.disconnect(_on_emitter_parameters_changed)
	_parameters_wref = weakref(out_emitter_parameters)
	if out_emitter_parameters != null:
		out_emitter_parameters.changed.connect(_on_emitter_parameters_changed)
		_on_emitter_parameters_changed()


func ensure_undo_redo_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_snapshot_target != in_workspace_context:
		_workspace_snapshot_target = in_workspace_context
		_workspace_snapshot_target.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)


func _take_snapshot_if_configured(in_modified_property: String) -> void:
	if is_instance_valid(_workspace_snapshot_target):
		_workspace_snapshot_target.snapshot_moment("Set: " + in_modified_property)


func _on_workspace_context_history_snapshot_applied() -> void:
	if is_instance_valid(_get_emitter_parameters()):
		# if instance is still valid refresh the UI
		_on_emitter_parameters_changed()


func _get_emitter_parameters() -> NanoParticleEmitterParameters:
	return _parameters_wref.get_ref() as NanoParticleEmitterParameters


func _on_emitter_parameters_changed() -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	assert(parameters != null, "Impossible condition. How can parametters not exists and have changed at the same time?")
	
	_initial_delay_time_picker.time_span_femtoseconds = TimeSpanPicker.unit_to_femtoseconds(
			parameters.get_initial_delay_in_nanoseconds(), TimeSpanPicker.Unit.NANOSECOND)
	_molecules_per_instance_spin_box.set_value_no_signal(parameters.get_molecules_per_instance())
	_instance_rate_time_picker.time_span_femtoseconds = TimeSpanPicker.unit_to_femtoseconds(
			parameters.get_instance_rate_time_in_nanoseconds(), TimeSpanPicker.Unit.NANOSECOND)
	_initial_speed_spin_box.set_value_no_signal(parameters.get_instance_speed_nanometers_per_picosecond())
	const NANOSECOND_TO_PICOSECOND: float = 1.0 / 1000.0
	var spin_speed: float = parameters.get_instance_spin_revolutions_per_nanosecond() * NANOSECOND_TO_PICOSECOND
	_spin_speed_spin_box.set_value_no_signal(abs(spin_speed))
	_spin_clockwise_button.set_pressed_no_signal(spin_speed >= 0)
	_spin_counter_clockwise_button.set_pressed_no_signal(spin_speed < 0)
	_update_spin_direction_visibility()
	_update_spin_speed_tooltip()
	_spread_angle_spin_box.set_value_no_signal(parameters.get_spread_angle_degrees())
	_stop_never_button.set_pressed_no_signal(parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.NEVER)
	_stop_count_button.set_pressed_no_signal(parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.INSTANCE_COUNT)
	_stop_time_button.set_pressed_no_signal(parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.TIME)
	_limit_label.visible = parameters.get_limit_type() != NanoParticleEmitterParameters.LimitType.NEVER
	_limit_instances_spin_box.visible = parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.INSTANCE_COUNT
	_limit_nanoseconds_time_picker.visible = parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.TIME
	_limit_instances_spin_box.set_value_no_signal(parameters.get_stop_emitting_after_count())
	_limit_nanoseconds_time_picker.time_span_femtoseconds = TimeSpanPicker.unit_to_femtoseconds(
			parameters.get_stop_emitting_after_nanoseconds(), TimeSpanPicker.Unit.NANOSECOND)


func _on_initial_delay_time_picker_time_span_changed(
		in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
			time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	parameters.set_initial_delay_in_nanoseconds(time_in_nanoseconds)
	_take_snapshot_if_configured(tr(&"Initial Delay"))


func _on_molecules_per_instance_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_molecules_per_instance(int(in_value))
	_take_snapshot_if_configured(tr(&"Molecules per Instantation"))


func _on_instance_rate_time_picker_time_span_changed(
		in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
			time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	parameters.set_instance_rate_time_in_nanoseconds(time_in_nanoseconds)
	_take_snapshot_if_configured(tr(&"Instance Rate"))


func _on_initial_speed_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_instance_speed_nanometers_per_picosecond(in_value)
	_take_snapshot_if_configured(tr(&"Initial Speed"))


func _on_spin_speed_spin_box_value_confirmed() -> void:
	_update_instance_spin_revolutions_per_nanosecond()


func _on_spin_direction_button_group_pressed() -> void:
	_update_instance_spin_revolutions_per_nanosecond()
	

func _update_instance_spin_revolutions_per_nanosecond() -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var polarity: float = 1 if _spin_clockwise_button.button_pressed else -1
	const PICOSECOND_TO_NANOSECOND: float = 1000.0
	parameters.set_instance_spin_revolutions_per_nanosecond(polarity * _spin_speed_spin_box.value * PICOSECOND_TO_NANOSECOND)
	_update_spin_speed_tooltip()
	_update_spin_direction_visibility()
	_take_snapshot_if_configured(tr(&"Spin Speed"))


func _update_spin_direction_visibility() -> void:
	if is_equal_approx(_spin_speed_spin_box.value, .0):
		_spin_direction_label.hide()
		# Hide HBoxContainer containing buttons
		_spin_clockwise_button.get_parent_control().hide()
	else:
		_spin_direction_label.show()
		# Show HBoxContainer containing buttons
		_spin_clockwise_button.get_parent_control().show()


func _update_spin_speed_tooltip() -> void:
	var FEMTOSECONDS_PER_PICOSECOND: float = 1000.0
	_spin_speed_spin_box.tooltip_text = tr("Revolutions per Picosecond:\n" +
		"This is the number of spins a motor will do per picosecond.\n" +
		"At %.2f Rev/ps a molecule will (if no external force stops it) complete a spin every %.2f femtoseconds") % \
		[ _spin_speed_spin_box.value, 1.0 / (_spin_speed_spin_box.value / FEMTOSECONDS_PER_PICOSECOND)]


func _on_spread_angle_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_spread_angle_degrees(in_value)
	_take_snapshot_if_configured(tr(&"Spread Angle"))


func _on_stop_condition_button_group_pressed(in_button: Button) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var type: NanoParticleEmitterParameters.LimitType
	if in_button == _stop_never_button:
		type = NanoParticleEmitterParameters.LimitType.NEVER
	elif in_button == _stop_count_button:
		type = NanoParticleEmitterParameters.LimitType.INSTANCE_COUNT
	elif in_button == _stop_time_button:
		type = NanoParticleEmitterParameters.LimitType.TIME
	else:
		assert(false, "Unexpected button in ButtonGroup: " + str(get_path_to(in_button)))
		pass
	parameters.set_limit_type(type)
	_take_snapshot_if_configured(tr(&"Stop Condition"))


func _on_limit_instances_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_stop_emitting_after_count(int(in_value))
	_take_snapshot_if_configured(tr(&"Instance Limit"))


func _on_limit_nanoseconds_time_picker_time_span_changed(
		in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
			time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	parameters.set_stop_emitting_after_nanoseconds(time_in_nanoseconds)
	_take_snapshot_if_configured(tr(&"Time Limit"))

func _on_feature_flag_toggled(in_path: String, in_new_value: bool) -> void:
	if in_path == FeatureFlagManager.FEATURE_FLAG_EMITTERS_WITH_EMMIT_COUNT:
		_molecules_per_instance_spin_box.visible = in_new_value
		%MoleculesPerInstanceLabel.visible = in_new_value
