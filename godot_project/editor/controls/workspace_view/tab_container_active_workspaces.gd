extends TabContainer


signal tab_title_updated(index: int)


var _workspaces: Array[Workspace]
var tab_bar: TabBar = null

func _ready() -> void:
	# Remove editor Placeholders
	for i in range(get_tab_count()-1, 0, -1):
		var child: Node = get_child(i)
		remove_child(child)
		child.queue_free()
	
	MolecularEditorContext.homepage_activated.connect(_on_homepage_activated)
	MolecularEditorContext.workspace_loaded.connect(_on_workspace_loaded)
	MolecularEditorContext.workspace_activated.connect(_on_workspace_activated)
	MolecularEditorContext.workspace_saved.connect(_on_workspace_saved)
	MolecularEditorContext.workspace_closed.connect(_on_workspace_closed)
	tab_bar = get_child(0, true) as TabBar
	tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
	tab_bar.tab_changed.connect(_on_tab_changed)
	tab_bar.tab_close_pressed.connect(_on_tab_close_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var current_page: Control = get_current_tab_control()
		if current_page != null:
			#Make it full rect, ignoring tab_bar area
			current_page.offset_top = 0


func _on_homepage_activated() -> void:
	if current_tab != 0:
		current_tab = 0


func _on_workspace_loaded(in_workspace: Workspace) -> void:
	if _workspaces.find(in_workspace) != -1:
		# Already owns a tab
		return
	_workspaces.push_back(in_workspace)
	if !in_workspace.changed.is_connected(_update_workspace_name):
		in_workspace.changed.connect(_update_workspace_name.bind(in_workspace))
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(in_workspace)
	if !workspace_context.history_changed.is_connected(_on_workspace_context_history_changed):
		workspace_context.history_changed.connect(_on_workspace_context_history_changed.bind(weakref(workspace_context)))
	var view: WorkspaceMainView = workspace_context.workspace_main_view
	add_child(view)
	_update_workspace_name.call_deferred(in_workspace)


func _on_workspace_context_history_changed(in_workspace_context: WeakRef) -> void:
	if is_instance_valid(in_workspace_context.get_ref()):
		_update_workspace_name(in_workspace_context.get_ref().workspace)


func _on_workspace_activated(in_workspace: Workspace) -> void:
	var index: int = _workspaces.find(in_workspace)
	if index == -1:
		return
	index += 1 # Offset by 1 since home will always occupy index 0
	if current_tab != index:
		current_tab = index


func _on_workspace_saved(in_workspace: Workspace) -> void:
	_update_workspace_name(in_workspace)


func _on_workspace_closed(in_workspace: Workspace) -> void:
	var index: int = _workspaces.find(in_workspace)
	if index == -1:
		return
	_workspaces.remove_at(index)
	index += 1 # Offset by 1 since home will always occupy index 0
	get_child(index).queue_free()
	
	if in_workspace.changed.is_connected(_update_workspace_name):
		in_workspace.changed.disconnect(_update_workspace_name)


func _on_tab_changed(in_tab: int) -> void:
	if in_tab == 0:
		tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
		MolecularEditorContext.show_homepage()
		return
	tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
	MolecularEditorContext.activate_workspace(_workspaces[in_tab-1])


func _on_tab_close_pressed(in_tab: int) -> void:
	if in_tab == 0:
		tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
		return
	assert(in_tab <= _workspaces.size())
	MolecularEditorContext.request_close_workspace(_workspaces[in_tab-1])


func _update_workspace_name(in_workspace: Workspace) -> void:
	var index: int = _workspaces.find(in_workspace)
	if index == -1:
		return
	index += 1 # Offset by 1 since home will always occupy index 0
	var wp_name: String = in_workspace.get_user_friendly_name().get_file().get_basename().capitalize()
	if wp_name.is_empty():
		wp_name = "Unsaved Workspace"
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(in_workspace) as WorkspaceContext
	if workspace_context != null and \
		(workspace_context.has_unsaved_changes() or not in_workspace.suggested_path.is_empty()):
		wp_name += "*"
	set_tab_title(index, wp_name)
	tab_title_updated.emit(index)

