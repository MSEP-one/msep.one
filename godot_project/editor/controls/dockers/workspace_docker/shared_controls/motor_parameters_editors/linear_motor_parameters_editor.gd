class_name LinearMotorParametersEditor extends GridContainer

@export var show_motor_type: bool = false

var _parameters_wref: WeakRef = weakref(null) # WeakRef<NanoLinearMotorParameters>

# Linear Settings Controls
var _linear_ramp_in_time: TimeSpanPicker
var _linear_ramp_out_time: TimeSpanPicker
var _linear_top_speed_spin_box: SpinBoxSlider
var _linear_forward_polarity_button: Button
var _linear_backward_polarity_button: Button

# when not null a snapshot in this workspace will be taken on change from UI
var _workspace_snapshot_target: WorkspaceContext = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		# Showing type controls is done on initialization and never again
		$TypeLabel.visible = show_motor_type
		$TypeButton.visible = show_motor_type
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		# Linear Settings Controls
		_linear_ramp_in_time = %LinearRampInTime as TimeSpanPicker
		_linear_ramp_out_time = %LinearRampOutTime as TimeSpanPicker
		_linear_top_speed_spin_box = %LinearTopSpeedSpinBox as SpinBoxSlider
		_linear_forward_polarity_button = %LinearForwardPolarityButton as Button
		_linear_backward_polarity_button = %LinearBackwardPolarityButton as Button
		# Linear controls signals
		_linear_ramp_in_time.time_span_changed.connect(_on_linear_ramp_in_time_time_span_changed)
		_linear_ramp_out_time.time_span_changed.connect(_on_linear_ramp_out_time_time_span_changed)
		_linear_top_speed_spin_box.value_confirmed.connect(_on_linear_top_speed_spin_box_value_confirmed)
		_linear_forward_polarity_button.toggled.connect(_on_linear_forward_polarity_button_toggled)
		_linear_backward_polarity_button.toggled.connect(_on_linear_backward_polarity_button_toggled)


func ensure_undo_redo_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_snapshot_target != in_workspace_context:
		_workspace_snapshot_target = in_workspace_context
		_workspace_snapshot_target.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)


func _take_snapshot_if_configured(in_modified_property: String) -> void:
	if is_instance_valid(_workspace_snapshot_target):
		_workspace_snapshot_target.snapshot_moment("Set: " + in_modified_property)


func _on_workspace_context_history_snapshot_applied() -> void:
	if is_instance_valid(_get_linear_parameters()):
		# if instance is still valid refresh the UI
		_on_linear_motor_parameters_changed()


func _get_linear_parameters() -> NanoLinearMotorParameters:
	return _parameters_wref.get_ref() as NanoLinearMotorParameters


func track_parameters(in_linear_motor_parameters: NanoLinearMotorParameters) -> void:
	var old_parameters: NanoLinearMotorParameters = _get_linear_parameters()
	if is_instance_valid(old_parameters):
		old_parameters.changed.disconnect(_on_linear_motor_parameters_changed)
	_parameters_wref = weakref(in_linear_motor_parameters)
	if is_instance_valid(in_linear_motor_parameters):
		in_linear_motor_parameters.changed.connect(_on_linear_motor_parameters_changed)
		_on_linear_motor_parameters_changed()


func _on_linear_motor_parameters_changed() -> void:
	var parameters: NanoLinearMotorParameters = _get_linear_parameters()
	assert(parameters != null)
	_linear_ramp_in_time.time_span_femtoseconds = TimeSpanPicker.unit_to_femtoseconds(
			parameters.ramp_in_time_in_nanoseconds, TimeSpanPicker.Unit.NANOSECOND)
	_linear_ramp_out_time.time_span_femtoseconds = TimeSpanPicker.unit_to_femtoseconds(
			parameters.ramp_out_time_in_nanoseconds, TimeSpanPicker.Unit.NANOSECOND)
	_linear_ramp_out_time.editable = parameters.cycle_type != NanoVirtualMotorParameters.CycleType.CONTINUOUS
	var top_speed_in_femtoseconds: float = parameters.top_speed_in_nanometers_by_nanoseconds / 1e+6
	_linear_top_speed_spin_box.set_value_no_signal(top_speed_in_femtoseconds)
	_linear_forward_polarity_button.set_pressed_no_signal(parameters.polarity == NanoLinearMotorParameters.Polarity.FORWARD)
	_linear_backward_polarity_button.set_pressed_no_signal(parameters.polarity == NanoLinearMotorParameters.Polarity.BACKWARDS)


func _on_linear_ramp_in_time_time_span_changed(in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	if in_unit != TimeSpanPicker.Unit.NANOSECOND:
		# Convert magnitude to nanoseconds
		var in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
		in_magnitude = TimeSpanPicker.femtoseconds_to_unit(in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	_get_linear_parameters().ramp_in_time_in_nanoseconds = in_magnitude
	_take_snapshot_if_configured(tr(&"Ramp-In Time"))

func _on_linear_ramp_out_time_time_span_changed(in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	if in_unit != TimeSpanPicker.Unit.NANOSECOND:
		# Convert magnitude to nanoseconds
		var in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
		in_magnitude = TimeSpanPicker.femtoseconds_to_unit(in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	_get_linear_parameters().ramp_out_time_in_nanoseconds = in_magnitude
	_take_snapshot_if_configured(tr(&"Ramp-Out Time"))

func _on_linear_top_speed_spin_box_value_confirmed(in_top_speed_in_femtoseconds: float) -> void:
	var top_speed_in_nanoseconds: float = in_top_speed_in_femtoseconds * 1e+6
	_get_linear_parameters().top_speed_in_nanometers_by_nanoseconds = top_speed_in_nanoseconds
	_take_snapshot_if_configured(tr(&"Top Speed"))

func _on_linear_forward_polarity_button_toggled(in_button_pressed: bool) -> void:
	if in_button_pressed:
		_get_linear_parameters().polarity = NanoLinearMotorParameters.Polarity.FORWARD
		_take_snapshot_if_configured(tr(&"Use Forward Polarity"))

func _on_linear_backward_polarity_button_toggled(in_button_pressed: bool) -> void:
	if in_button_pressed:
		_get_linear_parameters().polarity = NanoLinearMotorParameters.Polarity.BACKWARDS
		_take_snapshot_if_configured(tr(&"Use Backward Polarity"))
