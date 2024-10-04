extends WorkspaceDocker


@onready var _menu_button_filter_by: MenuButton = %MenuButtonFilterBy
@onready var _line_edit_filter: LineEdit = %LineEditFilter
@onready var _menu_button_sort: MenuButton = %MenuButtonSort
@warning_ignore("unused_private_class_variable")
@onready var _button_focus_selection: Button = %ButtonFocusSelection
@onready var _objects_tree: Tree = %ObjectsTree
@onready var _popup_object_contextual_menu: PopupMenu = %PopupObjectTreeView

const _icon_visible = preload("res://editor/controls/dockers/workspace_docker/icons/icon_visible.svg")
const _icon_hidden = preload("res://editor/controls/dockers/workspace_docker/icons/icon_hidden.svg")
const _icon_activated = preload("res://editor/controls/dockers/workspace_docker/icons/icon_activated.svg")
const _icon_deactivated = preload("res://editor/controls/dockers/workspace_docker/icons/icon_deactivated.svg")


var _current_filter_type: int = FILTER_TYPE_STRUCTURE_NAME
var _current_sort_order: int = SORT_OBJECTS_BY_CREATION_TIME
var _structure_to_tree_items_map: Dictionary = {} #[NanoStructure,TreeItem]
var _edited_tree_item: TreeItem = null
var _activated_tree_item: TreeItem = null
var _active_workspace_context: WorkspaceContext:
	set(v):
		if v == _active_workspace_context:
			return
		if is_instance_valid(_active_workspace_context):
			_active_workspace_context.structure_added.disconnect(_on_active_workspace_context_structure_added)
			_active_workspace_context.structure_removed.disconnect(_on_active_workspace_context_structure_about_to_remove)
			_active_workspace_context.workspace.structure_reparented.disconnect(_on_active_workspace_context_structure_reparented)
			_active_workspace_context.selection_in_structures_changed.disconnect(_on_active_workspace_context_selection_in_structures_changed)
			_active_workspace_context.object_tree_visibility_changed.disconnect(_on_visibility_setting_changed)
			_active_workspace_context.current_structure_context_changed.disconnect(_on_current_structure_context_changed)
		
		if is_instance_valid(_objects_tree):
			_objects_tree.clear()
			_structure_to_tree_items_map.clear()
		_active_workspace_context = v
		_update_structure_list()
		if is_instance_valid(v):
			v.structure_added.connect(_on_active_workspace_context_structure_added)
			v.structure_about_to_remove.connect(_on_active_workspace_context_structure_about_to_remove)
			v.workspace.structure_reparented.connect(_on_active_workspace_context_structure_reparented)
			v.selection_in_structures_changed.connect(_on_active_workspace_context_selection_in_structures_changed)
			v.object_tree_visibility_changed.connect(_on_visibility_setting_changed)
			v.current_structure_context_changed.connect(_on_current_structure_context_changed)
			

# region: Virtual

func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_active_workspace_context = in_workspace_context
	return is_instance_valid(in_workspace_context) and in_workspace_context.visible_object_tree


func get_unique_docker_name() -> StringName:
	return &"__ObjectTreeDocker__"


func get_default_docker_area() -> int:
	return DOCK_AREA_LEFT_TOP_RIGHT


#region: Internal

func _ready() -> void:
	_objects_tree.button_clicked.connect(_on_objects_tree_button_clicked)
	_objects_tree.item_activated.connect(_on_objects_tree_item_activated)
	_objects_tree.item_edited.connect(_on_objects_tree_item_edited)
	_objects_tree.multi_selected.connect(_on_object_tree_multi_selected)
	_objects_tree.item_mouse_selected.connect(_on_item_mouse_selected)
	_objects_tree.hide_root = true
	_menu_button_filter_by.get_popup().id_pressed.connect(_on_menu_button_filter_by_id_pressed)
	_line_edit_filter.text_changed.connect(_apply_filters)
	_menu_button_sort.get_popup().id_pressed.connect(_on_menu_button_sort_id_pressed)
	_popup_object_contextual_menu.action_copy.connect(_on_item_copied)
	_popup_object_contextual_menu.action_cut.connect(_on_item_cut)
	_popup_object_contextual_menu.action_paste.connect(_on_item_pasted)
	_popup_object_contextual_menu.action_delete.connect(_on_item_deleted)
	_update_structure_list()


func _on_visibility_setting_changed() -> void:
	_update_visibility(should_show(_active_workspace_context))


func _on_current_structure_context_changed(in_structure_context: StructureContext) -> void:
	assert(in_structure_context != null and in_structure_context.nano_structure != null, "Invalid structure context")
	var item: TreeItem = _structure_to_tree_items_map.get(in_structure_context.nano_structure, null)
	# Update activate button states
	if _activated_tree_item != null:
		_update_structure_item(_activated_tree_item)
	if item:
		_update_structure_item(item)

func _on_menu_button_filter_by_id_pressed(in_id: int) -> void:
	@warning_ignore("int_as_enum_without_cast")
	_current_filter_type = in_id
	for i in range(_menu_button_filter_by.item_count):
		_menu_button_filter_by.get_popup().set_item_checked(i, i == in_id)
	_menu_button_filter_by.text = _menu_button_filter_by.get_popup().get_item_text(in_id)
	_apply_filters()

func _on_menu_button_sort_id_pressed(in_id: int) -> void:
	if in_id == TREE_SETTING_GROUP_OBJECTS_BY_TYPE:
		push_error("Grouping objects by type is yet unimplemented")
		return
	@warning_ignore("int_as_enum_without_cast")
	_current_sort_order = in_id
	for i in range(_menu_button_sort.item_count - 1):
		_menu_button_sort.get_popup().set_item_checked(i, i == in_id)
	_sort_object_tree()

func _on_objects_tree_button_clicked(in_item: TreeItem, _column: int, in_id: int, in_mouse_button_index: int) -> void:
	var structure: NanoStructure = in_item.get_metadata(0)
	if structure == null || in_mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	match in_id:
		TREE_ITEM_BUTTON_ID_ACTIVATE:
			_active_workspace_context.activate_nano_structure(structure)
		TREE_ITEM_BUTTON_ID_VISIBILITY:
			structure.visible = !structure.visible
	_update_structure_item(in_item)
	_objects_tree.queue_redraw()


func _on_objects_tree_item_activated() -> void:
	var item: TreeItem = _objects_tree.get_selected()
	var structure: NanoStructure = null if item == null else item.get_metadata(0)
	if structure != null:
		item.set_editable(0, true)
		if _objects_tree.edit_selected():
			_edited_tree_item = item
		else:
			item.set_editable(0, false)


func _on_objects_tree_item_edited() -> void:
	var item: TreeItem = _edited_tree_item
	_edited_tree_item = null
	var structure: NanoStructure = item.get_metadata(0)
	if structure == null:
		return
	item.set_editable(0, false)
	var new_name: String = item.get_text(0)
	# Validate Name
	if new_name.is_empty():
		# Revert edit
		item.set_text(0, structure.get_structure_name())
		return
	# TBD: prevent repeated name?
	structure.set_structure_name(new_name)


func _on_object_tree_multi_selected(item: TreeItem, _column: int, selected: bool) -> void:
	var nano_structure: NanoStructure = item.get_metadata(0)
	if nano_structure == null:
		return
	var structure_context: StructureContext = _active_workspace_context.get_nano_structure_context(nano_structure)
	if selected:
		structure_context.select_all()
	else:
		structure_context.clear_selection()
		structure_context.set_shape_selected(false)


func _apply_filters(_ignored_signal_argument: Variant = null) -> void:
	if _objects_tree == null or _objects_tree.get_root() == null:
		return
	var tree_items: Array = _structure_to_tree_items_map.values()
	for item: TreeItem in tree_items:
		var structure: NanoStructure = item.get_metadata(0)
		if structure != null:
			item.visible = _check_filter_condition(structure)


func _check_filter_condition(structure: NanoStructure) -> bool:
	var filter_text: String = _line_edit_filter.text.to_lower()
	if filter_text.is_empty():
		return true
	var item_visible: bool = false
	if _current_filter_type in [FILTER_TYPE_ANY, FILTER_TYPE_STRUCTURE_NAME]:
		if structure.get_structure_name().to_lower().find(filter_text) >= 0:
			item_visible = true
	if _current_filter_type in [FILTER_TYPE_ANY, FILTER_TYPE_STRUCTURE_ID]:
		if str(structure.int_guid).to_lower().find(filter_text) >= 0:
			item_visible = true
	if _current_filter_type in [FILTER_TYPE_ANY, FILTER_TYPE_STRUCTURE_TYPE]:
		if str(structure.get_type()).capitalize().to_lower().find(filter_text) >= 0:
			item_visible = true
	return item_visible


func _on_create_structure(id: int) -> void:
	if !is_instance_valid(_active_workspace_context):
		return
	var workspace: Workspace = _active_workspace_context.workspace
	if !is_instance_valid(workspace):
		return
	var structure: NanoStructure = null
	match id:
		0:
			structure = AtomicStructure.create()
			structure.set_structure_name("Structure %d" % (workspace.get_nmb_of_structures() + 1))
			workspace.add_structure(structure)
		_:
			push_error("Unhandled structure type")
			return


func _on_active_workspace_context_structure_added(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_update_structure_list)


func _on_active_workspace_context_structure_about_to_remove(in_structure: NanoStructure) -> void:
	_destroy_structure_item(in_structure)


func _on_active_workspace_context_structure_reparented(in_structure: NanoStructure, in_new_parent: NanoStructure) -> void:
	var item: TreeItem = _structure_to_tree_items_map.get(in_structure, null)
	if item == null:
		_create_structure_item(in_structure)
		return
	var parent_item: TreeItem = _structure_to_tree_items_map.get(in_new_parent, null) as TreeItem
	if parent_item == null:
		parent_item = _create_structure_item(in_structure)
	item.get_parent().remove_child(item)
	parent_item.add_child(item)


func _on_active_workspace_context_selection_in_structures_changed(in_structure_contexts: Array[StructureContext]) -> void:
	for context: StructureContext in in_structure_contexts:
		var structure: NanoStructure = context.nano_structure
		var item: TreeItem = _structure_to_tree_items_map.get(structure, null)
		if item == null:
			continue
		if context.has_selection():
			item.select(0)
		else:
			item.deselect(0)


func _update_structure_list() -> void:
	if !is_instance_valid(_objects_tree):
		return # Too early, wait for _ready()
	if !is_instance_valid(_active_workspace_context):
		_objects_tree.clear()
		_structure_to_tree_items_map.clear()
		return
	_ensure_root_exists()
	var workspace: Workspace = _active_workspace_context.workspace
	if !is_instance_valid(workspace):
		_objects_tree.clear()
		_structure_to_tree_items_map.clear()
		return
	var structures: Array = workspace.get_structures()
	for structure: NanoStructure in structures:
		assert(is_instance_valid(structure), "Invalid NanoStructure")
		if !_structure_to_tree_items_map.has(structure):
			_create_structure_item(structure)
	_sort_object_tree()


func _ensure_root_exists() -> void:
	assert(_objects_tree)
	if _objects_tree.get_root() == null:
		var root: TreeItem = _objects_tree.create_item()
		var wp_name: String = _active_workspace_context.workspace.resource_path.get_basename()
		if wp_name.is_empty():
			wp_name = "Unsaved Workspace"
		root.set_text(0, wp_name)


func _destroy_structure_item(in_nano_structure: NanoStructure) -> void:
	var item: TreeItem = _structure_to_tree_items_map.get(in_nano_structure, null)
	if item != null:
		_free_tree_item_and_all_dependencies(item)


func _free_tree_item_and_all_dependencies(in_item: TreeItem) -> void:
	for child_item: TreeItem in in_item.get_children():
		_free_tree_item_and_all_dependencies(child_item)
	var related_nano_structure: NanoStructure = _structure_to_tree_items_map.find_key(in_item)
	_structure_to_tree_items_map.erase(related_nano_structure)
	in_item.free()


func _create_structure_item(in_nano_structure: NanoStructure) -> TreeItem:
	var parent_item: TreeItem = _find_tree_item_parent(in_nano_structure)
	var item: TreeItem = _objects_tree.create_item(parent_item)
	item.set_metadata(0, in_nano_structure)
	item.add_button(0, _icon_deactivated, TREE_ITEM_BUTTON_ID_ACTIVATE, false, tr("Activate Structure"))
	item.add_button(0, _icon_visible, TREE_ITEM_BUTTON_ID_VISIBILITY, false, tr("Toggle visibility"))
	_update_structure_item(item)
	_structure_to_tree_items_map[in_nano_structure] = item
	return item

func _find_tree_item_parent(in_nano_structure: NanoStructure) -> TreeItem:
	var parent_item: TreeItem = _objects_tree.get_root()
	var parent_int_guid: int = in_nano_structure.int_parent_guid
	if parent_int_guid != Workspace.INVALID_STRUCTURE_ID:
		var parent_struct: NanoStructure = _active_workspace_context.workspace.get_structure_by_int_guid(parent_int_guid)
		assert(parent_struct != null, "Invalid structure parent")
		parent_item = _structure_to_tree_items_map.get(parent_struct, _objects_tree.get_root())
	return parent_item

func _update_structure_item(in_item: TreeItem) -> void:
	var nano_structure: NanoStructure = in_item.get_metadata(0)
	if nano_structure == null:
		return
	var icon: Texture2D = _icon_visible if nano_structure.get_visible() else _icon_hidden
	in_item.set_button(0, TREE_ITEM_BUTTON_ID_VISIBILITY, icon)
	var tooltip: String = ""
	tooltip += tr("Type: %s\n") % str(nano_structure.get_type()).capitalize()
	tooltip += tr("Unique ID: %s\n") % str(nano_structure.int_guid)
	var is_structure_active: bool = _active_workspace_context.get_current_structure_context().nano_structure == nano_structure
	var activate_button_color: Color = Color.GOLD if is_structure_active else Color.WHITE
	var activate_button_texture: Texture2D = _icon_activated if is_structure_active else _icon_deactivated
	in_item.set_button_color(0, TREE_ITEM_BUTTON_ID_ACTIVATE, activate_button_color)
	in_item.set_button(0, TREE_ITEM_BUTTON_ID_ACTIVATE, activate_button_texture)
	in_item.set_tooltip_text(0, tooltip)
	in_item.set_text(0, nano_structure.get_structure_name())
	if is_structure_active:
		_activated_tree_item = in_item



func _sort_object_tree() -> void:
	var tree_root: TreeItem = _objects_tree.get_root()
	var is_structure_callback: Callable = func(item: TreeItem) -> bool:
		return item.get_metadata(0) is NanoStructure
	var structure_items: Array[TreeItem] = tree_root.get_children().filter(is_structure_callback)
	if structure_items.is_empty():
		return
	structure_items.sort_custom(_compare_tree_items)
	var previous_item: TreeItem = structure_items.pop_front()
	for item in structure_items:
		item.move_after(previous_item)
		previous_item = item

func _compare_tree_items(a: TreeItem, b: TreeItem) -> bool:
	assert(a != null and b != null)
	var structure_a: NanoStructure = a.get_metadata(0)
	var structure_b: NanoStructure = b.get_metadata(0)
	assert(structure_a != null and structure_b != null)
	match _current_sort_order:
		SORT_OBJECTS_BY_CREATION_TIME:
			var structures: Array = _active_workspace_context.workspace.get_structures()
			var a_index: int = structures.find(structure_a)
			var b_index: int = structures.find(structure_b)
			return a_index < b_index
		SORT_OBJECTS_BY_NAME_ASCENDING:
			return structure_a.get_structure_name() < structure_b.get_structure_name()
		SORT_OBJECTS_BY_NAME_DESCENDING:
			return structure_a.get_structure_name() > structure_b.get_structure_name()
		SORT_OBJECTS_BY_ID_ASCENDING:
			return str(structure_a.int_guid) < str(structure_b.int_guid)
		SORT_OBJECTS_BY_ID_DESCENDING:
			return str(structure_a.int_guid) > str(structure_b.int_guid)
	assert(false, "Invalid sort order " + str(_current_sort_order))
	return false

func _on_item_mouse_selected(_in_position: Vector2, in_mouse_btn_index: int) -> void:
	if in_mouse_btn_index == MOUSE_BUTTON_RIGHT:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		_popup_object_contextual_menu.popup(Rect2(mouse_pos.x, mouse_pos.y, _popup_object_contextual_menu.min_size.x, _popup_object_contextual_menu.min_size.y))

func _on_item_copied() -> void:
	var item: TreeItem = _objects_tree.get_selected()
	item.get_metadata(0)
	print(item.get_metadata(0))
	#TODO: Correctly perform action using undo_redo

func _on_item_cut() -> void:
	var item: TreeItem = _objects_tree.get_selected()
	item.get_metadata(0)
	print(item.get_metadata(0))
	#TODO: Correctly perform action using undo_redo

func _on_item_pasted() -> void:
	var item: TreeItem = _objects_tree.get_selected()
	item.get_metadata(0)
	print(item.get_metadata(0))
	#TODO: Correctly perform action using undo_redo

func _on_item_deleted() -> void:
	var item: TreeItem = _objects_tree.get_selected()
	item.get_metadata(0)
	print(item.get_metadata(0))
	#TODO: Correctly perform action using undo_redo

enum {
	FILTER_TYPE_ANY            = 0,
	FILTER_TYPE_STRUCTURE_NAME = 1,
	FILTER_TYPE_STRUCTURE_ID   = 2,
	FILTER_TYPE_STRUCTURE_TYPE = 3
}

enum {
	SORT_OBJECTS_BY_CREATION_TIME      = 0,
	SORT_OBJECTS_BY_NAME_ASCENDING     = 1,
	SORT_OBJECTS_BY_NAME_DESCENDING    = 2,
	SORT_OBJECTS_BY_ID_ASCENDING       = 3,
	SORT_OBJECTS_BY_ID_DESCENDING      = 4,
	TREE_SETTING_GROUP_OBJECTS_BY_TYPE = 5
}

enum {
	TREE_ITEM_BUTTON_ID_ACTIVATE = 0,
	TREE_ITEM_BUTTON_ID_VISIBILITY = 1
}
