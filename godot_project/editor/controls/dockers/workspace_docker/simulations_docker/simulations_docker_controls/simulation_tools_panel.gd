extends DynamicContextControl

const OpenmmWarningDialog = preload("res://autoloads/openmm/alert_controls/openmm_alert_dialog.tscn")
const _PREWARM_TIME_IN_FRAME_COUNTS = 1
const _DIMMED_ALPHA: float = 0.2
const _SIMULATION_TIME_THRESHOLD = 0.00000001
const _ICONS: Dictionary = {
	start = preload("res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/icons/icon_play_rec.svg"),
	recording = preload("res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/icons/icon_recording.svg"),
	play = preload("res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/icons/icon_playing.svg"),
	pause = preload("res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/icons/icon_pause.svg"),
	playing = preload("res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/icons/icon_playing.svg"),
	paused = preload("res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/icons/icon_pause.svg"),
	play_error = preload("res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/icons/icon_play_error.svg"),
}
const _REPORTS_DROP_ON_ERROR = 1

enum Status {
	INACTIVE,
	PREWARMING,
	PAUSED,
	PLAYING,
	ERROR
}

var _temperature_picker: TemperaturePicker = null
var _time_span_picker: TimeSpanPicker = null
var _spin_box_steps_per_report: SpinBoxSlider = null
var _spin_box_report_count: SpinBoxSlider = null
var _playback_speed_picker: PlaybackSpeedPicker = null
var _button_start_pause: Button = null
var _status_icon: TextureRect = null
var _status_label: Label = null
var _spin_box_timeline: SpinBox = null
var _option_button_timeline_unit: OptionButton = null
var _slider_timeline: HSlider = null
var _relax_before_sim_button: CheckBox = null
var _label_edit_notice: Label = null
var _label_error_notice: Label = null
var _label_empty_notice: Label = null
var _button_revert: Button = null
var _button_end: Button = null
var _button_view_alerts: Button = null
var _open_mm_failure_tracker: OpenMMFailureTracker = null
var _motors_warning_dialog: NanoAcceptDialog = null

var _workspace_context: WorkspaceContext = null
var _status: Status = Status.INACTIVE: set = _set_status
var _total_simulation_len_nanoseconds: float = 0.0
var _finish_prewarming_time: float = 0.0
var _simulation_length_nanoseconds: float = 0.0: set = _set_simulation_length_nanoseconds
var _edit_notice_dimmed: bool = true
var _playback_delta: float = 0.0
var _error_playback_active: bool = false: set = _set_error_playback_active


func should_show(out_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(out_workspace_context)
	_update_view_alerts_button()
	var current_type: CreateObjectParameters.SimulationType = \
		out_workspace_context.create_object_parameters.get_simulation_type()
	if current_type == CreateObjectParameters.SimulationType.MOLECULAR_MECHANICS:
		_update_controls()
		return true
	return false


func _ensure_workspace_initialized(out_workspace_context: WorkspaceContext) -> void:
	if _workspace_context != out_workspace_context:
		_workspace_context = out_workspace_context
		out_workspace_context.about_to_apply_simulation.connect(_on_workspace_context_about_to_apply_simulation)
		out_workspace_context.alerts_panel_visibility_changed.connect(_on_workspace_context_alerts_panel_visibility_changed)
		_open_mm_failure_tracker.set_workspace_context(out_workspace_context)
		# Initialize UI
		var params: SimulationParameters = out_workspace_context.workspace.simulation_parameters
		params.changed.connect(_on_simulation_parameters_changed)
		# Also refresh UI when snapshot state changes
		_workspace_context.history_snapshot_applied.connect(_on_simulation_parameters_changed)
		# Ensure TimeSpanPicker and SimulationParameters enums are in sync
		# This should prevent any future missmatch caused by the modification of any of those 2 classes
		assert(TimeSpanPicker.Unit.FEMTOSECOND == SimulationParameters.PlaybackUnit.Femtoseconds,
				"TimeSpanPicker.Unit and SimulationParameter.PlaybackUnit are out of sync!")
		assert(TimeSpanPicker.Unit.PICOSECOND == SimulationParameters.PlaybackUnit.Picoseconds,
				"TimeSpanPicker.Unit and SimulationParameter.PlaybackUnit are out of sync!")
		assert(TimeSpanPicker.Unit.NANOSECOND == SimulationParameters.PlaybackUnit.Nanoseconds,
				"TimeSpanPicker.Unit and SimulationParameter.PlaybackUnit are out of sync!")
		_on_simulation_parameters_changed()


func _ready() -> void:
	set_physics_process(false)


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_temperature_picker = %TemperaturePicker as TemperaturePicker
		_time_span_picker = %TimeSpanPicker as TimeSpanPicker
		_spin_box_steps_per_report = %SpinBoxStepsPerReport as SpinBoxSlider
		_spin_box_report_count = %SpinBoxReportCount as SpinBoxSlider
		_playback_speed_picker = %PlaybackSpeedPicker as PlaybackSpeedPicker
		_button_start_pause = %ButtonStartPause as Button
		_status_icon = %StatusIcon as TextureRect
		_status_label = %StatusLabel as Label
		_spin_box_timeline = %SpinBoxTimeline as SpinBox
		_option_button_timeline_unit = %OptionButtonTimelineUnit as OptionButton
		_slider_timeline = %SliderTimeline as HSlider
		_relax_before_sim_button = %RelaxBeforeSimButton as CheckBox
		_label_edit_notice = %LabelEditNotice as Label
		_label_error_notice = %LabelErrorNotice as Label
		_label_empty_notice = %LabelEmptyNotice as Label
		_button_revert = %ButtonRevert as Button
		_button_end = %ButtonEnd as Button
		_button_view_alerts = %ButtonViewAlerts as Button
		_open_mm_failure_tracker = %OpenMMFailureTracker as OpenMMFailureTracker
		_motors_warning_dialog = %MotorsWarningDialog as NanoAcceptDialog
		_status = Status.INACTIVE
		_spin_box_timeline.share(_slider_timeline)
		# Note: Step is too small for setting it from Godot inspector
		_spin_box_timeline.step = 0.0001
		_slider_timeline.step = 0.0001
		_label_edit_notice.self_modulate.a = _DIMMED_ALPHA
		set_physics_process(false)
		_relax_before_sim_button.toggled.connect(_on_relax_before_sim_button_toggled)
		_temperature_picker.temperature_changed.connect(_on_temperature_picker_temperature_changed)
		_time_span_picker.time_span_changed.connect(_on_time_span_picker_time_span_changed)
		_spin_box_steps_per_report.value_confirmed.connect(_on_spin_box_steps_per_report_value_confirmed)
		_spin_box_report_count.value_confirmed.connect(_on_spin_box_report_count_value_confirmed)
		_update_estimated_length()
	
		_button_start_pause.pressed.connect(_on_button_start_pause_pressed)
		_spin_box_timeline.focus_entered.connect(_on_spin_box_timeline_focus_entered)
		_slider_timeline.focus_entered.connect(_on_spin_box_timeline_focus_entered)
		_spin_box_timeline.value_changed.connect(_on_spin_box_timeline_value_changed)
		_option_button_timeline_unit.item_selected.connect(_on_option_button_timeline_unit_item_selected)
		_button_revert.pressed.connect(_on_button_revert_pressed)
		_button_end.pressed.connect(_on_button_end_pressed)
		_button_view_alerts.pressed.connect(_on_button_view_alerts_pressed)
		_open_mm_failure_tracker.results_collected.connect(_on_open_mm_failure_tracker_results_collected)


func _on_workspace_context_about_to_apply_simulation() -> void:
	if _status == Status.PLAYING:
		# This ensures _physics_process won't try to seek simulation
		_status = Status.PAUSED


func _on_workspace_context_alerts_panel_visibility_changed(in_is_visible: bool) -> void:
	_button_view_alerts.visible = (not in_is_visible) and _workspace_context.has_alerts()


func _set_status(in_status: Status) -> void:
	if _status == Status.ERROR and in_status != Status.INACTIVE:
		push_warning("You can only jump from an error state to an innactive (reset) state")
	_status = in_status
	set_physics_process(_status == Status.PLAYING)
	if is_instance_valid(_workspace_context):
		_workspace_context.set_simulation_playback_running(_status == Status.PLAYING)
	_update_controls()


func _set_simulation_length_nanoseconds(in_length_nanoseconds: float) -> void:
	_simulation_length_nanoseconds = in_length_nanoseconds
	_update_spin_box_timeline_sufix()
	if _status == Status.PREWARMING and _simulation_length_nanoseconds >= _finish_prewarming_time:
		_status = Status.PLAYING


func _update_spin_box_timeline_sufix() -> void:
	var length_in_playback_unit: float = _nanoseconds_to_playback_unit(_simulation_length_nanoseconds)
	_spin_box_timeline.max_value = length_in_playback_unit
	var unit: int = _option_button_timeline_unit.selected
	var decimals: int = 0
	match unit:
		SimulationParameters.PlaybackUnit.Femtoseconds:
			_spin_box_timeline.suffix = tr("/ %.2f fs") % length_in_playback_unit
			decimals = 2
		SimulationParameters.PlaybackUnit.Picoseconds:
			_spin_box_timeline.suffix = tr("/ %.4f ps") % length_in_playback_unit
			decimals = 4
		SimulationParameters.PlaybackUnit.Nanoseconds:
			_spin_box_timeline.suffix = tr("/ %.6f ns") % length_in_playback_unit
			decimals = 6
		SimulationParameters.PlaybackUnit.Steps:
			var steps_per_report: float = _spin_box_steps_per_report.value
			_spin_box_timeline.suffix = tr("/ %d steps") % (length_in_playback_unit + steps_per_report)
		SimulationParameters.PlaybackUnit.Frames:
			_spin_box_timeline.suffix = tr("/ %d frames") % (length_in_playback_unit + 1)
	
	# Update spinbox minimum size to fit the largest possible string for the current unit and simulation length.
	var font: Font = _spin_box_timeline.get_theme_font("default_font")
	var font_size: int = _spin_box_timeline.get_theme_font_size("font_size")
	var max_string: String = str(length_in_playback_unit).pad_decimals(decimals) + " " + _spin_box_timeline.suffix
	var min_size: Vector2 = font.get_string_size(max_string, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	const SPINBOX_BUTONS_WIDTH: float = 18
	_spin_box_timeline.custom_minimum_size.x = min_size.x + SPINBOX_BUTONS_WIDTH


func _update_controls() -> void:
	_label_edit_notice.visible = _status != Status.ERROR
	_label_error_notice.visible = _status == Status.ERROR
	_label_empty_notice.visible = not _has_valid_atoms()
	match _status:
		Status.INACTIVE:
			_temperature_picker.editable = true
			_time_span_picker.editable = true
			_spin_box_steps_per_report.editable = true
			_spin_box_report_count.editable = true
			_playback_speed_picker.editable = true
			_button_start_pause.icon = _ICONS.start
			_button_start_pause.text = tr("Start")
			_button_start_pause.disabled = false
			_status_icon.texture = _ICONS.paused
			_status_label.text = tr("Stopped")
			_simulation_length_nanoseconds = 0
			_total_simulation_len_nanoseconds = 0.0
			_error_playback_active = false
			_spin_box_timeline.value = 0
			_spin_box_timeline.max_value = _spin_box_timeline.step
			_spin_box_timeline.editable = false
			_slider_timeline.editable = false
			_button_revert.disabled = true
			_button_end.disabled = true
		Status.PREWARMING:
			_temperature_picker.editable = false
			_time_span_picker.editable = false
			_spin_box_steps_per_report.editable = false
			_spin_box_report_count.editable = false
			_playback_speed_picker.editable = true
			_button_start_pause.icon = _ICONS.pause
			_button_start_pause.text = tr("Hold on...")
			_button_start_pause.disabled = true
			_status_icon.texture = _ICONS.recording
			_status_label.text = tr("Preparing")
			_spin_box_timeline.editable = false
			_slider_timeline.editable = false
			_button_revert.disabled = true
			const PREWARM_MANDATORY_TIME: float = 1.5
			# This timeout ensures openmm server has some time to start processing the simulation
			# but is ignored if status advanced to PAUSED or PLAYING
			get_tree().create_timer(PREWARM_MANDATORY_TIME).timeout.connect(func() -> void:
				if _status == Status.PREWARMING:
					_button_revert.disabled = false
			)
		Status.PAUSED:
			_temperature_picker.editable = false
			_time_span_picker.editable = false
			_spin_box_steps_per_report.editable = false
			_spin_box_report_count.editable = false
			_playback_speed_picker.editable = true
			_button_start_pause.icon = _ICONS.play
			_button_start_pause.text = tr("Play")
			_button_start_pause.disabled = false
			_status_icon.texture = _ICONS.paused
			_status_label.text = tr("Paused")
			_spin_box_timeline.editable = true
			_slider_timeline.editable = true
			_button_revert.disabled = false
		Status.PLAYING:
			_temperature_picker.editable = false
			_time_span_picker.editable = false
			_spin_box_steps_per_report.editable = false
			_spin_box_report_count.editable = false
			_playback_speed_picker.editable = true
			_button_start_pause.icon = _ICONS.pause
			_button_start_pause.text = tr("Pause")
			_button_start_pause.disabled = false
			_status_icon.texture = _ICONS.playing
			_status_label.text = tr("Playing")
			_spin_box_timeline.editable = true
			_slider_timeline.editable = true
			_button_revert.disabled = false
		Status.ERROR:
			_temperature_picker.editable = false
			_time_span_picker.editable = false
			_spin_box_steps_per_report.editable = false
			_spin_box_report_count.editable = false
			_playback_speed_picker.editable = false
			_button_start_pause.icon = _ICONS.play_error
			_button_start_pause.text = tr("Play")
			_button_start_pause.disabled = false
			_slider_timeline.editable = true
			if _simulation_length_nanoseconds == 0:
				# Cannot replay animation when no frames have been received
				_button_start_pause.disabled = true
				_slider_timeline.editable = false
			_status_icon.texture = _ICONS.pause
			_status_label.text = tr("❌Error")
			_spin_box_timeline.editable = true
			_button_revert.disabled = false
			_button_end.disabled = true


func _has_valid_atoms() -> bool:
	if not is_instance_valid(_workspace_context):
		return false
	return _workspace_context.has_valid_atoms() or _workspace_context.has_valid_particle_emitters()


func _is_simulation_complete() -> bool:
	# make a string comparison to prevent rounding presition errors
	# comparing floats was causing false negatives
	var complete: bool = ("%.15f" % _simulation_length_nanoseconds) == ("%.15f" % _total_simulation_len_nanoseconds)
	return complete


func _is_playback_complete() -> bool:
	var seek: float = _playback_unit_to_nanoseconds(_spin_box_timeline.value)
	return absf(seek - _total_simulation_len_nanoseconds) < _SIMULATION_TIME_THRESHOLD or seek >= _total_simulation_len_nanoseconds


func _set_error_playback_active(in_enabled: bool) -> void:
	_error_playback_active = in_enabled
	if _status != Status.ERROR:
		return # Error playback can only happen after an error
	if in_enabled:
		_button_start_pause.icon = _ICONS.pause
		_button_start_pause.text = tr("Pause")
	else:
		_button_start_pause.icon = _ICONS.play_error
		_button_start_pause.text = tr("Play")
	if in_enabled and _is_playback_complete():
		_spin_box_timeline.value = 0.0
	
	set_physics_process(in_enabled)
	if is_instance_valid(_workspace_context):
		_workspace_context.set_simulation_playback_running(in_enabled)


func _on_simulation_frame_received(in_frame: float, _in_state: Variant) -> void:
	var time_femtoseconds: float = in_frame * _time_span_picker.time_span_femtoseconds * _spin_box_steps_per_report.value
	var time_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(time_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	_simulation_length_nanoseconds = max(time_nanoseconds, _simulation_length_nanoseconds)
	if _is_simulation_complete():
		_button_end.disabled = true


func _on_simulation_invalid_state_received() -> void:
	_status = Status.ERROR
	# On error, the last report received is dropped. (The amount of reports dropped can
	# be configured with _REPORTS_DROP_ON_ERROR)
	# This last report is filled with exploded atoms that takes a while to render (probably the
	# segmented multimesh that recreates a new segment for each atom since they are so far apart)
	var steps: float = _spin_box_steps_per_report.value
	var report_duration: float = TimeSpanPicker.femtoseconds_to_unit(
			 _time_span_picker.time_span_femtoseconds * steps, TimeSpanPicker.Unit.NANOSECOND)
	_simulation_length_nanoseconds -= report_duration * _REPORTS_DROP_ON_ERROR
	_simulation_length_nanoseconds = max(_simulation_length_nanoseconds, 0.0)
	_total_simulation_len_nanoseconds = _simulation_length_nanoseconds
	_spin_box_timeline.set_value_no_signal(_simulation_length_nanoseconds)


func _on_workspace_context_simulation_finished(out_simulation_data: SimulationData) -> void:
	assert(out_simulation_data.frame_received.is_connected(_on_simulation_frame_received),
			"Received a simulation finished event of an untracked simulation")
	out_simulation_data.frame_received.disconnect(_on_simulation_frame_received)
	_status = Status.INACTIVE


func _on_relax_before_sim_button_toggled(in_button_pressed: bool) -> void:
	var params: SimulationParameters = _workspace_context.workspace.simulation_parameters
	if params.relax_before_start_simulation == in_button_pressed:
		return
	params.relax_before_start_simulation = in_button_pressed
	_workspace_context.snapshot_moment("Set Simulation Setting: Relax model before running mechanical simulation")


func _on_temperature_picker_temperature_changed(_in_magnitude: float, _unit: TemperaturePicker.Unit) -> void:
	var params: SimulationParameters = _workspace_context.workspace.simulation_parameters
	if params.temperature_in_kelvins == _temperature_picker.temperature_kelvins:
		return
	params.temperature_in_kelvins = _temperature_picker.temperature_kelvins
	_workspace_context.snapshot_moment("Set Simulation Setting: Temperature")


func _on_time_span_picker_time_span_changed(_in_magnitude: float, _in_unit: TimeSpanPicker.Unit) -> void:
	_update_estimated_length()
	var params: SimulationParameters = _workspace_context.workspace.simulation_parameters
	if params.step_size_in_femtoseconds == _time_span_picker.time_span_femtoseconds:
		return
	params.step_size_in_femtoseconds = _time_span_picker.time_span_femtoseconds
	_workspace_context.snapshot_moment("Set Simulation Setting: Step Time")


func _on_spin_box_steps_per_report_value_confirmed(in_steps_per_report: float) -> void:
	_update_estimated_length()
	var params: SimulationParameters = _workspace_context.workspace.simulation_parameters
	if params.steps_per_report == int(in_steps_per_report):
		return
	
	params.steps_per_report = int(in_steps_per_report)
	params.total_step_count = int(in_steps_per_report) * int(_spin_box_report_count.value)
	_workspace_context.snapshot_moment("Set Simulation Setting: Steps per Frame")


func _on_spin_box_report_count_value_confirmed(in_reports_count: float) -> void:
	_update_estimated_length()
	var params: SimulationParameters = _workspace_context.workspace.simulation_parameters
	if params.total_step_count == int(_spin_box_steps_per_report.value) * int(in_reports_count):
		return
	params.total_step_count = int(_spin_box_steps_per_report.value) * int(in_reports_count)
	_workspace_context.snapshot_moment("Set Simulation Setting: Frame Count")


func _on_simulation_parameters_changed() -> void:
	var params: SimulationParameters = _workspace_context.workspace.simulation_parameters
	_relax_before_sim_button.set_pressed_no_signal(params.relax_before_start_simulation)
	_temperature_picker.temperature_kelvins = params.temperature_in_kelvins
	_time_span_picker.time_span_femtoseconds = params.step_size_in_femtoseconds
	_spin_box_steps_per_report.set_value_no_signal(params.steps_per_report)
	_option_button_timeline_unit.select(params.playback_unit)
	_spin_box_report_count.set_value_no_signal(params.total_step_count / float(params.steps_per_report))


func _update_estimated_length() -> void:
	var step_size_in_femtoseconds: float = _time_span_picker.time_span_femtoseconds
	var steps_per_report: float = _spin_box_steps_per_report.value
	var report_count: float = _spin_box_report_count.value
	var unit: int = _option_button_timeline_unit.selected
	var playback_unit_is_time: bool = TimeSpanPicker.Unit.find_key(unit) != null
	
	if playback_unit_is_time:
		var report_time_in_femtoseconds: float = \
				step_size_in_femtoseconds * steps_per_report
		var estimated_time_in_femtoseconds: float = \
				report_time_in_femtoseconds * report_count
		var report_time_in_desired_unit: float = TimeSpanPicker.femtoseconds_to_unit(
				report_time_in_femtoseconds, unit as TimeSpanPicker.Unit)
		var estimated_time_in_desired_unit: float = TimeSpanPicker.femtoseconds_to_unit(
				estimated_time_in_femtoseconds, unit as TimeSpanPicker.Unit)
		var unit_suffix: String = TimeSpanPicker.UNIT_SYMBOL[unit]
		_spin_box_steps_per_report.suffix = tr(&"steps ({0} {1})").format([report_time_in_desired_unit, unit_suffix])
		_spin_box_report_count.suffix = tr(&"frames ({0} {1})").format([estimated_time_in_desired_unit, unit_suffix])
	else:
		var total_steps: int = int(steps_per_report * report_count)
		_spin_box_steps_per_report.suffix = tr(&"steps")
		_spin_box_report_count.suffix = tr(&"frames ({0} steps)").format([total_steps])


func _on_button_start_pause_pressed() -> void:
	assert(is_instance_valid(_workspace_context), "Invalid workspace context")
	match _status:
		Status.INACTIVE:
			if _workspace_context.ignored_warnings.emitters_affected_by_motors == false:
				var emitters_affected: bool = WorkspaceUtils.has_emitters_affected_by_motors(_workspace_context)
				if emitters_affected:
					var warning_promise: Promise = _workspace_context.show_warning_dialog(
							tr("One or more particle emitters will be affected by motors,\n" +
							"overriding their initial velocity and potentially affecting the " +
							"stability of the System."), tr("Continue"), tr("Cancel") , &"emitters_affected_by_motors", true)
					await warning_promise.wait_for_fulfill()
					if warning_promise.get_result() == false:
						# "Cancel" button selected
						return
			assert(!_workspace_context.is_simulating(), "A simulation is already running")
			
			_workspace_context.clear_alerts()
			_update_view_alerts_button()
			
			if not _has_valid_atoms():
				_label_empty_notice.visible = true
				return
			if _workspace_context.has_motors() and FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_VIRTUAL_MOTORS_SIMULATION_WARNING):
				_motors_warning_dialog.popup_centered()
				await _motors_warning_dialog.closed
			
			# Copy simulation config to Workspace's simulation params
			var params: SimulationParameters = _workspace_context.workspace.simulation_parameters
			params.relax_before_start_simulation = _relax_before_sim_button.button_pressed
			params.temperature_in_kelvins = _temperature_picker.temperature_kelvins
			params.step_size_in_femtoseconds = _time_span_picker.time_span_femtoseconds
			params.steps_per_report = int(_spin_box_steps_per_report.value)
			params.total_step_count = int(_spin_box_steps_per_report.value) * int(_spin_box_report_count.value)
			
			if _relax_before_sim_button.button_pressed and WorkspaceUtils.can_relax(_workspace_context, false):
				# Disabling the button is not necesary at all
				# I am doing this to catch any case in the future where promise returned by
				# _relax_before_simulation() is leaking in the future without being fulfilled under
				# certain circunstance. If that happens the UI will become responsive, but the start/pause
				# button will be disabled, and will be reported as a bug.
				_button_start_pause.disabled = true
				var promise: Promise = _relax_before_simulation()
				await promise.wait_for_fulfill()
				_button_start_pause.disabled = false
				if not promise.get_result():
					# Relaxation failed or was cancelled
					return
			var new_simulation: SimulationData = OpenMM.request_start_simulation(_workspace_context, params)
			new_simulation.frame_received.connect(_on_simulation_frame_received)
			new_simulation.invalid_state_received.connect(_on_simulation_invalid_state_received)
			_workspace_context.start_simulating(new_simulation)
			_workspace_context.simulation_finished.connect(_on_workspace_context_simulation_finished.bind(new_simulation), CONNECT_ONE_SHOT)
			_status = Status.PREWARMING
			await new_simulation.start_promise.wait_for_fulfill()
			if not _workspace_context.is_simulating():
				# Aborted during the async process
				return
			if new_simulation.start_promise.has_error():
				_open_mm_failure_tracker.track_openmm_simulation_request(new_simulation)
				_workspace_context.abort_simulation_if_running()
				var alert_dialog : AcceptDialog = OpenmmWarningDialog.instantiate()
				alert_dialog.set_detailed_message(new_simulation.start_promise.get_error())
				Engine.get_main_loop().root.add_child(alert_dialog)
				_status = Status.INACTIVE
			elif new_simulation.was_aborted():
				return
			else:
				var report_time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
						params.step_size_in_femtoseconds,
						TimeSpanPicker.Unit.NANOSECOND
					) * params.steps_per_report
				_total_simulation_len_nanoseconds = report_time_in_nanoseconds * _spin_box_report_count.value
				_finish_prewarming_time = report_time_in_nanoseconds * _PREWARM_TIME_IN_FRAME_COUNTS
				_finish_prewarming_time = min(_total_simulation_len_nanoseconds, _finish_prewarming_time)
				_spin_box_timeline.step = _nanoseconds_to_playback_unit(report_time_in_nanoseconds)
				_slider_timeline.step = _nanoseconds_to_playback_unit(report_time_in_nanoseconds)
				_button_end.disabled = false
		Status.PREWARMING:
			# Nothing to do here
			return
		Status.PAUSED:
			if _is_playback_complete():
				# Replay from position 0
				_spin_box_timeline.value = 0
			_status = Status.PLAYING
		Status.PLAYING:
			_status = Status.PAUSED
		Status.ERROR:
			_error_playback_active = not _error_playback_active


func _relax_before_simulation() -> Promise:
	var promise: Promise = Promise.new()
	var request: RelaxRequest = WorkspaceUtils.relax(_workspace_context, _temperature_picker.temperature_kelvins, false, true, true, false)
	_track_relax_request(promise, request)
	return promise


func _on_relax_request_retrying(out_new_request: RelaxRequest, out_promise: Promise) -> void:
	_track_relax_request(out_promise, out_new_request)


func _on_relax_request_retry_discarded(out_promise: Promise) -> void:
	# Intentionally ignored by the user, proceed with simulation
	out_promise.fulfill(true)


func _track_relax_request(out_promise: Promise, out_request: RelaxRequest) -> void:
	out_request.retrying.connect(_on_relax_request_retrying.bind(out_promise))
	out_request.retry_discarded.connect(_on_relax_request_retry_discarded.bind(out_promise))
	await out_request.promise.wait_for_fulfill()
	if out_request.retried:
		out_request.retrying.disconnect(_on_relax_request_retrying)
		out_request.retry_discarded.disconnect(_on_relax_request_retry_discarded)
		# the new relax request will be tracked
		return
	if out_request.promise.has_error():
		out_request.retrying.disconnect(_on_relax_request_retrying)
		out_request.retry_discarded.disconnect(_on_relax_request_retry_discarded)
		_open_mm_failure_tracker.track_openmm_relax_request(out_request)
		out_promise.fulfill(false)
		return
	var error: String = await _workspace_context.atoms_relaxation_finished
	if not error.is_empty():
		out_promise.fulfill(false)
		return
	if not out_request.bad_tetrahedral_bonds_detected or _workspace_context.ignored_warnings.invalid_relaxed_tetrahedral_structure:
		# Success or user decided he doesn't care
		out_promise.fulfill(true)


func _on_spin_box_timeline_focus_entered() -> void:
	if _status == Status.PLAYING:
		_status = Status.PAUSED


func _on_spin_box_timeline_value_changed(in_value: float) -> void:
	var should_dim_notice: bool = \
			in_value == 0.0 \
			or not is_instance_valid(_workspace_context) \
			or !_workspace_context.is_simulating()
	if _edit_notice_dimmed != should_dim_notice:
		_edit_notice_dimmed = should_dim_notice
		var tween: Tween = create_tween()
		var target_alpha: float = _DIMMED_ALPHA if should_dim_notice else 1.0
		tween.tween_property(_label_edit_notice, "self_modulate:a", target_alpha, 0.1)
	if not is_instance_valid(_workspace_context) or not _workspace_context.is_simulating():
		_status = Status.INACTIVE
		return
	var has_started_recording: bool = _total_simulation_len_nanoseconds > 0.0
	if has_started_recording and _is_playback_complete():
		if _error_playback_active:
			_error_playback_active = false
		else:
			_status = Status.PAUSED
	var frame: float = _playback_unit_to_frames(_spin_box_timeline.value)
	_workspace_context.seek_simulation(frame)


func _playback_unit_to_nanoseconds(in_value: float) -> float:
	var unit: int = _option_button_timeline_unit.selected
	var playback_unit_is_time: bool = TimeSpanPicker.Unit.find_key(unit) != null
	
	if playback_unit_is_time:
		var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(
				in_value, unit as TimeSpanPicker.Unit)
		var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
				time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
		return time_in_nanoseconds
	else:
		var advanced_steps: float = 0
		match unit:
			SimulationParameters.PlaybackUnit.Steps:
				advanced_steps = in_value
			SimulationParameters.PlaybackUnit.Frames:
				var steps_per_report: float = _spin_box_steps_per_report.value
				advanced_steps = in_value * steps_per_report
		var step_size_in_femtoseconds: float = _time_span_picker.time_span_femtoseconds
		var time_in_femtoseconds: float = advanced_steps * step_size_in_femtoseconds
		var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
				time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
		return time_in_nanoseconds


func _playback_unit_to_frames(in_value: float) -> float:
	var unit: int = _option_button_timeline_unit.selected
	var playback_unit_is_time: bool = TimeSpanPicker.Unit.find_key(unit) != null
	
	if playback_unit_is_time:
		var step_size_in_femtoseconds: float = _time_span_picker.time_span_femtoseconds
		var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(
				in_value, unit as TimeSpanPicker.Unit)
		var advanced_steps: float = time_in_femtoseconds / step_size_in_femtoseconds
		var advanced_frames: float = floorf(advanced_steps / _spin_box_steps_per_report.value)
		return advanced_frames
	else:
		var advanced_frames: float = 0
		match unit:
			SimulationParameters.PlaybackUnit.Steps:
				var advanced_steps: float = in_value
				advanced_frames = floorf(advanced_steps / _spin_box_steps_per_report.value)
			SimulationParameters.PlaybackUnit.Frames:
				advanced_frames = in_value
		return advanced_frames

func _nanoseconds_to_playback_unit(in_nanoseconds: float) -> float:
	var unit: int = _option_button_timeline_unit.selected
	var playback_unit_is_time: bool = TimeSpanPicker.Unit.find_key(unit) != null
	
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(
			in_nanoseconds, TimeSpanPicker.Unit.NANOSECOND)
	if playback_unit_is_time:
		var time_in_desired_unit: float = TimeSpanPicker.femtoseconds_to_unit(
				time_in_femtoseconds, unit as TimeSpanPicker.Unit)
		return time_in_desired_unit
	else:
		var step_size_in_femtoseconds: float = _time_span_picker.time_span_femtoseconds
		var advanced_steps: float = time_in_femtoseconds / step_size_in_femtoseconds
		if unit == SimulationParameters.PlaybackUnit.Steps:
			return advanced_steps
		else:
			var steps_per_report: float = _spin_box_steps_per_report.value
			return advanced_steps / steps_per_report


func _on_option_button_timeline_unit_item_selected(in_index: int) -> void:
	_update_estimated_length()
	var params: SimulationParameters = _workspace_context.workspace.simulation_parameters
	if params.playback_unit == in_index:
		return
	# Note: This change does not produce Undo/Redo
	var current_time_in_nanoseconds: float = _playback_unit_to_nanoseconds(_spin_box_timeline.value)
	params.playback_unit = in_index as SimulationParameters.PlaybackUnit
	var current_time_in_playback_unit: float = _nanoseconds_to_playback_unit(current_time_in_nanoseconds)
	_spin_box_timeline.set_value(current_time_in_playback_unit)
	var report_time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
			params.step_size_in_femtoseconds,
			TimeSpanPicker.Unit.NANOSECOND
		) * params.steps_per_report
	_spin_box_timeline.step = _nanoseconds_to_playback_unit(report_time_in_nanoseconds)
	_slider_timeline.step = _nanoseconds_to_playback_unit(report_time_in_nanoseconds)
	_update_spin_box_timeline_sufix()


func _on_button_revert_pressed() -> void:
	if is_instance_valid(_workspace_context):
		if _workspace_context.ignored_warnings.abort_simulation == false:
			const ACCEPT_WHEN_PRESSING_DONT_REMIND_ME_AGAIN := true
			var message: String = tr("Are you sure you want to abort this simulation?")
			if _is_simulation_complete() or _status == Status.ERROR:
				message = tr("By resetting this simulation, data collected in the timeline will be lost. Proceed?")
			var promise: Promise = _workspace_context.show_warning_dialog(
					message, tr("OK"), tr("Cancel"),
					&"abort_simulation", ACCEPT_WHEN_PRESSING_DONT_REMIND_ME_AGAIN)
			await promise.wait_for_fulfill()
			if not promise.get_result():
				return
		_workspace_context.abort_simulation_if_running()
		_status = Status.INACTIVE


func _on_button_end_pressed() -> void:
	if not is_instance_valid(_workspace_context):
		return
	if _workspace_context.ignored_warnings.end_simulation == false:
		const ACCEPT_WHEN_PRESSING_DONT_REMIND_ME_AGAIN := true
		var message: String = tr("Are you sure you want to stop processing this simulation?")
		var promise: Promise = _workspace_context.show_warning_dialog(
				message, tr("OK"), tr("Cancel"),
				&"end_simulation", ACCEPT_WHEN_PRESSING_DONT_REMIND_ME_AGAIN)
		await promise.wait_for_fulfill()
		if not promise.get_result():
			return
	
	_workspace_context.end_simulation_if_running()
	_button_end.disabled = true
	_total_simulation_len_nanoseconds = _simulation_length_nanoseconds
	
	if _status == Status.PLAYING:
		_status = Status.PAUSED


func _on_button_view_alerts_pressed() -> void:
	if _workspace_context.has_alerts():
		_workspace_context.show_alerts_panel()


func _update_view_alerts_button() -> void:
	var alerts_count: int = _workspace_context.get_alerts_count()
	_button_view_alerts.visible = (not _workspace_context.is_alerts_panel_visible()) and alerts_count > 0
	_button_view_alerts.text = tr_n(&"View %d alert", &"View %d alerts", alerts_count) % alerts_count


func _on_open_mm_failure_tracker_results_collected() -> void:
	_update_view_alerts_button()


func _physics_process(_delta: float) -> void:
	_playback_delta += _spin_box_timeline.step * _playback_speed_picker.get_playback_speed()
	if _playback_delta >= _spin_box_timeline.step:
		_spin_box_timeline.set_value(min(_spin_box_timeline.value + _playback_delta, _spin_box_timeline.max_value))
		_playback_delta = 0.0
