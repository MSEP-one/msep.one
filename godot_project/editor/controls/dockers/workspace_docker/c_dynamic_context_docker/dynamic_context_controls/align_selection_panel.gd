extends DynamicContextControl

const AlignSelectionGroupingPolicy = AlignSelectionParameters.AlignSelectionGroupingPolicy
const AlignRelativeTo = AlignSelectionParameters.AlignRelativeTo
const WorldPlane = AlignSelectionParameters.WorldPlane
const BoxFace = AlignSelectionParameters.BoxFace

enum Alignment {
	IGNORE = -1,
	BEGIN,
	CENTER,
	END,
}

var _alignable_boxes_tree: Tree
var _relative_to_option_button: OptionButton
var _world_plane_container: HBoxContainer
var _plane_button_group: ButtonGroup
var _specific_box_container: HBoxContainer
var _align_to_box_option_button: OptionButton
var _align_to_face_button: Button
var _advanced_align_to_face_button: Button
var _grouping_policy_option_button: OptionButton
var _align_position_button: Button
var _align_rotation_button: Button
var _align_camera_button: Button
var _advanced_align_settings_popup: PopupPanel

var _workspace_context: WorkspaceContext = null
var _align_selection_parameters: AlignSelectionParameters
static var _empty_texture := AtlasTexture.new() # Behaves as a 0x0 texture


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(in_workspace_context)
	if _align_selection_parameters.can_align_selection():
		_update_ui()
	return _align_selection_parameters.can_align_selection()


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context != null:
		return
	_workspace_context = in_workspace_context
	_align_selection_parameters = in_workspace_context.align_selection_parameters
	_align_selection_parameters.align_relative_to_changed.connect(_on_align_relative_to_changed)
	_workspace_context.history_changed.connect(_on_workspace_context_history_changed)
	visibility_changed.connect(_on_visibility_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_alignable_boxes_tree = %AlignableBoxesTree as Tree
		_relative_to_option_button = %RelativeToOptionButton as OptionButton
		_world_plane_container = %WorldPlaneContainer as HBoxContainer
		_plane_button_group = (%XY as Button).button_group
		
		_alignable_boxes_tree.button_clicked.connect(_on_alignable_boxes_tree_button_clicked)
		_relative_to_option_button.item_selected.connect(_on_relative_to_option_button_item_selected)
		_plane_button_group.pressed.connect(_on_plane_button_group_pressed)
		
		_specific_box_container = %SpecificBoxContainer as HBoxContainer
		_align_to_box_option_button = %AlignToBoxOptionButton as OptionButton
		_align_to_face_button = %AlignToFaceButton as Button
		_advanced_align_to_face_button = %AdvancedAlignToFaceButton as Button
		
		_align_to_box_option_button.item_selected.connect(_on_align_to_box_option_button_item_selected)
		_align_to_face_button.pressed.connect(_on_align_to_face_button_pressed)
		_advanced_align_to_face_button.pressed.connect(_on_advanced_align_to_face_button_pressed)
		
		_grouping_policy_option_button = %GroupingPolicyOptionButton as OptionButton
		_grouping_policy_option_button.item_selected.connect(_on_grouping_policy_option_button_item_selected)
		
		_align_position_button = %AlignPositionButton as Button
		_align_rotation_button = %AlignRotationButton as Button
		_align_position_button.pressed.connect(_on_align_position_button_pressed)
		_align_rotation_button.pressed.connect(_on_align_rotation_button_pressed)
		
		_align_camera_button = %AlignCameraButton as Button
		_align_camera_button.pressed.connect(_on_align_camera_button_pressed)
		
		_advanced_align_settings_popup = %AdvancedAlignSettingsPopup as PopupPanel


func _on_align_relative_to_changed() -> void:
	ScriptUtils.call_deferred_once(_update_ui)


func _on_workspace_context_history_changed() -> void:
	ScriptUtils.call_deferred_once(_update_ui)


func _on_visibility_changed() -> void:
	_align_selection_parameters.set_alignment_tools_enabled(is_visible_in_tree())


func _update_ui() -> void:
	_update_tree()
	_world_plane_container.visible = _align_selection_parameters.get_align_relative_to() in [
		AlignRelativeTo.WORLD_PLANE,
		AlignRelativeTo.CAMERA_PLANE
	]
	_specific_box_container.visible = _align_selection_parameters.get_align_relative_to() \
		== AlignRelativeTo.SPECIFIC_BOX_PLANE
	_align_rotation_button.disabled = not _align_selection_parameters.can_align_rotations()
	var can_align_camera: bool = true
	if _align_selection_parameters.get_align_relative_to() == AlignRelativeTo.CAMERA_PLANE:
		can_align_camera = false
	elif _align_selection_parameters.get_align_relative_to() == AlignRelativeTo.SPECIFIC_BOX_PLANE:
		var reference_box: AlignableOBB = _align_selection_parameters.get_align_obb_target()
		if reference_box == null or reference_box.align_to_face == BoxFace.UNDEFINED:
			can_align_camera = false
	_align_camera_button.disabled = not can_align_camera
	_align_position_button.disabled = not _align_selection_parameters.can_align_positions()


var _last_alignable_boxes: Array[AlignableOBB] = []
func _update_tree() -> void:
	var alignable_boxes: Array[AlignableOBB] = _align_selection_parameters.get_alignable_boxes()
	if alignable_boxes == _last_alignable_boxes:
		if not _last_alignable_boxes.is_empty():
			_refresh_tree_items()
		return
	_last_alignable_boxes = alignable_boxes
	const COL_0 = 0
	const COL_1 = 1
	_alignable_boxes_tree.set_column_title(COL_0, tr(&"Object"))
	_alignable_boxes_tree.set_column_title(COL_1, tr(&"Face to Align"))
	_alignable_boxes_tree.set_column_expand(COL_1, false)
	var current_box: AlignableOBB = _align_selection_parameters.get_align_obb_target()
	_alignable_boxes_tree.clear()
	_align_to_box_option_button.clear()
	_alignable_boxes_tree.hide_root = true
	var root: TreeItem = _alignable_boxes_tree.create_item()
	for box: AlignableOBB in alignable_boxes:
		var is_current: bool = box == current_box and current_box != null
		var item: TreeItem = _alignable_boxes_tree.create_item(root)
		item.set_metadata(COL_0, box)
		item.set_text(COL_0, box.description)
		if is_current:
			item.set_custom_color(COL_0, Color.YELLOW)
		item.add_button(COL_1, _empty_texture if is_current else _get_box_face_icon(box.selected_face),
			-1, false, "" if is_current else tr(&"Select next face"))
		item.set_button_disabled(COL_1, 0, is_current)
		var show_more_button: bool = \
			_align_selection_parameters.is_advanced_settings_enabled() and not is_current
		if show_more_button:
			if item.get_button_count(COL_1) < 2:
				const ICON_SETTINGS_MENU = preload("uid://dtfepgaagdcj5")
				item.add_button(COL_1, ICON_SETTINGS_MENU)
			var MORE_OPTIONS_BUTTON_INDEX: int = 1
			item.set_button_disabled(COL_1, MORE_OPTIONS_BUTTON_INDEX, box.selected_face == BoxFace.UNDEFINED)
		_align_to_box_option_button.add_item(box.description)
		if is_current:
			_align_to_box_option_button.select(_align_to_box_option_button.item_count - 1)
			_align_to_face_button.icon = _get_box_face_icon(box.align_to_face)


func _refresh_tree_items() -> void:
	const COL_0 = 0
	const COL_1 = 1
	const BUTTON_IDX = 0
	var current_box: AlignableOBB = _align_selection_parameters.get_align_obb_target()
	var checked_icon: Texture2D = null#get_theme_icon(&"radio_checked", &"CheckBox")
	var unchecked_icon: Texture2D = null#get_theme_icon(&"radio_unchecked", &"CheckBox")
	for item: TreeItem in _alignable_boxes_tree.get_root().get_children():
		var item_box: AlignableOBB = item.get_metadata(COL_0) as AlignableOBB
		assert(item_box)
		var is_current: bool = item_box == current_box and current_box != null
		if item.get_button_count(COL_1) == 0:
			print("No button: ", item.get_text(COL_0))
		if is_current:
			item.set_button(COL_1, BUTTON_IDX, _empty_texture)
			item.set_custom_color(COL_0, Color.YELLOW)
			_align_to_face_button.icon = _get_box_face_icon(item_box.align_to_face)
		else:
			item.set_button(COL_1, BUTTON_IDX, _get_box_face_icon(item_box.selected_face))
			item.clear_custom_color(COL_0)
		var show_more_button: bool = \
			_align_selection_parameters.is_advanced_settings_enabled() and not is_current
		const MORE_OPTIONS_BUTTON_INDEX: int = 1
		if show_more_button:
			if item.get_button_count(COL_1) < 2:
				const ICON_SETTINGS_MENU = preload("uid://dtfepgaagdcj5")
				item.add_button(COL_1, ICON_SETTINGS_MENU)
			item.set_button_disabled(COL_1, MORE_OPTIONS_BUTTON_INDEX, item_box.selected_face == BoxFace.UNDEFINED)
		else:
			if item.get_button_count(COL_1) >= 2:
				item.erase_button(COL_1, MORE_OPTIONS_BUTTON_INDEX)
		if _align_selection_parameters.get_align_relative_to() == AlignRelativeTo.SPECIFIC_BOX_PLANE:
			item.set_icon(COL_0, checked_icon if is_current else unchecked_icon)
		else:
			item.set_icon(COL_0, null)


func _on_alignable_boxes_tree_button_clicked(item: TreeItem, _column: int, id: int, mouse_button_index: int) -> void:
	const COL_0 = 0
	const ID_CYCLE_FACE = 0
	const ID_ADVANCED_OPTIONS = 1
	var item_box: AlignableOBB = item.get_metadata(COL_0) as AlignableOBB
	assert(item_box)
	assert(item_box != _align_selection_parameters.get_align_obb_target())
	if id == ID_CYCLE_FACE:
		var advance_dir: int = 0
		match mouse_button_index:
			MOUSE_BUTTON_LEFT:
				advance_dir = +1
			MOUSE_BUTTON_RIGHT:
				advance_dir = -1
		if advance_dir == 0:
			return
		item_box.advance_selected_face(advance_dir)
		# Force redraw preview
		_update_ui()
		_align_selection_parameters.request_redraw_preview()
	if id == ID_ADVANCED_OPTIONS:
		_advanced_align_settings_popup.setup(item_box, _align_selection_parameters)
		const COL_1 = 1
		var button_rect: Rect2 = _alignable_boxes_tree.get_item_area_rect(item, COL_1, ID_ADVANCED_OPTIONS)
		button_rect.position += _alignable_boxes_tree.global_position
		_advanced_align_settings_popup.popup_attached_to_global_rect(button_rect)


func _get_box_face_icon(selected_face: BoxFace) -> Texture2D:
	const ICONS: Dictionary[BoxFace, Texture2D] = {
		BoxFace.UNDEFINED : preload("uid://dr6k8q285dgls"),
		BoxFace.FRONT_BACK : preload("uid://d16yxekfb4k3h"),
		BoxFace.TOP_BOTTOM : preload("uid://de1hnqihu4ugw"),
		BoxFace.LEFT_RIGHT : preload("uid://c01w40g4dq4eg"),
	}
	return ICONS[selected_face]


func _on_relative_to_option_button_item_selected(in_index: int) -> void:
	_align_selection_parameters.set_align_relative_to(
		in_index as AlignRelativeTo
	)


func _on_plane_button_group_pressed(in_button: Button) -> void:
	_align_selection_parameters.set_align_to_what_plane(
		in_button.get_index() as WorldPlane
	)


func _on_align_to_box_option_button_item_selected(index: int) -> void:
	var alignable_boxes: Array[AlignableOBB] = _align_selection_parameters.get_alignable_boxes()
	assert(index >= 0 and index < alignable_boxes.size())
	_align_selection_parameters.set_specific_obb(alignable_boxes[index])


func _on_align_to_face_button_pressed() -> void:
	var current_box: AlignableOBB = _align_selection_parameters.get_align_obb_target()
	assert(current_box)
	current_box.advance_align_to_face(+1)
	_refresh_tree_items()
	_align_selection_parameters.request_redraw_preview()


func _on_advanced_align_to_face_button_pressed() -> void:
	_advanced_align_settings_popup.setup(
		_align_selection_parameters.get_align_obb_target(),
		_align_selection_parameters
	)
	_advanced_align_settings_popup.popup_attached_to_control(_advanced_align_to_face_button)


func _on_grouping_policy_option_button_item_selected(index: int) -> void:
	_align_selection_parameters.set_align_selection_grouping_policy(index as AlignSelectionGroupingPolicy)


func _on_align_rotation_button_pressed() -> void:
	var align_basis: Basis
	var relative_to: AlignRelativeTo = _align_selection_parameters.get_align_relative_to()
	var alignable_boxes: Array[AlignableOBB] = _align_selection_parameters.get_alignable_boxes()
	var something_changed: bool = false
	match relative_to:
		AlignRelativeTo.WORLD_PLANE, AlignRelativeTo.CAMERA_PLANE:
			align_basis = Basis()
			if relative_to == AlignRelativeTo.CAMERA_PLANE:
				align_basis = _workspace_context.get_camera_global_transform().basis
			var plane: WorldPlane = _align_selection_parameters.get_align_to_what_plane()
			match plane:
				WorldPlane.XY:
					pass
				WorldPlane.XZ:
					align_basis = align_basis.rotated(align_basis[0], -PI * 0.5)
				WorldPlane.YZ:
					align_basis = align_basis.rotated(align_basis[1], PI * 0.5)
			for i: int in alignable_boxes.size():
				something_changed = something_changed or alignable_boxes[i].align_rotation_to_basis(align_basis)
		AlignRelativeTo.SPECIFIC_BOX_PLANE:
			var align_target: AlignableOBB = _align_selection_parameters.get_align_obb_target()
			for i: int in alignable_boxes.size():
				something_changed = something_changed or alignable_boxes[i].align_rotation_to_box(align_target)
	if something_changed:
		_workspace_context.snapshot_moment("Align Selection Rotation")
	_update_ui()


func _on_align_camera_button_pressed() -> void:
	var align_basis: Basis
	var relative_to: AlignRelativeTo = _align_selection_parameters.get_align_relative_to()
	match relative_to:
		AlignRelativeTo.WORLD_PLANE:
			align_basis = Basis()
			if relative_to == AlignRelativeTo.CAMERA_PLANE:
				align_basis = _workspace_context.get_camera_global_transform().basis
			var plane: WorldPlane = _align_selection_parameters.get_align_to_what_plane()
			match plane:
				WorldPlane.XY:
					pass
				WorldPlane.XZ:
					align_basis = align_basis.rotated(align_basis[0], -PI * 0.5)
				WorldPlane.YZ:
					align_basis = align_basis.rotated(align_basis[1], PI * 0.5)
		AlignRelativeTo.SPECIFIC_BOX_PLANE:
			align_basis = _align_selection_parameters.get_align_obb_target().transform.basis
			var face: BoxFace = _align_selection_parameters.get_align_obb_target().selected_face
			match face:
				BoxFace.FRONT_BACK:
					pass
				BoxFace.TOP_BOTTOM:
					align_basis = align_basis.rotated(align_basis[0], -PI * 0.5)
				BoxFace.LEFT_RIGHT:
					align_basis = align_basis.rotated(align_basis[1], PI * 0.5)
		AlignRelativeTo.CAMERA_PLANE:
			assert(false, "Cannot align camera to camera's plane")
			return
	var orientation_widget: Control = (
		_workspace_context.get_editor_viewport()
		.get_orientation_widget()
		.get_node_or_null("DrawOrientationWidget")
	)
	orientation_widget.snap_to_rotation(align_basis.get_euler())


func _on_align_position_button_pressed() -> void:
	assert(_align_selection_parameters.get_align_relative_to() == AlignRelativeTo.SPECIFIC_BOX_PLANE,
		"Cannot align position to global planes, they dont have boundaries")
	var reference_obb: AlignableOBB = _align_selection_parameters.get_align_obb_target()
	var alignable_boxes: Array[AlignableOBB] = _align_selection_parameters.get_alignable_boxes()
	var something_changed: bool = false
	for i: int in alignable_boxes.size():
		var obb: OBB = alignable_boxes[i]
		something_changed = something_changed or obb.align_position_to(reference_obb)
	
	if something_changed:
		_workspace_context.snapshot_moment("Align Selection Position")
		_update_ui()
