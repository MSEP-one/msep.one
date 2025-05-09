class_name NanoPopupMenu extends PopupMenu


func _init() -> void:
	hide()
	MolecularEditorContext.workspace_activated.connect(_on_workspace_activated)
	about_to_popup.connect(_on_about_to_popup)
	popup_hide.connect(_on_popup_hide)
	id_pressed.connect(_on_forward_id_pressed)
	InitialInfoScreen.visibility_changed.connect(_on_full_screen_popupup_visibility_changed)
	BusyIndicator.visibility_changed.connect(_on_full_screen_popupup_visibility_changed)


func _ready() -> void:
	pass


func _on_about_to_popup() -> void:
	EditorSfx.open_menu()
	_queue_update_menu()


func _on_popup_hide() -> void:
	EditorSfx.close_menu()


func _on_full_screen_popupup_visibility_changed() -> void:
	_queue_update_menu()


func _on_workspace_activated(in_workspace: Workspace) -> void:
	_queue_update_menu()
	if in_workspace == null:
		return
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(in_workspace)
	if not workspace_context.history_changed.is_connected(_on_workspace_history_changed):
		workspace_context.history_changed.connect(_on_workspace_history_changed)


func _on_workspace_history_changed() -> void:
	_queue_update_menu()


func _queue_update_menu() -> void:
	if InitialInfoScreen.visible or BusyIndicator.visible:
		_set_all_is_disabled(self, true)
	else:
		_set_all_is_disabled(self, false)
		_update_menu()


func _set_all_is_disabled(out_menu:PopupMenu, in_disable: float) -> void:
	for i in range(out_menu.item_count):
		if out_menu.is_item_separator(i):
			continue
		var submenu: String = out_menu.get_item_submenu(i)
		if not submenu.is_empty():
			_set_all_is_disabled(out_menu.get_node(submenu), in_disable)
			continue
		out_menu.set_item_disabled(i, in_disable)


func _update_menu() -> void:
	assert(false, "Implement this function in your specialized class")


func _on_forward_id_pressed(in_id: int) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context() as WorkspaceContext
	if is_instance_valid(workspace_context):
		if workspace_context.get_editor_viewport().has_exclusive_input_consumer():
			# block menu activations (assumed from keyboard shortcuts)
			# when viewport has an exclusive consumer
			return
	_on_id_pressed(in_id)


func _on_id_pressed(_in_id: int) -> void:
	assert(false, "Implement this function in your specialized class")
