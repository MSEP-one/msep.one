extends HBoxContainer


const _MARGIN: int = 200

@onready var active_workspaces: TabContainer = owner.get_node_or_null("%TabContainerActiveWorkspaces")
@onready var tab_bar_active_workspaces: TabBar = %TabBarActiveWorkspaces
@onready var tab_bar_mask: Control = %TabBarMask
@onready var next_button: Button = %NextButton
@onready var previous_button: Button = %PreviousButton

var _adjusting_to_tools_container: Control = null
var _tab_scroll_index: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(active_workspaces)
	tab_bar_active_workspaces.clear_tabs()
	for tab_index in range(active_workspaces.get_tab_count()):
		tab_bar_active_workspaces.add_tab(
			active_workspaces.get_tab_title(tab_index),
			active_workspaces.get_tab_icon(tab_index)
		)
		tab_bar_active_workspaces.set_tab_hidden(tab_index, active_workspaces.is_tab_hidden(tab_index))
		tab_bar_active_workspaces.set_tab_disabled(tab_index, active_workspaces.is_tab_disabled(tab_index))
	tab_bar_active_workspaces.current_tab = active_workspaces.current_tab
	tab_bar_active_workspaces.tab_close_display_policy = active_workspaces.tab_bar.tab_close_display_policy
	
	active_workspaces.tab_changed.connect(_on_active_workspaces_tab_changed, CONNECT_DEFERRED)
	active_workspaces.tab_title_updated.connect(_on_active_workspaces_tab_title_updated, CONNECT_DEFERRED)
	resized.connect(_on_resized)
	tab_bar_active_workspaces.tab_changed.connect(_on_tab_bar_active_workspaces_tab_changed)
	tab_bar_active_workspaces.tab_close_pressed.connect(_on_tab_bar_active_workspaces_tab_close_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	previous_button.pressed.connect(_on_previous_button_pressed)
	
	active_workspaces.child_entered_tree.connect(_on_active_workspaces_child_entered_tree, CONNECT_DEFERRED)
	active_workspaces.child_exiting_tree.connect(_on_active_workspaces_child_exiting_tree)
	
	MolecularEditorContext.workspace_activated.connect(_on_workspace_activated)
	MolecularEditorContext.homepage_activated.connect(_on_homepage_activated)


func _process(_delta: float) -> void:
	var tab_bar_rect: Rect2 = tab_bar_active_workspaces.get_global_rect()
	var mouse_pos: Vector2 = get_global_mouse_position()
	if not tab_bar_rect.has_point(mouse_pos):
		return
	for tab_idx: int in tab_bar_active_workspaces.tab_count:
		var tab_rect: Rect2 = tab_bar_active_workspaces.get_tab_rect(tab_idx)
		tab_rect.position += tab_bar_rect.position
		if tab_rect.has_point(mouse_pos):
			# Mouse is hovering a Tab. Capture Inputs
			tab_bar_active_workspaces.mouse_filter = Control.MOUSE_FILTER_STOP
			return
	# Mouse is hovering the TabBar, but not hovering any Tab. Ignore mouse inputs
	tab_bar_active_workspaces.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Scrolls the tab bar horizontally on mouse scroll.
## This is the same as clicking the left and right arrows.
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if previous_button.visible:
				_on_previous_button_pressed()
		MOUSE_BUTTON_WHEEL_DOWN:
			if next_button.visible:
				_on_next_button_pressed()


func _has_point(point: Vector2) -> bool:
	for tab_index in tab_bar_active_workspaces.tab_count:
		var tab_rect: Rect2 = tab_bar_active_workspaces.get_tab_rect(tab_index)
		if tab_index == tab_bar_active_workspaces.current_tab:
			# Current tab expands outside of the base rect by 10 pixels
			tab_rect.size.y += 10
		if tab_rect.has_point(point):
			return true
	return false

func _on_active_workspaces_tab_changed(in_tab: int) -> void:
	tab_bar_active_workspaces.current_tab = in_tab
	tab_bar_active_workspaces.tab_close_display_policy = active_workspaces.tab_bar.tab_close_display_policy


func focus_tab(in_index: int) -> void:
	tab_bar_active_workspaces.current_tab = in_index
	_tab_scroll_index = in_index
	ScriptUtils.call_deferred_once(update)



## Updates the navigation buttons visibility and the tab bar scroll position.
func update() -> void:
	# Some state used for updating UI is not yet ready in the current frame, so we wait a frame
	# before updating the UI.
	await get_tree().process_frame
	
	if tab_bar_active_workspaces.get_tab_count() == 0:
		return
	
	if tab_bar_active_workspaces.size.x < size.x:
		# Every tabs can fit, hide the navigation buttons
		previous_button.visible = false
		next_button.visible = false
		tab_bar_active_workspaces.position.x = (size.x - tab_bar_active_workspaces.size.x) / 2.0
		_tab_scroll_index = tab_bar_active_workspaces.current_tab
		return
	
	# Update scroll position
	var tab_position: Vector2 = tab_bar_active_workspaces.get_tab_rect(_tab_scroll_index).position
	var tween: Tween = tab_bar_active_workspaces.create_tween()
	tween.tween_property(tab_bar_active_workspaces, "position:x", -tab_position.x, 0.1)
	
	# Selectively hide the arrows if we can't scroll in that direction
	var last_index: int = tab_bar_active_workspaces.get_tab_count() - 1
	previous_button.visible = _tab_scroll_index > 0
	var last_tab_end: float = tab_bar_active_workspaces.get_tab_rect(last_index).end.x
	var clipping_end: float = tab_position.x + tab_bar_mask.size.x
	next_button.visible = last_tab_end > clipping_end


func _on_next_button_pressed() -> void:
	var max_index: int = tab_bar_active_workspaces.get_tab_count() - 1
	if _tab_scroll_index < max_index:
		_tab_scroll_index += 1
		ScriptUtils.call_deferred_once(update)


func _on_previous_button_pressed() -> void:
	if _tab_scroll_index > 0:
		_tab_scroll_index -= 1
		ScriptUtils.call_deferred_once(update)


func _on_active_workspaces_tab_title_updated(in_index: int) -> void:
	if active_workspaces != null and active_workspaces.get_tab_count() > in_index:
		tab_bar_active_workspaces.set_tab_title(in_index, active_workspaces.get_tab_title(in_index))


func _on_resized() -> void:
	ScriptUtils.call_deferred_once(update)


func _on_tab_bar_active_workspaces_tab_changed(in_tab: int) -> void:
	if active_workspaces.current_tab != in_tab:
		EditorSfx.open_menu()
		active_workspaces.current_tab = in_tab
	# Focus the clicked tab, but only if it's not fully visible already
	var tab_rect: Rect2 = tab_bar_active_workspaces.get_tab_rect(in_tab)
	var tab_start_position: int = int(tab_bar_active_workspaces.position.x + tab_rect.position.x)
	var tab_end_position: int = int(tab_start_position + tab_rect.size.x)
	if tab_start_position < 0 or tab_end_position > tab_bar_mask.size.x:
		focus_tab(in_tab)
	else:
		ScriptUtils.call_deferred_once(update)


func _on_tab_bar_active_workspaces_tab_close_pressed(in_tab: int) -> void:
	EditorSfx.mouse_down()
	active_workspaces.tab_bar.tab_close_pressed.emit(in_tab)


func _on_active_workspaces_child_entered_tree(in_child: Node) -> void:
	if in_child is Control:
		var tab_index: int = active_workspaces.get_tab_idx_from_control(in_child)
		assert(tab_index == tab_bar_active_workspaces.tab_count)
		tab_bar_active_workspaces.add_tab(
			active_workspaces.get_tab_title(tab_index),
			active_workspaces.get_tab_icon(tab_index)
		)
		tab_bar_active_workspaces.set_tab_hidden(tab_index, active_workspaces.is_tab_hidden(tab_index))
		tab_bar_active_workspaces.set_tab_disabled(tab_index, active_workspaces.is_tab_disabled(tab_index))
		ScriptUtils.call_deferred_once(update)


func _on_active_workspaces_child_exiting_tree(in_child: Node) -> void:
	if in_child is Control:
		var tab_index: int = active_workspaces.get_tab_idx_from_control(in_child)
		if tab_index >= 0 and tab_index < tab_bar_active_workspaces.tab_count:
			tab_bar_active_workspaces.remove_tab(tab_index)


func _on_workspace_activated(in_workspace: Workspace) -> void:
	if _adjusting_to_tools_container != null:
		_adjusting_to_tools_container.resized.disconnect(_on_adjusting_to_tools_container_resized)
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(in_workspace)
	var workspace_view: WorkspaceMainView = workspace_context.workspace_main_view
	assert(workspace_view != null)
	_adjusting_to_tools_container = workspace_view.workspace_tools_container
	_adjusting_to_tools_container.resized.connect(_on_adjusting_to_tools_container_resized)
	ScriptUtils.call_deferred_once(_update_margins)


func _on_homepage_activated() -> void:
	if _adjusting_to_tools_container != null:
		_adjusting_to_tools_container.resized.disconnect(_on_adjusting_to_tools_container_resized)
	_adjusting_to_tools_container = null
	ScriptUtils.call_deferred_once(_update_margins)


func _on_adjusting_to_tools_container_resized() -> void:
	ScriptUtils.call_deferred_once(_update_margins)


func _update_margins() -> void:
	if _adjusting_to_tools_container == null:
		offset_left = _MARGIN
		offset_right = -_MARGIN
	else:
		var working_rect: Rect2 = _adjusting_to_tools_container.get_global_rect()
		var screen_width: float = _adjusting_to_tools_container.get_viewport_rect().size.x
		offset_left = _MARGIN + working_rect.position.x
		offset_right = -(_MARGIN + (screen_width - working_rect.end.x))
	if not ScriptUtils.is_callable_queued(update):
		update()
