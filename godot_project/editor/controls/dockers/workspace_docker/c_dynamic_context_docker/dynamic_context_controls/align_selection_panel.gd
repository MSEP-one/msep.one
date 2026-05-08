extends DynamicContextControl

var _relative_to_option_button: OptionButton
var _world_plane_container: HBoxContainer
var _plane_button_group: ButtonGroup
var _pick_plane_button: Button
var _align_rotation_button: Button
var _align_h_begin_button: Button
var _align_h_center_button: Button
var _align_h_end_button: Button
var _align_v_begin_button: Button
var _align_v_center_button: Button
var _align_v_end_button: Button


var _workspace_context: WorkspaceContext = null
var _align_selection_parameters: AlignSelectionParameters


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_ALIGN_SELECTION_PANEL) == false:
		return false
	_ensure_workspace_initialized(in_workspace_context)
	_update_ui()
	return _align_selection_parameters.can_align_selection()


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context != null:
		return
	_workspace_context = in_workspace_context
	_align_selection_parameters = in_workspace_context.align_selection_parameters
	_align_selection_parameters.align_relative_to_changed.connect(_on_align_relative_to_changed)
	_align_selection_parameters.alignment_tools_enabled_changed.connect(func(enabled: bool) -> void:
		# TODO: Delete this print when signal is actually used to draw group boxes
		print("alignment_tools_enabled: ", "ON" if enabled else "OFF")
	)
	visibility_changed.connect(_on_visibility_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_relative_to_option_button = %RelativeToOptionButton as OptionButton
		_world_plane_container = %WorldPlaneContainer as HBoxContainer
		_plane_button_group = (%XY as Button).button_group
		_pick_plane_button = %PickPlaneButton as Button
		_align_rotation_button = %AlignRotationButton as Button
		_align_h_begin_button = %AlignHBeginButton as Button
		_align_h_center_button = %AlignHCenterButton as Button
		_align_h_end_button = %AlignHEndButton as Button
		_align_v_begin_button = %AlignVBeginButton as Button
		_align_v_center_button = %AlignVCenterButton as Button
		_align_v_end_button = %AlignVEndButton as Button
		_relative_to_option_button.item_selected.connect(_on_relative_to_option_button_item_selected)
		_plane_button_group.pressed.connect(_on_plane_button_group_pressed)
		_pick_plane_button.pressed.connect(_on_pick_plane_button_pressed)
		_align_rotation_button.pressed.connect(_on_align_rotation_button_pressed)
		_align_h_begin_button.pressed.connect(_on_align_h_button_pressed.bind(HORIZONTAL_ALIGNMENT_LEFT))
		_align_h_center_button.pressed.connect(_on_align_h_button_pressed.bind(HORIZONTAL_ALIGNMENT_CENTER))
		_align_h_end_button.pressed.connect(_on_align_h_button_pressed.bind(HORIZONTAL_ALIGNMENT_RIGHT))
		_align_v_begin_button.pressed.connect(_on_align_v_button_pressed.bind(VERTICAL_ALIGNMENT_TOP))
		_align_v_center_button.pressed.connect(_on_align_v_button_pressed.bind(VERTICAL_ALIGNMENT_CENTER))
		_align_v_end_button.pressed.connect(_on_align_v_button_pressed.bind(VERTICAL_ALIGNMENT_BOTTOM))


func _on_align_relative_to_changed() -> void:
	_update_ui()


func _on_visibility_changed() -> void:
	_align_selection_parameters.set_alignment_tools_enabled(is_visible_in_tree())


func _update_ui() -> void:
	_world_plane_container.visible = _align_selection_parameters.get_align_relative_to() in [
		AlignSelectionParameters.AlignRelativeTo.WORLD_PLANE,
		AlignSelectionParameters.AlignRelativeTo.CAMERA_PLANE
	]
	_pick_plane_button.visible = _align_selection_parameters.get_align_relative_to() \
		== AlignSelectionParameters.AlignRelativeTo.SPECIFIC_BOX_PLANE
	_align_rotation_button.disabled = not _align_selection_parameters.can_align_rotations()
	_align_h_begin_button.disabled = not _align_selection_parameters.can_align_positions()
	_align_h_center_button.disabled = not _align_selection_parameters.can_align_positions()
	_align_h_end_button.disabled = not _align_selection_parameters.can_align_positions()
	_align_v_begin_button.disabled = not _align_selection_parameters.can_align_positions()
	_align_v_center_button.disabled = not _align_selection_parameters.can_align_positions()
	_align_v_end_button.disabled = not _align_selection_parameters.can_align_positions()


func _on_relative_to_option_button_item_selected(in_index: int) -> void:
	_align_selection_parameters.set_align_relative_to(
		in_index as AlignSelectionParameters.AlignRelativeTo
	)


func _on_plane_button_group_pressed(in_button: Button) -> void:
	_align_selection_parameters.set_align_to_what_plane(
		in_button.get_index() as AlignSelectionParameters.WorldPlane
	)


func _on_pick_plane_button_pressed() -> void:
	_align_selection_parameters.start_picking_obb()


func _on_align_rotation_button_pressed() -> void:
	push_warning("TODO: _on_align_rotation_button_pressed()")


func _on_align_h_button_pressed(in_alignment: HorizontalAlignment) -> void:
	push_warning("TODO: _on_align_h_button_pressed(%d)" % in_alignment)


func _on_align_v_button_pressed(in_alignment: VerticalAlignment) -> void:
	push_warning("TODO: _on_align_v_button_pressed(%d)" % in_alignment)
