class_name QuickSearchDialog
extends PopupPanel

# A dialog for quick access to every features available in MSEP.
# The actions are automatically detected from the ring menu files and doesn't
# require manual updates, unlike the menu bar.


const RING_MENUS_FOLDER := "res://editor/ring_menu_levels/"
const NON_USABLE_ITEM_COLOR_UNSELECTED: Color = Color(.5, .5, .5, 1.0)
const NON_USABLE_ITEM_COLOR_SELECTED: Color = Color(.2, .2, .2, 1.0)


var _workspace_context: WorkspaceContext
var _ring_menu: NanoRingMenu
var _menu_items: Array[TreeItem] = []
var _action_items: Array[TreeItem] = []
var _previously_selected_tree_item: TreeItem = null

@onready var _search_bar: QuickSearchBar = %SearchBar
@onready var _tree: Tree = %Tree
@onready var _description_label: Label = %DescriptionLabel


func _ready() -> void:
	window_input.connect(_on_window_input)
	about_to_popup.connect(_on_about_to_popup)
	close_requested.connect(hide)
	focus_exited.connect(hide)
	_search_bar.text_changed.connect(_on_search_bar_text_changed)
	_tree.item_selected.connect(_on_tree_item_selected)
	_tree.item_activated.connect(_on_tree_item_activated)
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	hide()


func _apply_selection_color(_in_tree_item: TreeItem = null) -> void:
	var tree_item: TreeItem = _in_tree_item
	if !tree_item:
		tree_item = _tree.get_selected()
	
	if !tree_item:
		return
	
	if tree_item.visible:
		if tree_item.get_metadata(0) is RingMenuAction:
			var item_action: RingMenuAction = tree_item.get_metadata(0)
			if !item_action.can_execute():
				if tree_item.is_selected(0):
					tree_item.set_custom_color(0, NON_USABLE_ITEM_COLOR_SELECTED)
			else:
				tree_item.clear_custom_color(0)
		
	if _previously_selected_tree_item:
		if _previously_selected_tree_item != tree_item:
			if _previously_selected_tree_item.get_metadata(0) is RingMenuAction:
				var previous_item_action: RingMenuAction = _previously_selected_tree_item.get_metadata(0)
				if !previous_item_action.can_execute():
					_previously_selected_tree_item.set_custom_color(0, NON_USABLE_ITEM_COLOR_UNSELECTED)
				else:
					_previously_selected_tree_item.clear_custom_color(0)
	
	_previously_selected_tree_item = tree_item


func _on_window_input(in_event: InputEvent) -> void:
	if Editor_Utils.process_quit_request(in_event, self):
		return
	if in_event.is_action_pressed(&"close_view", false, true):
		hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed(&"toggle_ring_menu"):
		hide()
		var context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
		WorkspaceUtils.forward_event(context, event)


# Replicate the ring menu hierarchy in a Tree node.
# Each TreeItem represents either a RingMenuAction that can be executed, or
# a RingMenuLevel that can be opened in the ring menu.
func _rebuild_tree() -> void:
	_workspace_context = MolecularEditorContext.get_current_workspace_context()
	_ring_menu = _workspace_context.get_editor_viewport_container().get_ring_menu()
	_tree.clear()
	_discover_actions_recursive(RING_MENUS_FOLDER, null)
	
	# Remove the actions used to navigate the ring menu
	var _items_to_remove: Array[TreeItem] = []
	for action_item: TreeItem in _action_items:
		var action_title: String = action_item.get_metadata(0).get_title()
		for menu_item: TreeItem in _menu_items:
			var menu_title: String = menu_item.get_metadata(0).get_title()
			if action_title == menu_title:
				_items_to_remove.push_back(action_item)
				break
	for item: TreeItem in _items_to_remove:
		_action_items.erase(item)
		item.free()
	
	# Add extra elements, not present in the ring menu
	var workspace_settings_action: RingMenuAction = \
		RingActionWorkspaceSettings.new(_workspace_context, _ring_menu)
	var action_item: TreeItem = \
		_create_action_tree_item(_tree.get_root(), workspace_settings_action)
	_action_items.push_back(action_item)
	
	# Reverse the arrays to make visibility checks easier
	_menu_items.reverse()
	_action_items.reverse()
	_filter_actions()


func _create_action_tree_item(parent: TreeItem, action: RingMenuAction) -> TreeItem:
	var action_item: TreeItem = parent.create_child()
	action_item.set_text(0, action.get_title())
	action_item.set_tooltip_text(0, action.get_description())
	action_item.set_metadata(0, action)
	return action_item


# Hides the TreeItems that don't match the search query.
# Auto select the first matching result.
func _filter_actions() -> void:
	var search_text: String = _search_bar.text.strip_edges().to_lower()
	
	for item: TreeItem in _menu_items:
		_apply_selection_color(item)
	
	# Hide irrelevant actions
	for item: TreeItem in _action_items:
		var action: RingMenuAction = item.get_metadata(0)
		var action_name: String = action.get_title().to_lower()
		item.visible = search_text.is_subsequence_ofn(action_name)
		if item.visible:
			item.select(0)
	
	# Hide irrelevant empty levels
	for item: TreeItem in _menu_items:
		var level_title: String = item.get_metadata(0).get_title().to_lower()
		if search_text.is_subsequence_ofn(level_title):
			item.visible = true
			continue
		# Level name doesn't match, hide if it doesn't have visible children
		var any_child_visible: bool = false
		for child: TreeItem in item.get_children():
			if child.visible:
				any_child_visible = true
				break
		item.visible = any_child_visible


# Finds the RingMenuLevel script for a given folder.
# If there is one, create a TreeItem for this level, and another one for each actions.
# Repeat the process if there are other folders in the current directory.
func _discover_actions_recursive(path: String, parent: TreeItem) -> void:
	var menu_level: RingMenuLevel
	var current_level_item: TreeItem = _tree.create_item(parent)
	
	# Find the RingMenuLevel script
	var files: PackedStringArray = DirAccess.get_files_at(path)
	for file_name: String in files:
		if not file_name.get_extension() in ["gd", "gdc"]:
			continue
		
		var file_path: String = path.path_join(file_name)
		var script := load(file_path)
		if not script is Script or not script.can_instantiate():
			continue
		
		if file_name.begins_with("ring_level"):
			menu_level = script.new(_workspace_context, _ring_menu)
			current_level_item.set_text(0, menu_level.get_title())
			current_level_item.set_tooltip_text(0, menu_level.get_description())
			current_level_item.set_metadata(0, menu_level)
			break
	
	if not is_instance_valid(menu_level):
		# No menu level found (could be an icon folder)
		current_level_item.free()
		return
	
	_menu_items.push_back(current_level_item)
	for action: RingMenuAction in menu_level.get_actions():
		var action_item: TreeItem = _create_action_tree_item(current_level_item, action)
		_action_items.push_back(action_item)
	
	# Scan for sub menu levels
	var directories: PackedStringArray = DirAccess.get_directories_at(path)
	for dir_name: String in directories:
		var dir_path: String = path.path_join(dir_name)
		_discover_actions_recursive(dir_path, current_level_item)


func _on_about_to_popup() -> void:
	if _action_items.is_empty():
		_rebuild_tree()
	_search_bar.text = ""
	_search_bar.grab_focus()
	_filter_actions()


func _on_search_bar_text_changed(_text: String) -> void:
	_filter_actions()


func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	
	_apply_selection_color()
	
	_description_label.visible = item != null
	if item:
		_description_label.text = item.get_metadata(0).get_description()
		_tree.scroll_to_item(item)


func _on_tree_item_activated() -> void:
	var item: TreeItem = _tree.get_selected()
	if not item:
		return
	
	# We don't use item.set_selectable(0, false), because it works fine with keyboard input, but
	# with mouse, incorrect tree item is considered to be selected and action will still happen,
	# therefore as per requirement we gray out the locked item and disallow its action, but the item
	# itself can be selected. We could check if the item is visible, but that introduces different
	# inconsistencies.
	# And as a bonus with this implementation (because the item can be selected) we get ability to
	# show appropriate message or inform the user in any other way why the item can't be used.
	if !(item.get_metadata(0) is RingMenuAction):
		await get_tree().process_frame
		_search_bar.grab_focus()
		return
	var item_action: RingMenuAction = item.get_metadata(0)
	if !item_action.can_execute():
		if item_action.get_validation_problem_description():
			_workspace_context.get_editor_viewport_container().show_warning_in_message_bar(\
					item_action.get_validation_problem_description())
		await get_tree().process_frame
		_search_bar.grab_focus()
		return
	
	# Selected item is an action, execute it.
	if item in _action_items:
		var action: RingMenuAction = item.get_metadata(0)
		action.execute()
	
	# Selected item is a menu, open the ring menu at the corresponding level
	elif item in _menu_items:
		var menu_path: Array[RingMenuLevel] = []
		while item:
			menu_path.push_back(item.get_metadata(0))
			item = item.get_parent()
		menu_path.reverse()
		
		_ring_menu.clear()
		for menu_level in menu_path:
			# Put a copy of the RingMenuLevel in the ring menu instead of the original object.
			# Otherwise, the action array will be erased on NanoRingMenu.clear() and make it useless.
			var copy: RingMenuLevel = menu_level.get_script().new(_workspace_context, _ring_menu)
			_ring_menu.add_level(copy)
		
		var main_view: WorkspaceMainView = _workspace_context.workspace_main_view
		var fit_in_rect: Rect2i = main_view.workspace_tools_container.get_global_rect()
		var desired_position: Vector2 = fit_in_rect.get_center()
		_ring_menu.show_in_desired_position(desired_position, fit_in_rect)
	
	hide()


## When a feature flag is toggled, some actions can be enabled or disabled.
## The state is cleared so the next time the search menu is opened, it rebuilds
## the tree with only the valid set of actions.
## The tree is not rebuilt immediately in case the user toggles multiple
## feature flags at once.
func _on_feature_flag_toggled(_path: String, _new_value: bool) -> void:
	_action_items.clear()
	_menu_items.clear()
