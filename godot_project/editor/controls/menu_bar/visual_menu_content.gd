extends MarginContainer

const VisualMenuCategoryScn = preload("res://editor/controls/menu_bar/visual_menu_category/visual_menu_category.tscn")

@onready var _line_edit_filter: LineEdit = %LineEditFilter
@onready var _content_container: VBoxContainer = %ContentContainer

var _categories: Array[VisualMenuCategory] = []

func _ready() -> void:
	_ready_deferred.call_deferred()
	_line_edit_filter.text_changed.connect(_on_line_edit_filter_text_changed)
	visibility_changed.connect(_on_visibility_changed)

func _ready_deferred() -> void:
	var molecular_editor: MolecularEditor = Editor_Utils.get_editor()
	var menu_bar: MenuBar = molecular_editor.menu_bar
	for child in menu_bar.get_children():
		var menu: PopupMenu = child as PopupMenu
		if menu != null and menu.item_count > 0:
			_add_menu_bar_path(menu, menu.name)
			

func _add_menu_bar_path(in_menu: PopupMenu, in_path: String) -> void:
	var category: VisualMenuCategory = VisualMenuCategoryScn.instantiate()
	var root_menu_category: VisualMenuCategory = category
	_content_container.add_child(category)
	_categories.push_back(category)
	category.title_label.text = in_path
	if in_menu.has_signal(&"request_hide"):
		in_menu.request_hide.connect(get_window().hide)
	for i in range(in_menu.item_count):
		var submenu_name: String = in_menu.get_item_submenu(i)
		var is_submenu: bool = !submenu_name.is_empty()
		if is_submenu:
			var submenu: PopupMenu = in_menu.get_node(submenu_name) as PopupMenu
			if submenu != null:
				var path: String = in_path + "/" + submenu_name
				_add_menu_bar_path(submenu, path)
			continue
		if in_menu.is_item_separator(i):
			var separator_name: String = in_menu.get_item_text(i)
			if separator_name.is_empty():
				category = root_menu_category
			else:
				category = VisualMenuCategoryScn.instantiate()
				_content_container.add_child(category)
				_categories.push_back(category)
				category.title_label.text = in_path + "/" + separator_name
			continue
#		if in_menu.is_item_checkable(i) or in_menu.is_item_radio_checkable(i):
#			continue
		
		var menu_item_id: int = in_menu.get_item_id(i)
		var text: String = in_menu.get_item_text(i)
		var tooltip: String = in_menu.get_item_tooltip(i)
		var icon: Texture2D = in_menu.get_item_icon(i)
		var is_disabled: bool = in_menu.is_item_disabled(i)
		
		var item_id: int = category.add_item(text, icon)
		category.set_item_disabled(item_id, is_disabled)
		category.set_item_tooltip(item_id, tooltip)
		var clicked_callback: Callable = func () -> void:
			if not in_menu.is_item_disabled(i):
				in_menu.id_pressed.emit(menu_item_id)
				_update_if_visible()
		category.set_item_clicked_callback(item_id, clicked_callback)
	if root_menu_category.items_count == 0:
		# This category has no items, most probably only submenus
		root_menu_category.hide()


func _on_visibility_changed() -> void:
	_update_if_visible()

func _update_if_visible() -> void:
	if is_visible_in_tree():
		_force_update_content()

func _force_update_content() -> void:
	var molecular_editor: MolecularEditor = Editor_Utils.get_editor()
	var menu_bar: MenuBar = molecular_editor.menu_bar
	for child in menu_bar.get_children():
		var menu: PopupMenu = child as PopupMenu
		if menu != null and menu.item_count > 0:
			_update_menu_bar_path(menu, menu.name)


func _update_menu_bar_path(in_menu: PopupMenu, in_path: String) -> void:
	var candidates: Array[VisualMenuCategory] = _categories.filter(
		func (in_cat: VisualMenuCategory) -> bool:
			return in_cat.title_label.text == in_path
	)
	assert(candidates.size() == 1, "1 and only 1 category should exist per path")
	var category: VisualMenuCategory = candidates.front()
	var root_menu_category: VisualMenuCategory = category
	in_menu.about_to_popup.emit() # Force update
	var item_id: int = 0
	var root_category_item_id: int = 0
	var separator_name: String = ""
	for i in range(in_menu.item_count):
		var submenu_name: String = in_menu.get_item_submenu(i)
		var is_submenu: bool = !submenu_name.is_empty()
		if is_submenu:
			var submenu: PopupMenu = in_menu.get_node(submenu_name) as PopupMenu
			if submenu != null:
				var path: String = in_path + "/" + submenu_name
				_update_menu_bar_path(submenu, path)
			continue
		if in_menu.is_item_separator(i):
			var new_separator_name: String = in_menu.get_item_text(i)
			if separator_name.is_empty() and not new_separator_name.is_empty():
				# exit root and enter a new separator
				candidates = _categories.filter(
					func (in_cat: VisualMenuCategory) -> bool:
						return in_cat.title_label.text == in_path + "/" + new_separator_name
				)
				assert(candidates.size() == 1, "1 and only 1 category should exist per path")
				category = candidates.front()
				root_category_item_id = item_id
				item_id = 0
			elif not separator_name.is_empty() and new_separator_name.is_empty():
				# exit separator
				item_id = root_category_item_id
				category = root_menu_category
			elif separator_name != new_separator_name:
				# switch from a separator to a new separator
				candidates = _categories.filter(
					func (in_cat: VisualMenuCategory) -> bool:
						return in_cat.title_label.text == in_path + "/" + new_separator_name
				)
				assert(candidates.size() == 1, "1 and only 1 category should exist per path")
				category = candidates.front()
				item_id = 0
			separator_name = new_separator_name
			continue
#		if in_menu.is_item_checkable(i) or in_menu.is_item_radio_checkable(i):
#			continue
		
		var text: String = in_menu.get_item_text(i)
		var tooltip: String = in_menu.get_item_tooltip(i)
		var icon: Texture2D = in_menu.get_item_icon(i)
		var is_disabled: bool = in_menu.is_item_disabled(i)
		
		category.set_item_text(item_id, text)
		category.set_item_tooltip(item_id, tooltip)
		category.set_item_icon(item_id, icon)
		category.set_item_disabled(item_id, is_disabled)
		item_id += 1

func _on_line_edit_filter_text_changed(in_new_text: String) -> void:
	for category in _categories:
		category.filter(in_new_text)
