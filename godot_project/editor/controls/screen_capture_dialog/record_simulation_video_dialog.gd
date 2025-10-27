extends "./screen_capture_dialog.gd"


var _time_scale_picker: TimeSpanPicker
var _time_visible_button: CheckButton
var _time_position_option_button: OptionButton
var _time_label_font_size_spinbox: SpinBoxSlider

var _framerate_spin_box: SpinBoxSlider
var _quality_preset_option_button: OptionButton
var _crf_spin_box: SpinBoxSlider

var _crop_rect_control: MarginContainer
var _time_label: Label
var _video_time_elapsed_label: Label
var _time_slider: HSlider

var _recording_overlay: CanvasLayer
var _stop_button: Button
var _abort_button: Button
var _progress_bar: ProgressBar
var _progress_label: Label

var _label_unit: TimeSpanPicker.Unit:
	get: return _time_scale_picker.current_unit

var _workspace_context: WorkspaceContext
var _is_baking: bool:
	get(): return _recorder != null
var _stopped: bool = false
var _aborted: bool = false
var _simulation_elapsed_time_femtoseconds: float = 0.0
var _recorder: VideoRecorder = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_update_mode = SubViewport.UpdateMode.UPDATE_ALWAYS
		_time_scale_picker = %TimeScalePicker as TimeSpanPicker
		_time_visible_button = %TimeVisibleButton as CheckButton
		_time_position_option_button = %TimePositionOptionButton as OptionButton
		_time_label_font_size_spinbox = %TimeLabelFontSizeSpinbox as SpinBoxSlider
		
		_framerate_spin_box = %FramerateSpinBox as SpinBoxSlider
		_quality_preset_option_button = %QualityPresetOptionButton as  OptionButton
		_crf_spin_box = %CrfSpinBox as  SpinBoxSlider
		
		_crop_rect_control = %CropRectControl as MarginContainer
		_time_label = %TimeLabel as Label
		_video_time_elapsed_label = %VideoTimeElapsedLabel as Label
		_time_slider = %TimeSlider as HSlider
		
		_recording_overlay = %RecordingOverlay as CanvasLayer
		_stop_button = %StopButton as Button
		_abort_button = %AbortButton as Button
		_progress_bar = %ProgressBar as ProgressBar
		_progress_label = %ProgressLabel as Label
		
		crop_settings_changed.connect(_on_crop_settings_changed)
		_time_scale_picker.time_span_changed.connect(_on_time_scale_picker_time_span_changed.unbind(2))
		_time_visible_button.toggled.connect(_update_time_label_layout.unbind(1))
		_time_position_option_button.item_selected.connect(_update_time_label_layout.unbind(1))
		_time_label_font_size_spinbox.value_changed.connect(_on_time_label_font_size_spinbox_value_changed)
		_time_slider.value_changed.connect(_on_time_slider_value_changed)
		_stop_button.pressed.connect(_on_stop_button_pressed)
		_abort_button.pressed.connect(_abort_button_pressed)


# OVERRIDE
func _on_visibility_changed() -> void:
	if !visible and _is_baking == true:
		# prevent the window from hiding
		set_deferred(&"visible", true)
		DisplayServer.beep()
		return
	else:
		super._on_visibility_changed()


# OVERRIDE
func _on_about_to_popup() -> void:
	super._on_about_to_popup()
	_workspace_context = MolecularEditorContext.get_current_workspace_context()
	_setup_save_file_dialog()
	_setup_time_slider()
	_setup_quality_preset_option_button()
	_update_time_label_layout()
	_update_time_label_text()
	_update_progress()


# OVERRIDE
func _on_confirmed() -> void:
	if _save_file_dialog.current_file.is_empty():
		var date_time: String = Time.get_datetime_string_from_system()
		date_time = date_time.replace(":", "-")
		_save_file_dialog.current_file = "capture_%s.mp4" % [date_time]
		_save_file_dialog.set_meta(_AUTOGEN_FILE_NAME_META, _save_file_dialog.current_file)
	_save_file_dialog.popup_centered_ratio()


# OVERRIDE
func _on_save_file_dialog_file_selected(in_path: String) -> void:
	if in_path.is_empty():
		return
	_bake_video(in_path)


func _on_crop_toggle_change(in_new_value: bool) -> void:
	super._on_crop_toggle_change(in_new_value)
	_update_time_label_layout()


func _on_crop_settings_changed() -> void:
	_update_time_label_layout()


func _on_time_scale_picker_time_span_changed() -> void:
	_update_time_label_text()


func _on_time_label_font_size_spinbox_value_changed(in_value: float) -> void:
	_time_label.add_theme_font_size_override(&"font_size", int(in_value))


func _on_time_slider_value_changed(in_frame: float) -> void:
	_workspace_context.seek_simulation(in_frame)
	_update_time_label_text()


func _on_stop_button_pressed() -> void:
	_stopped = true
	_stop_button.disabled = true
	_abort_button.disabled = true


func _abort_button_pressed() -> void:
	_aborted = true
	_stop_button.disabled = true
	_abort_button.disabled = true
	_recorder.abort()


func _setup_save_file_dialog() -> void:
	assert(VideoRecorderFFMPEG.is_available(), "ffmpeg failed to install")
	_save_file_dialog.filters = VideoRecorderFFMPEG.get_file_format_filters()


func _setup_time_slider() -> void:
	var simulation_frame_count: int = _workspace_context.get_simulation_frame_count()
	_time_slider.set_block_signals(true)
	_time_slider.min_value = 0.0
	_time_slider.max_value = simulation_frame_count - 1 # last index is size-1
	_time_slider.step = 1.0
	_time_slider.value = _workspace_context.get_simulation_current_frame()
	_time_slider.share(_progress_bar)
	_time_slider.set_block_signals(false)


func _setup_quality_preset_option_button() -> void:
	const PRESETS: PackedStringArray = [
		"ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"
	]
	const DEFAULT: String = "fast"
	
	_quality_preset_option_button.clear()
	for i in PRESETS.size():
		var preset: String = PRESETS[i]
		_quality_preset_option_button.add_item(preset)
		if preset == DEFAULT:
			_quality_preset_option_button.select(i)


func _update_time_label_layout() -> void:
	if _time_label.visible != _time_visible_button.button_pressed:
		_time_label.visible = _time_visible_button.button_pressed
		# This ensures text is updated when visibility changes
		_update_time_label_text()
	if _check_button_crop.button_pressed:
		var crop_rect := Rect2i(
			int(_spin_box_slider_h_offset.value),
			int(_spin_box_slider_v_offset.value),
			int(_spin_box_slider_crop_width.value),
			int(_spin_box_slider_crop_height.value)
		)
		_crop_rect_control.set_anchor_and_offset(SIDE_LEFT, 0, crop_rect.position.x)
		_crop_rect_control.set_anchor_and_offset(SIDE_TOP, 0, crop_rect.position.y)
		var offset := Vector2i(_crop_rect_control.get_viewport_rect().size) - crop_rect.end
		_crop_rect_control.set_anchor_and_offset(SIDE_RIGHT, 1, -offset.x)
		_crop_rect_control.set_anchor_and_offset(SIDE_BOTTOM, 1, -offset.y)
	else:
		_crop_rect_control.set_anchor_and_offset(SIDE_LEFT, 0, 0)
		_crop_rect_control.set_anchor_and_offset(SIDE_TOP, 0, 0)
		_crop_rect_control.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
		_crop_rect_control.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	var alignment: Control.LayoutPreset = _time_position_option_button.get_selected_id() as Control.LayoutPreset
	if alignment in [Control.LayoutPreset.PRESET_TOP_LEFT, Control.LayoutPreset.PRESET_BOTTOM_LEFT]:
		# align left
		_time_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		# align right
		_time_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	if alignment in [Control.LayoutPreset.PRESET_TOP_LEFT, Control.LayoutPreset.PRESET_TOP_RIGHT]:
		# align top
		_time_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		# align bottom
		_time_label.size_flags_vertical = Control.SIZE_SHRINK_END


func _update_time_label_text() -> void:
	if _time_visible_button.button_pressed == false:
		return
	var current_simulation_frame: float = _time_slider.value
	var sim_params: SimulationParameters = _workspace_context.workspace.simulation_parameters
	var femtoseconds_per_simulation_frame: float = sim_params.step_size_in_femtoseconds * sim_params.steps_per_report
	var elapsed_femtoseconds: float = current_simulation_frame * femtoseconds_per_simulation_frame
	var elapsed: float = TimeSpanPicker.femtoseconds_to_unit(elapsed_femtoseconds, _label_unit)
	_time_label.text = "%.02f %s" % [elapsed, TimeSpanPicker.UNIT_SYMBOL[_label_unit]]
	
	var last_simulation_drame: float = _time_slider.max_value
	var femtoseconds_per_video_second: float = _time_scale_picker.time_span_femtoseconds
	var simulation_length_femtoseconds: float = last_simulation_drame * femtoseconds_per_simulation_frame
	var video_length: float = simulation_length_femtoseconds / femtoseconds_per_video_second
	var elapsed_video_time: float = elapsed_femtoseconds / femtoseconds_per_video_second
	_video_time_elapsed_label.text = "%s / %s" % [_format_time(elapsed_video_time), _format_time(video_length)]


func _format_time(in_seconds: float) -> String:
	var minutes: int = floori(in_seconds / 60.0)
	var seconds: int = int(in_seconds) - minutes * 60
	return ("%02d:%02d" % [minutes, seconds])


func _update_progress() -> void:
	if _is_baking == false:
		_recording_overlay.hide()
		return
	_recording_overlay.show()
	if _recorder.is_converting():
		_progress_bar.indeterminate = true
		_progress_label.text = "Converting Video ..."
	else:
		_progress_bar.indeterminate = false
		var progress: float = (_progress_bar.value / _progress_bar.max_value) * 100
		_progress_label.text = "Processing: %d%%" % int(progress)


func _bake_video(in_filepath: String) -> void:
	# Prevent inputs while baking
	_recording_overlay.show()
	gui_release_focus()
	_stopped = false
	_aborted = false
	_stop_button.disabled = false
	_abort_button.disabled = false
	var resolution: Vector2i = _sub_viewport_preview.size
	if _check_button_crop.button_pressed:
		resolution.x = int(_spin_box_slider_crop_width.value)
		resolution.y = int(_spin_box_slider_crop_height.value)
	assert(VideoRecorderFFMPEG.is_available(), "Cannot record videos of %s format without ffmpeg installed in the system")
	var quality_preset: String = _quality_preset_option_button.text
	var constant_rate_factor: int = int(_crf_spin_box.value)
	_recorder = VideoRecorderFFMPEG.new(in_filepath, resolution, int(_framerate_spin_box.value),
		quality_preset, constant_rate_factor)
	
	var femtoseconds_per_video_second: float = _time_scale_picker.time_span_femtoseconds
	var femtoseconds_per_video_frame: float = femtoseconds_per_video_second / _framerate_spin_box.value
	var sim_params: SimulationParameters = _workspace_context.workspace.simulation_parameters
	var femtoseconds_per_simulation_frame: float = sim_params.step_size_in_femtoseconds * sim_params.steps_per_report
	assert(femtoseconds_per_video_frame > 0.0, "Invalid delta time")
	var simulation_frame_count := int(_time_slider.max_value)
	_simulation_elapsed_time_femtoseconds = 0.0
	var length_in_femtoseconds: float = simulation_frame_count * femtoseconds_per_simulation_frame
	while _simulation_elapsed_time_femtoseconds <= length_in_femtoseconds and not (_stopped or _aborted):
		var simulation_frame: int = int(_simulation_elapsed_time_femtoseconds / femtoseconds_per_simulation_frame)
		# This will in cause the simulation to be updated
		_time_slider.value = simulation_frame
		# ensure rendered
		await get_tree().process_frame
		var capture_image: Image = _sub_viewport_preview.get_texture().get_image()
		if _check_button_crop.button_pressed:
			capture_image = capture_image.get_region(Rect2i(
				int(_spin_box_slider_h_offset.value),
				int(_spin_box_slider_v_offset.value),
				int(_spin_box_slider_crop_width.value),
				int(_spin_box_slider_crop_height.value)
			))
		_recorder.add_frame(capture_image)
		_update_progress()
		# ensure encoded
		await get_tree().process_frame
		_simulation_elapsed_time_femtoseconds += femtoseconds_per_video_frame
	if _aborted:
		_recorder = null
		_recording_overlay.hide()
		return
	_recorder.finish()
	while _recorder.is_running():
		# Wait until video convertion finishes
		_update_progress()
		await get_tree().process_frame
	_recorder = null
	_update_progress()
	_recording_overlay.hide()
	if _save_file_dialog.get_meta(_AUTOGEN_FILE_NAME_META, String()) == _save_file_dialog.current_file:
		_save_file_dialog.current_file = String()
	hide()
