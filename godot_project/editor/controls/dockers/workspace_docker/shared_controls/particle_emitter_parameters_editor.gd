class_name ParticleEmitterParametersEditor extends VBoxContainer


var _initial_delay_time_picker: TimeSpanPicker
var _molecules_per_instance_spin_box: SpinBoxSlider
var _instance_rate_time_picker: TimeSpanPicker
var _initial_speed_spin_box: SpinBoxSlider
var _spread_angle_spin_box: SpinBoxSlider
var _stop_never_button: Button
var _stop_count_button: Button
var _stop_time_button: Button
var _limit_label: Label
var _limit_instances_spin_box: SpinBoxSlider
var _limit_nanoseconds_time_picker: TimeSpanPicker
var _molecule_preview: AspectRatioContainer
var _load_molecule_from_selection_button: Button
var _load_molecule_from_library_button: Button


var _parameters_wref: WeakRef = weakref(null) # WeakRef<NanoParticleEmitterParameters>


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_initial_delay_time_picker = %InitialDelayTimePicker as TimeSpanPicker
		_molecules_per_instance_spin_box = %MoleculesPerInstanceSpinBox as SpinBoxSlider
		_instance_rate_time_picker = %InstanceRateTimePicker as TimeSpanPicker
		_initial_speed_spin_box = %InitialSpeedSpinBox as SpinBoxSlider
		_spread_angle_spin_box = %SpreadAngleSpinBox as SpinBoxSlider
		_stop_never_button = %StopNeverButton as Button
		_stop_count_button = %StopCountButton as Button
		_stop_time_button = %StopTimeButton as Button
		_limit_label = %LimitLabel as Label
		_limit_instances_spin_box = %LimitInstancesSpinBox as SpinBoxSlider
		_limit_nanoseconds_time_picker = %LimitNanosecondsTimePicker as TimeSpanPicker
		_molecule_preview = %MoleculePreview as AspectRatioContainer
		_load_molecule_from_selection_button = %LoadMoleculeFromSelectionButton as Button
		_load_molecule_from_library_button = %LoadMoleculeFromLibraryButton as Button
		_initial_delay_time_picker.time_span_changed.connect(_on_initial_delay_time_picker_time_span_changed)
		_molecules_per_instance_spin_box.value_confirmed.connect(_on_molecules_per_instance_spin_box_value_confirmed)
		_instance_rate_time_picker.time_span_changed.connect(_on_instance_rate_time_picker_time_span_changed)
		_initial_speed_spin_box.value_confirmed.connect(_on_initial_speed_spin_box_value_confirmed)
		_spread_angle_spin_box.value_confirmed.connect(_on_spread_angle_spin_box_value_confirmed)
		_stop_never_button.button_group.pressed.connect(_on_stop_condition_button_group_pressed)
		_limit_instances_spin_box.value_confirmed.connect(_on_limit_instances_spin_box_value_confirmed)
		_limit_nanoseconds_time_picker.time_span_changed.connect(_on_limit_nanoseconds_time_picker_time_span_changed)
		_load_molecule_from_selection_button.pressed.connect(_on_load_molecule_from_selection_button_pressed)
		_load_molecule_from_library_button.pressed.connect(_on_load_molecule_from_library_button_pressed)


func track_parameters(out_emitter_parameters: NanoParticleEmitterParameters) -> void:
	var old_parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	if is_instance_valid(old_parameters):
		old_parameters.changed.disconnect(_on_emitter_parameters_changed)
	_parameters_wref = weakref(out_emitter_parameters)
	if out_emitter_parameters != null:
		out_emitter_parameters.changed.connect(_on_emitter_parameters_changed)
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
	_spread_angle_spin_box.set_value_no_signal(parameters.get_spread_angle())
	_stop_never_button.set_pressed_no_signal(parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.NEVER)
	_stop_count_button.set_pressed_no_signal(parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.INSTANCE_COUNT)
	_stop_time_button.set_pressed_no_signal(parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.TIME)
	_limit_label.visible = parameters.get_limit_type() != NanoParticleEmitterParameters.LimitType.NEVER
	_limit_instances_spin_box.visible = parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.INSTANCE_COUNT
	_limit_nanoseconds_time_picker.visible = parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.TIME
	_limit_instances_spin_box.set_value_no_signal(parameters.get_stop_emitting_after_count())


func _on_initial_delay_time_picker_time_span_changed(
		in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
			time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	parameters.set_initial_delay_in_nanoseconds(time_in_nanoseconds)


func _on_molecules_per_instance_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_molecules_per_instance(int(in_value))


func _on_instance_rate_time_picker_time_span_changed(
		in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
			time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	parameters.set_instance_rate_time_in_nanoseconds(time_in_nanoseconds)


func _on_initial_speed_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_instance_speed_nanometers_per_picosecond(in_value)


func _on_spread_angle_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_spread_angle(in_value)


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


func _on_limit_instances_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_stop_emitting_after_count(int(in_value))


func _on_limit_nanoseconds_time_picker_time_span_changed(
		in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
			time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	parameters.set_stop_emitting_after_nanoseconds(time_in_nanoseconds)


func _on_load_molecule_from_selection_button_pressed() -> void:
	var _parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	assert("TODO")


func _on_load_molecule_from_library_button_pressed() -> void:
	var _parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	assert("TODO")

