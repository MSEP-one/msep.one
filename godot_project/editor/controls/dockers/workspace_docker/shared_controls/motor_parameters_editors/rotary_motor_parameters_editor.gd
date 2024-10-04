class_name RotaryMotorParametersEditor extends GridContainer


@export var show_motor_type: bool = false


var _parameters_wref: WeakRef = weakref(null) # WeakRef<NanoRotaryMotorParameters>

# Rotary Settings Controls
var _rotary_ramp_in_time: TimeSpanPicker
var _rotary_ramp_out_time: TimeSpanPicker
var _rotary_top_speed_check_box: CheckBox
var _rotary_top_speed_spin_box: SpinBoxSlider
var _rotary_max_torque_check_box: CheckBox
var _rotary_max_torque_spin_box: SpinBoxSlider
var _rotary_jerk_limit_check_box: CheckBox
var _rotary_jerk_limit_spin_box_slider: SpinBoxSlider
var _rotary_clockwise_button: Button
var _rotary_counter_clockwise_button: Button

# when not null an snapshot in this workspace will be taken on change from UI
var _workspace_snapshot_target: WorkspaceContext = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		# Showing type controls is done on initialization and never again
		$TypeLabel.visible = show_motor_type
		$TypeButton.visible = show_motor_type
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_rotary_ramp_in_time = %RotaryRampInTime as TimeSpanPicker
		_rotary_ramp_out_time = %RotaryRampOutTime as TimeSpanPicker
		_rotary_top_speed_check_box = %RotaryTopSpeedCheckBox as CheckBox
		_rotary_top_speed_spin_box = %RotaryTopSpeedSpinBox as SpinBoxSlider
		_rotary_max_torque_check_box = %RotaryMaxTorqueCheckBox as CheckBox
		_rotary_max_torque_spin_box = %RotaryMaxTorqueSpinBox as SpinBoxSlider
		_rotary_jerk_limit_check_box = %RotaryJerkLimitCheckBox as CheckBox
		_rotary_jerk_limit_spin_box_slider = %RotaryJerkLimitSpinBoxSlider as SpinBoxSlider
		_rotary_clockwise_button = %RotaryClockwiseButton as Button
		_rotary_counter_clockwise_button = %RotaryCounterClockwiseButton as Button
		# Rotary controls signals
		_rotary_ramp_in_time.time_span_changed.connect(_on_rotary_ramp_in_time_time_span_changed)
		_rotary_ramp_out_time.time_span_changed.connect(_on_rotary_ramp_out_time_time_span_changed)
		_rotary_top_speed_check_box.toggled.connect(_on_rotary_top_speed_check_box_toggled)
		_rotary_top_speed_spin_box.value_confirmed.connect(_on_rotary_top_speed_spin_box_value_confirmed)
		_rotary_max_torque_check_box.toggled.connect(_on_rotary_max_torque_check_box_toggled)
		_rotary_max_torque_spin_box.value_confirmed.connect(_rotary_max_torque_spin_box_value_confirmed)
		_rotary_jerk_limit_check_box.toggled.connect(_on_rotary_jerk_limit_check_box_toggled)
		_rotary_clockwise_button.toggled.connect(_on_rotary_clockwise_button_toggled)
		_rotary_counter_clockwise_button.toggled.connect(_on_rotary_counter_clockwise_button_toggled)
		_rotary_jerk_limit_spin_box_slider.value_confirmed.connect(_on_rotary_jerk_limit_spin_box_slider_value_confirmed)


func ensure_undo_redo_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_snapshot_target != in_workspace_context:
		_workspace_snapshot_target = in_workspace_context
		_workspace_snapshot_target.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)


func _take_snapshot_if_configured(in_modified_property: String) -> void:
	if is_instance_valid(_workspace_snapshot_target):
		_workspace_snapshot_target.snapshot_moment("Set: " + in_modified_property)


func _on_workspace_context_history_snapshot_applied() -> void:
	if is_instance_valid(_get_rotary_parameters()):
		# if instance is still valid refresh the UI
		_on_rotary_motor_parameters_changed()


func _get_rotary_parameters() -> NanoRotaryMotorParameters:
	return _parameters_wref.get_ref() as NanoRotaryMotorParameters


func track_parameters(in_rotary_motor_parameters: NanoRotaryMotorParameters) -> void:
	var old_parameters: NanoRotaryMotorParameters = _get_rotary_parameters()
	if is_instance_valid(old_parameters):
		old_parameters.changed.disconnect(_on_rotary_motor_parameters_changed)
	_parameters_wref = weakref(in_rotary_motor_parameters)
	if is_instance_valid(in_rotary_motor_parameters):
		in_rotary_motor_parameters.changed.connect(_on_rotary_motor_parameters_changed)
		_on_rotary_motor_parameters_changed()


func _on_rotary_motor_parameters_changed() -> void:
	var parameters: NanoRotaryMotorParameters = _get_rotary_parameters()
	assert(parameters != null)
	_rotary_ramp_in_time.time_span_femtoseconds = TimeSpanPicker.unit_to_femtoseconds(
			parameters.ramp_in_time_in_nanoseconds, TimeSpanPicker.Unit.NANOSECOND)
	_rotary_ramp_out_time.time_span_femtoseconds = TimeSpanPicker.unit_to_femtoseconds(
			parameters.ramp_out_time_in_nanoseconds, TimeSpanPicker.Unit.NANOSECOND)
	_rotary_ramp_out_time.editable = parameters.cycle_type != NanoVirtualMotorParameters.CycleType.CONTINUOUS
	_rotary_top_speed_check_box.set_pressed_no_signal(parameters.max_speed_type == NanoRotaryMotorParameters.MaxSpeedType.TOP_SPEED)
	_rotary_top_speed_spin_box.editable = _rotary_top_speed_check_box.button_pressed
	var top_revolutions_per_picoseconds: float = parameters.top_revolutions_per_nanosecond / 1000
	_rotary_top_speed_spin_box.set_value_no_signal(top_revolutions_per_picoseconds)
	_update_rotary_top_speed_tooltip()
	_rotary_max_torque_check_box.set_pressed_no_signal(parameters.max_speed_type == NanoRotaryMotorParameters.MaxSpeedType.MAX_TORQUE)
	_rotary_max_torque_spin_box.editable = _rotary_max_torque_check_box.button_pressed
	_rotary_max_torque_spin_box.set_value_no_signal(parameters.max_torque)
	_rotary_jerk_limit_check_box.set_pressed_no_signal(parameters.is_jerk_limited)
	_rotary_jerk_limit_spin_box_slider.editable = _rotary_jerk_limit_check_box.button_pressed
	_rotary_jerk_limit_spin_box_slider.set_value_no_signal(parameters.jerk_limit)
	_rotary_clockwise_button.set_pressed_no_signal(parameters.polarity == NanoRotaryMotorParameters.Polarity.CLOCKWISE)
	_rotary_counter_clockwise_button.set_pressed_no_signal(parameters.polarity == NanoRotaryMotorParameters.Polarity.COUNTER_CLOCKWISE)


func _on_rotary_ramp_in_time_time_span_changed(in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	if in_unit != TimeSpanPicker.Unit.NANOSECOND:
		# Convert magnitude to nanoseconds
		var in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
		in_magnitude = TimeSpanPicker.femtoseconds_to_unit(in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	_get_rotary_parameters().ramp_in_time_in_nanoseconds = in_magnitude
	_take_snapshot_if_configured(tr(&"Ramp-In Time"))


func _on_rotary_ramp_out_time_time_span_changed(in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	if in_unit != TimeSpanPicker.Unit.NANOSECOND:
		# Convert magnitude to nanoseconds
		var in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
		in_magnitude = TimeSpanPicker.femtoseconds_to_unit(in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	_get_rotary_parameters().ramp_out_time_in_nanoseconds = in_magnitude
	_take_snapshot_if_configured(tr(&"Ramp-Out Time"))


func _on_rotary_top_speed_check_box_toggled(in_button_pressed: bool) -> void:
	_rotary_top_speed_spin_box.editable = in_button_pressed
	if in_button_pressed:
		_get_rotary_parameters().max_speed_type = NanoRotaryMotorParameters.MaxSpeedType.TOP_SPEED
		_take_snapshot_if_configured(tr(&"Use Max Speed"))


func _on_rotary_top_speed_spin_box_value_confirmed(in_top_speed: float) -> void:
	_get_rotary_parameters().top_revolutions_per_nanosecond = in_top_speed * 1000.0
	_update_rotary_top_speed_tooltip()
	_take_snapshot_if_configured(tr(&"Top Speed"))


func _update_rotary_top_speed_tooltip() -> void:
	_rotary_top_speed_spin_box.tooltip_text = tr("Revolutions per Picosecond:\n" +
		"This is the number of spins a motor will do per picosecond.\n" +
		"At %.2f Rev/ps a motor will make a spin every %.2f femtoseconds") % \
		[ _rotary_top_speed_spin_box.value, 1.0 / (_rotary_top_speed_spin_box.value / 1000.0)]


func _on_rotary_max_torque_check_box_toggled(in_button_pressed: bool) -> void:
	_rotary_max_torque_spin_box.editable = in_button_pressed
	if in_button_pressed:
		_get_rotary_parameters().max_speed_type = NanoRotaryMotorParameters.MaxSpeedType.MAX_TORQUE
		_take_snapshot_if_configured(tr(&"Use Max Torque"))


func _rotary_max_torque_spin_box_value_confirmed(in_max_torque: float) -> void:
	_get_rotary_parameters().max_torque = in_max_torque
	_take_snapshot_if_configured(tr(&"Max Torque"))


func _on_rotary_jerk_limit_check_box_toggled(in_button_pressed: bool) -> void:
	_rotary_jerk_limit_spin_box_slider.editable = in_button_pressed
	_get_rotary_parameters().is_jerk_limited = in_button_pressed
	_take_snapshot_if_configured(tr(&"Use Jerk Limit"))


func _on_rotary_clockwise_button_toggled(in_button_pressed: bool) -> void:
	if in_button_pressed:
		_get_rotary_parameters().polarity = NanoRotaryMotorParameters.Polarity.CLOCKWISE
		_take_snapshot_if_configured(tr(&"Use Clockwise Polarity"))


func _on_rotary_counter_clockwise_button_toggled(in_button_pressed: bool) -> void:
	if in_button_pressed:
		_get_rotary_parameters().polarity = NanoRotaryMotorParameters.Polarity.COUNTER_CLOCKWISE
		_take_snapshot_if_configured(tr(&"Use Counter Clockwise Polarity"))


func _on_rotary_jerk_limit_spin_box_slider_value_confirmed(in_jerk_limit: float) -> void:
	_get_rotary_parameters().jerk_limit = in_jerk_limit
	_take_snapshot_if_configured(tr(&"Jerk Limit"))

