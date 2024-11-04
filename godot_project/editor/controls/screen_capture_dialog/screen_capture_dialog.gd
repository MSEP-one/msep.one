extends ConfirmationDialog


enum SizePresets {
	RES_MATCH_EDITOR,
	RES_CUSTOM,
	RES_LD,
	RES_HD,
	RES_2K,
	RES_4K,
	RES_5K,
	RES_6K,
	RES_8K,
}


enum {
	_PREVIEW_SCALE_FIT    = 0,
	_PREVIEW_SCALE_EXPAND = 1
}


const SIZE_PRESETS_MAP: Dictionary = {
	SizePresets.RES_LD: Vector2i(854, 480),
	SizePresets.RES_HD: Vector2i(1280, 720),
	SizePresets.RES_2K: Vector2i(2048, 1080),
	SizePresets.RES_4K: Vector2i(4096, 2160),
	SizePresets.RES_5K: Vector2i(5120, 2700),
	SizePresets.RES_6K: Vector2i(6144, 3160),
	SizePresets.RES_8K: Vector2i(8192, 4320)
}
const _DEFAULT_ENVIRONMENT: Environment = preload("res://editor/rendering/resources/world_environment.tres")
const _AUTOGEN_FILE_NAME_META: StringName = &"___autogen_filename___"

var _is_about_to_popup: bool = false

# Size Settings
@onready var _option_button_size_preset: OptionButton = %OptionButtonSizePreset
@onready var _spin_box_slider_width: SpinBox = %SpinBoxSliderWidth
@onready var _spin_box_slider_height: SpinBox = %SpinBoxSliderHeight
# Crop Settings
@onready var _check_button_crop: CheckButton = %CheckButtonCrop
@onready var _panel_container_crop: PanelContainer = %PanelContainerCrop
@onready var _spin_box_slider_h_offset: SpinBoxSlider  = %SpinBoxSliderHOffset
@onready var _spin_box_slider_v_offset: SpinBoxSlider = %SpinBoxSliderVOffset
@onready var _spin_box_slider_crop_width: SpinBoxSlider = %SpinBoxSliderCropWidth
@onready var _spin_box_slider_crop_height: SpinBoxSlider = %SpinBoxSliderCropHeight
# Background Settings
@onready var _radio_background_environment: CheckBox = %RadioBackgroundEnvironment
@onready var _radio_background_transparent: CheckBox = %RadioBackgroundTransparent
@onready var _radio_background_color: CheckBox = %RadioBackgroundColor
@onready var _color_picker_button_background_color: ColorPickerButton = %ColorPickerButtonBackgroundColor
@onready var _button_group_preview_background: ButtonGroup = _radio_background_color.button_group
# Preview
@onready var _sub_viewport_preview: SubViewport = %SubViewportPreview
@onready var _preview_camera_3d: Camera3D = _sub_viewport_preview.get_camera_3d()
@onready var _preview_world_environment: WorldEnvironment = %PreviewWorldEnvironment
@onready var _environment_custom_color: Environment = _preview_world_environment.environment
@onready var _button_fit: Button = %ButtonFit
@onready var _button_1_to_1: Button = %Button1to1
@onready var _button_group_preview_scale: ButtonGroup = _button_1_to_1.button_group
@onready var _switch_preview_scale: TabContainer = %SwitchPreviewScale
@onready var _texture_rects_capture_preview: Array[TextureRect] = [
	%TextureRectCapturePreviewFit, %TextureRectCapturePreviewUnscaled
]
# Save
@onready var _save_file_dialog: NanoFileDialog = %SaveFileDialog as NanoFileDialog
# Confirmation
@onready var _resolution_confirmation: ConfirmationDialog

var prev_size_preset: SizePresets = SizePresets.RES_MATCH_EDITOR
var high_resolution_rendering_confirmed: bool = false
var workspace_snapshot: Dictionary


func _init() -> void:
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_option_button_size_preset = %OptionButtonSizePreset
		_spin_box_slider_width = %SpinBoxSliderWidth
		_spin_box_slider_height = %SpinBoxSliderHeight
		_check_button_crop = %CheckButtonCrop
		_spin_box_slider_h_offset = %SpinBoxSliderHOffset
		_spin_box_slider_v_offset = %SpinBoxSliderVOffset
		_spin_box_slider_crop_width = %SpinBoxSliderCropWidth
		_spin_box_slider_crop_height = %SpinBoxSliderCropHeight
		_radio_background_environment = %RadioBackgroundEnvironment
		_radio_background_transparent = %RadioBackgroundTransparent
		_radio_background_color = %RadioBackgroundColor
		_color_picker_button_background_color = %ColorPickerButtonBackgroundColor
		_button_group_preview_background = _radio_background_color.button_group
		_sub_viewport_preview = %SubViewportPreview
		_preview_camera_3d = _sub_viewport_preview.get_camera_3d()
		_preview_world_environment = %PreviewWorldEnvironment
		_environment_custom_color = _preview_world_environment.environment
		_button_fit = %ButtonFit
		_button_1_to_1 = %Button1to1
		_button_group_preview_scale = _button_1_to_1.button_group
		_switch_preview_scale = %SwitchPreviewScale
		_texture_rects_capture_preview = [
			%TextureRectCapturePreviewFit, %TextureRectCapturePreviewUnscaled
		]
		_save_file_dialog = %SaveFileDialog
		_resolution_confirmation = %ResolutionConfirmationDialog
		
		for preview in _texture_rects_capture_preview:
			preview.crop_rect_changed.connect(_on_texture_rect_capture_preview_crop_rect_changed)
		_check_button_crop.toggled.connect(_on_crop_toggle_change)
		_spin_box_slider_h_offset.value_changed.connect(_on_spin_box_slider_h_offset_value_changed)
		_spin_box_slider_v_offset.value_changed.connect(_on_spin_box_slider_v_offset_value_changed)
		_spin_box_slider_crop_width.value_changed.connect(_on_spin_box_slider_crop_width_value_changed)
		_spin_box_slider_crop_height.value_changed.connect(_on_spin_box_slider_crop_height_value_changed)


func _ready() -> void:
	window_input.connect(_on_window_input)
	about_to_popup.connect(_on_about_to_popup)
	confirmed.connect(_on_confirmed)
	visibility_changed.connect(_on_visibility_changed)
	# Watch editor size change to maintain resolution up to date when using SizePresets.RES_MATCH_EDITOR
	get_tree().root.size_changed.connect(_on_main_window_size_changed)
	_option_button_size_preset.item_selected.connect(_on_option_button_size_preset_item_selected)
	_spin_box_slider_width.value_changed.connect(_on_spin_box_slider_width_value_changed)
	_spin_box_slider_height.value_changed.connect(_on_spin_box_slider_height_value_changed)
	_button_group_preview_scale.pressed.connect(_on_button_group_preview_scale_pressed)
	_button_group_preview_background.pressed.connect(_on_button_group_preview_background_pressed)
	_color_picker_button_background_color.color_changed.connect(_on_color_picker_button_background_color_color_changed)
	_save_file_dialog.file_selected.connect(_on_save_file_dialog_file_selected)
	_save_file_dialog.current_path = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("")


func _on_window_input(in_event: InputEvent) -> void:
	if Editor_Utils.process_quit_request(in_event, self):
		return
	if in_event.is_action_pressed(&"close_view", false, true):
		hide()


func _on_about_to_popup() -> void:
	_is_about_to_popup = true
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	assert(workspace_context != null)
	var workspace_viewport: WorkspaceEditorViewport = workspace_context.get_editor_viewport()
	_sub_viewport_preview.world_3d = workspace_viewport.find_world_3d()
	var workspace_camera_3d: Camera3D = workspace_viewport.get_camera_3d()
	_set_remote_camera(workspace_camera_3d)
	_on_option_button_size_preset_item_selected(_option_button_size_preset.get_selected_id())
	# Store existing selection and deselect everything
	workspace_snapshot = workspace_context.create_state_snapshot()
	workspace_context.clear_all_selection()
	_is_about_to_popup = false


func _set_remote_camera(in_camera_3d: Camera3D) -> void:
	assert(in_camera_3d)
	var camera_properties: Array[Dictionary] = in_camera_3d.get_property_list()
	# Copy all properties from workspace camera to preview camera
	for property in camera_properties:
		if property.name in [&"script", &"name", &"owner", &"environment", &"cull_mask"]:
			continue
		var value: Variant = in_camera_3d.get(property.name)
		_preview_camera_3d.set(property.name, value)


func _on_confirmed() -> void:
	if _save_file_dialog.current_file.is_empty():
		var date_time: String = Time.get_datetime_string_from_system()
		date_time = date_time.replace(":", "-")
		_save_file_dialog.current_file = "capture_%s.png" % date_time
		_save_file_dialog.set_meta(_AUTOGEN_FILE_NAME_META, _save_file_dialog.current_file)
	_save_file_dialog.popup_centered_ratio()


# Restore the previous selection when the popup is closed
func _on_visibility_changed() -> void:
	if visible:
		return # Popup was opened, ignore
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	assert(workspace_context != null)
	workspace_context.apply_state_snapshot(workspace_snapshot)
	workspace_snapshot.clear()


func _on_main_window_size_changed() -> void:
	# Note: this method is connected on ready, so it's safe to assume
	#+_option_button_size_preset is not null
	if _option_button_size_preset.get_selected_id() == SizePresets.RES_MATCH_EDITOR \
		and MolecularEditorContext.get_current_workspace_context() != null:
			_on_option_button_size_preset_item_selected(SizePresets.RES_MATCH_EDITOR)


func _on_option_button_size_preset_item_selected(in_id: int) -> void:
	if not high_resolution_rendering_confirmed and in_id >= SizePresets.RES_4K:
		_resolution_confirmation.popup_centered()
		_resolution_confirmation.always_on_top = true
		high_resolution_rendering_confirmed = await(_resolution_confirmation.closed)
		if not high_resolution_rendering_confirmed:
			in_id = prev_size_preset
			_option_button_size_preset.select(prev_size_preset)
	
	prev_size_preset = in_id as SizePresets
	_sub_viewport_preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	if in_id == SizePresets.RES_CUSTOM:
		_spin_box_slider_width.editable = true
		_spin_box_slider_height.editable = true
		return
	_spin_box_slider_width.editable = false
	_spin_box_slider_height.editable = false
	var new_resolution := Vector2i(640, 480) # safeward to ensure a non zero value
	if in_id == SizePresets.RES_MATCH_EDITOR:
		var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
		var workspace_viewport: WorkspaceEditorViewport = workspace_context.get_editor_viewport()
		new_resolution = workspace_viewport.size
	else:
		new_resolution = SIZE_PRESETS_MAP[in_id]
	_spin_box_slider_width.set_value(new_resolution.x)
	_spin_box_slider_width.queue_redraw()
	_spin_box_slider_height.set_value(new_resolution.y)
	_spin_box_slider_height.queue_redraw()
	_spin_box_slider_h_offset.max_value = new_resolution.x
	_spin_box_slider_v_offset.max_value = new_resolution.y
	_spin_box_slider_h_offset.value = 0.0
	_spin_box_slider_v_offset.value = 0.0
	_spin_box_slider_crop_width.value = new_resolution.x
	_spin_box_slider_crop_height.value = new_resolution.y


func _on_spin_box_slider_width_value_changed(in_width: int) -> void:
	# MATCH_EDITR Preset can make this slider change when the window is not visible
	if not visible and not _is_about_to_popup:
		return
	
	var nmb_of_pixels_in_2k_res: int = 2048 * 1080
	var is_high_resolution_render: bool = _sub_viewport_preview.size.y * in_width > nmb_of_pixels_in_2k_res
	if is_high_resolution_render and not high_resolution_rendering_confirmed:
		_resolution_confirmation.popup_centered()
		_resolution_confirmation.always_on_top = true
		high_resolution_rendering_confirmed = await(_resolution_confirmation.closed)
		if not high_resolution_rendering_confirmed:
			_spin_box_slider_width.set_value_no_signal(_sub_viewport_preview.size.x)
			return
	
	_sub_viewport_preview.size.x = in_width
	_sub_viewport_preview.render_target_update_mode = SubViewport.UPDATE_ONCE


func _on_spin_box_slider_height_value_changed(in_height: int) -> void:
	# MATCH_EDITR Preset can make this slider change when the window is not visible
	if not visible and not _is_about_to_popup:
		return
	
	var nmb_of_pixels_in_2k_res: int = 2048 * 1080
	var is_high_resolution_render: bool = _sub_viewport_preview.size.x * in_height > nmb_of_pixels_in_2k_res
	if is_high_resolution_render and not high_resolution_rendering_confirmed:
		_resolution_confirmation.popup_centered()
		_resolution_confirmation.always_on_top = true
		high_resolution_rendering_confirmed = await(_resolution_confirmation.closed)
		if not high_resolution_rendering_confirmed:
			_spin_box_slider_height.set_value_no_signal(_sub_viewport_preview.size.y)
			return
		high_resolution_rendering_confirmed = true
	
	_sub_viewport_preview.size.y = in_height
	_sub_viewport_preview.render_target_update_mode = SubViewport.UPDATE_ONCE


func _on_button_group_preview_scale_pressed(in_button: Button) -> void:
	match in_button:
		_button_fit:
			_switch_preview_scale.current_tab = _PREVIEW_SCALE_FIT
		_button_1_to_1:
			_switch_preview_scale.current_tab = _PREVIEW_SCALE_EXPAND
		_:
			assert(false, "Unknown button was added to _button_group_preview_scale")
	_sub_viewport_preview.render_target_update_mode = SubViewport.UPDATE_ONCE


func _on_button_group_preview_background_pressed(_in_button: Button) -> void:
	_update_preview_background()


func _on_color_picker_button_background_color_color_changed(_in_color: Color) -> void:
	_update_preview_background()


func _update_preview_background() -> void:
	match _button_group_preview_background.get_pressed_button():
		_radio_background_environment:
			_sub_viewport_preview.transparent_bg = false
			_preview_camera_3d.environment = _DEFAULT_ENVIRONMENT
		_radio_background_transparent:
			_sub_viewport_preview.transparent_bg = true
			_preview_camera_3d.environment = null
		_radio_background_color:
			_sub_viewport_preview.transparent_bg = false
			_environment_custom_color.background_color = _color_picker_button_background_color.color
			_preview_camera_3d.environment = _environment_custom_color
	_sub_viewport_preview.render_target_update_mode = SubViewport.UPDATE_ONCE


func _on_texture_rect_capture_preview_crop_rect_changed(in_rect: Rect2) -> void:
	_spin_box_slider_crop_width.value = in_rect.size.x
	_spin_box_slider_crop_height.value = in_rect.size.y
	_spin_box_slider_h_offset.value = in_rect.position.x
	_spin_box_slider_v_offset.value = in_rect.position.y


func _on_crop_toggle_change(in_new_value: bool) -> void:
	for preview in _texture_rects_capture_preview:
		preview.crop_enabled = in_new_value
	_panel_container_crop.visible = in_new_value


func _on_spin_box_slider_h_offset_value_changed(in_new_value: float) -> void:
	for preview in _texture_rects_capture_preview:
		preview.crop_h_offset = in_new_value
		_spin_box_slider_crop_width.max_value = preview.texture.get_size().x - in_new_value


func _on_spin_box_slider_v_offset_value_changed(in_new_value: float) -> void:
	for preview in _texture_rects_capture_preview:
		preview.crop_v_offset = in_new_value
		_spin_box_slider_crop_height.max_value = preview.texture.get_size().y - in_new_value


func _on_spin_box_slider_crop_width_value_changed(in_new_value: float) -> void:
	for preview in _texture_rects_capture_preview:
		preview.crop_width = in_new_value


func _on_spin_box_slider_crop_height_value_changed(in_new_value: float) -> void:
	for preview in _texture_rects_capture_preview:
		preview.crop_height = in_new_value


func _on_save_file_dialog_file_selected(in_path: String) -> void:
	if in_path.is_empty():
		return
	var capture_image: Image = _sub_viewport_preview.get_texture().get_image()
	if _check_button_crop.button_pressed:
		capture_image = capture_image.get_region(Rect2i(
			int(_spin_box_slider_h_offset.value),
			int(_spin_box_slider_v_offset.value),
			int(_spin_box_slider_crop_width.value),
			int(_spin_box_slider_crop_height.value)
		))
	var capture_texture := ImageTexture.create_from_image(capture_image)
	ResourceSaver.save(capture_texture, in_path)
	if _save_file_dialog.get_meta(_AUTOGEN_FILE_NAME_META, String()) == _save_file_dialog.current_file:
		_save_file_dialog.current_file = String()
	hide()
