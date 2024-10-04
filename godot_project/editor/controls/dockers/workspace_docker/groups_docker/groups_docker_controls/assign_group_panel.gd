extends DynamicContextControl



const _UNGROUPED_GROUP_ID_AND_INDEX: int = 0

var _check_box_add_to_new: CheckBox
var _line_edit_new_structure_name: LineEdit
var _nano_structure_picker_new_structure_parent: NanoGroupPicker
var _check_box_add_to_existing: CheckBox
var _nano_structure_picker_assign_existing: NanoGroupPicker
var _label_select_only_notice: InfoLabel
var _button_set_structure: Button
var _recursion_check_dialog: NanoAcceptDialog

var _workspace_context: WorkspaceContext = null
var _highest_index: int = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_check_box_add_to_new = %CheckBoxAddToNew as CheckBox
		_line_edit_new_structure_name = %LineEditNewGroupName as LineEdit
		_nano_structure_picker_new_structure_parent = %NanoGroupPickerNewGroupParent as NanoGroupPicker
		_check_box_add_to_existing = %CheckBoxAddToExisting as CheckBox
		_nano_structure_picker_assign_existing = %NanoGroupPickerAssignExisting as NanoGroupPicker
		_label_select_only_notice = %LabelSelectOnlyNotice as InfoLabel
		_button_set_structure = %ButtonSetStructure as Button
		_recursion_check_dialog = %RecursionCheckDialog as NanoAcceptDialog
		_line_edit_new_structure_name.text_changed.connect(_on_line_edit_new_structure_name_text_changed)
		_check_box_add_to_new.toggled.connect(_on_check_box_add_to_new_toggled)
		_check_box_add_to_existing.toggled.connect(_on_check_box_add_to_existing_toggled)
		_button_set_structure.pressed.connect(_on_button_set_structure_pressed)
		_label_select_only_notice.meta_clicked.connect(_on_label_select_only_notice_meta_clicked)
		visibility_changed.connect(_on_visibility_changed)


func should_show(out_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(out_workspace_context)
	return out_workspace_context.has_selection()


func _on_visibility_changed() -> void:
	if is_instance_valid(_workspace_context) and is_visible_in_tree():
		ScriptUtils.call_deferred_once(_update_controls)
		ScriptUtils.call_deferred_once(_update_apply_button_state)


func _ensure_workspace_initialized(out_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == null:
		_workspace_context = out_workspace_context
		_highest_index = out_workspace_context.workspace.get_nmb_of_structures()
		_nano_structure_picker_new_structure_parent.initialize(out_workspace_context)
		_nano_structure_picker_assign_existing.initialize(out_workspace_context)
		_nano_structure_picker_new_structure_parent.nano_structure_clicked.connect(_on_structure_picker_nano_structure_clicked)
		_nano_structure_picker_assign_existing.nano_structure_clicked.connect(_on_structure_picker_nano_structure_clicked)
		out_workspace_context.structure_added.connect(_on_nano_structure_added)
		out_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		out_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
		out_workspace_context.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)
		_update_controls()
		_update_apply_button_state()


func _on_structure_picker_nano_structure_clicked(_in_structure_id: int) -> void:
	ScriptUtils.call_deferred_once(_update_apply_button_state)


func _on_nano_structure_added(in_nano_structure: NanoStructure) -> void:
	if in_nano_structure.is_virtual_object():
		# Virtual objects are not meant to be shown in the graph
		return
	var need_to_update_structure_name: bool = \
			_line_edit_new_structure_name.text == _generate_new_structure_name()
	_highest_index += 1
	if need_to_update_structure_name:
		_line_edit_new_structure_name.text = _generate_new_structure_name()
	ScriptUtils.call_deferred_once(_update_controls)


func _on_workspace_context_selection_in_structures_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_update_apply_button_state)


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_update_controls)
	ScriptUtils.call_deferred_once(_update_apply_button_state)


func _on_workspace_context_history_snapshot_applied() -> void:
	_update_controls()
	_update_apply_button_state()


func _on_check_box_add_to_new_toggled(in_button_pressed: bool) -> void:
	%NewGroupSettingsContainer.visible = in_button_pressed
	%AssignExistingSettingsContainer.visible = not in_button_pressed


func _on_check_box_add_to_existing_toggled(in_button_pressed: bool) -> void:
	%NewGroupSettingsContainer.visible = not in_button_pressed
	%AssignExistingSettingsContainer.visible = in_button_pressed


func _on_button_set_structure_pressed() -> void:
	if _check_box_add_to_new.button_pressed:
		if _do_recursion_check(_nano_structure_picker_new_structure_parent.selected_id):
			_add_selection_to_new_structure()
		else:
			return
	else:
		if _do_recursion_check(_nano_structure_picker_assign_existing.selected_id):
			_add_selection_to_existing_structure()
		else:
			return
		
	_line_edit_new_structure_name.text = _generate_new_structure_name()


# Performs group nesting check, if check fails will prompt and error message
# returns true of it is possible to proceed with creation of groups
func _do_recursion_check(in_parent_structure_id: int) -> bool:
	var parent_structure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(in_parent_structure_id)
	var parent_context: StructureContext = _workspace_context.get_nano_structure_context(parent_structure)
	if !parent_context.is_editable() || parent_context == _workspace_context.get_current_structure_context():
		# Any selected atom will be moved to the new structure withoput reparenting
		return true
	if parent_context.has_selection(true):
		_recursion_check_dialog.dialog_text = tr("'{0}' can't be made its own parent. Please choose a different parent or remove it from selection."
		).format([parent_structure.get_structure_name()])
		_recursion_check_dialog.popup_centered()
		return false
	return true


func _on_line_edit_new_structure_name_text_changed(_new_text: String) -> void:
	ScriptUtils.call_deferred_once(_update_apply_button_state)


func _update_apply_button_state() -> void:
	var new_group_name_is_empty: bool = _line_edit_new_structure_name.text.is_empty()
	var can_move_molecule: bool = WorkspaceUtils.can_move_selection_to_another_group(_workspace_context)
	var active_picker: NanoGroupPicker = _get_active_group_picker()
	var has_target: bool = active_picker.selected_id != -1
	var can_apply: bool = has_target and can_move_molecule and \
			(_check_box_add_to_existing.button_pressed or not new_group_name_is_empty)
	_button_set_structure.disabled = not can_apply
	
	var default_message: String = tr(&"When adding a molecule to a group, make sure it is entirely selected.")
	var notice_message: String
	if can_apply:
		notice_message = default_message
	if not can_move_molecule:
		notice_message = default_message + " " + tr(&"Try [url=select_linked] selecting all linked atoms[/url].\n")
	if new_group_name_is_empty:
		notice_message += tr(&"Group name can't be blank.")
	if not has_target:
		notice_message += " " + tr(&"Select a target group.")
	
	_label_select_only_notice.message = notice_message
	_label_select_only_notice.highlighted = not can_apply


func _get_active_group_picker() -> NanoGroupPicker:
	if _check_box_add_to_existing.button_pressed:
		return _nano_structure_picker_assign_existing
	return _nano_structure_picker_new_structure_parent


func _on_label_select_only_notice_meta_clicked(meta: Variant) -> void:
	match meta:
		"select_linked":
			WorkspaceUtils.select_connected(_workspace_context, true)
		_:
			assert(false, "Unknown meta! %s" % str(meta))
			return


func _add_selection_to_new_structure() -> void:
	var parent_structure_id: int = _nano_structure_picker_new_structure_parent.selected_id
	var new_group_name: String = _line_edit_new_structure_name.text
	WorkspaceUtils.move_selection_to_new_structure(_workspace_context, parent_structure_id, new_group_name)


func _add_selection_to_existing_structure() -> void:
	var target_structure_id: int = _nano_structure_picker_assign_existing.selected_id
	WorkspaceUtils.move_selection_to_existing_structure(_workspace_context, target_structure_id)


func _update_controls() -> void:
	var is_more_than_one_structure_available: bool = _workspace_context.workspace.get_nmb_of_structures() > 1
	if is_more_than_one_structure_available:
		_check_box_add_to_existing.disabled = false
		_nano_structure_picker_assign_existing.disabled = false
	else:
		_check_box_add_to_new.set_pressed_no_signal(true)
		_check_box_add_to_existing.set_pressed_no_signal(false)
		_check_box_add_to_existing.disabled = true
		_nano_structure_picker_assign_existing.disabled = true
	
	if _line_edit_new_structure_name.text.is_empty():
		_line_edit_new_structure_name.text = _generate_new_structure_name()


func _generate_new_structure_name() -> String:
	return tr(&"Group {0}").format([_highest_index + 1])


