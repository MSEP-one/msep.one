extends MenuBar


func _ready() -> void:
	for child in get_children():
		if child is PopupMenu:
			var child_popup_menu: PopupMenu = child as PopupMenu
			child_popup_menu.about_to_popup.connect(_on_child_popup_menu_about_to_popup)


func _on_child_popup_menu_about_to_popup() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	if not is_instance_valid(workspace_context):
		return
	var viewport_container: SubViewportContainer = workspace_context.get_editor_viewport_container()
	if not is_instance_valid(viewport_container):
		return
	var ring_menu: NanoRingMenu = viewport_container.get_ring_menu()
	ring_menu.close()


# # # # # 
# # Workaround for the fact that FileDialog is giving graphical artifacts in 4.0 when it's a child of PopupMenu
func _on_file_file_popup_requested() -> void:
	var current_workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	if current_workspace_context == null:
		MolecularEditorContext.create_workspace()
		current_workspace_context = MolecularEditorContext.get_current_workspace_context()
	assert(current_workspace_context)
	var frame_counter: int = 0
	while !is_instance_valid(current_workspace_context.action_import_file):
		await get_tree().process_frame
		frame_counter += 1
		assert(frame_counter < 5, "Something unexpected happened")
	current_workspace_context.action_import_file.execute()

