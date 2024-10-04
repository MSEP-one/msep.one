class_name NanoGroupPickerPopupPanel extends PopupPanel


const _TREE_MAXIMUM_HEIGTH: int = 200
const _WORKSPACE_GROUP_ID: int = 0
const _TREE_COLUMN_0: int = 0


signal nano_structure_clicked(structure_id: int)

@export var can_select_current: bool = true
var selected_id: int: set = _set_selected_id
var _tree: Tree

var _workspace_context: WorkspaceContext = null
var _structure_id_to_tree_item: Dictionary = {
#	structure_id<int> = tree_item<TreeItem>
}

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		about_to_popup.connect(_on_about_to_popup)
		_tree = $MarginContainer/Tree as Tree
		_tree.item_selected.connect(_on_tree_item_selected)
		hide()


func initialize(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context
	assert(_structure_id_to_tree_item.is_empty(), "Already initialized")
	_tree.clear()
	var root: TreeItem = _tree.create_item(null, _WORKSPACE_GROUP_ID)
	_structure_id_to_tree_item[_WORKSPACE_GROUP_ID] = root
	var structures: Array = in_workspace_context.workspace.get_structures()
	for nano_structure: NanoStructure in structures:
		_on_nano_structure_added(nano_structure)
		if selected_id == 0 and _can_contain_children(nano_structure):
			selected_id = nano_structure.int_guid
	
	if not in_workspace_context.structure_added.is_connected(_on_nano_structure_added):
		in_workspace_context.structure_added.connect(_on_nano_structure_added)
	if not in_workspace_context.structure_about_to_remove.is_connected(_on_nano_structure_removed):
		in_workspace_context.structure_about_to_remove.connect(_on_nano_structure_removed)
	if not in_workspace_context.structure_renamed.is_connected(_on_nano_structure_renamed):
		in_workspace_context.structure_renamed.connect(_on_nano_structure_renamed)
	if not in_workspace_context.workspace.structure_reparented.is_connected(_on_nano_structure_reparented):
		in_workspace_context.workspace.structure_reparented.connect(_on_nano_structure_reparented)
	if not in_workspace_context.history_snapshot_applied.is_connected(_on_nano_structure_history_snapshot_applied):
		in_workspace_context.history_snapshot_applied.connect(_on_nano_structure_history_snapshot_applied)


func _can_contain_children(in_structure: NanoStructure) -> bool:
	return not in_structure.is_virtual_object()


func get_selected_structure_name() -> String:
	if selected_id < 0:
		return tr(&"Click to select")
	else:
		var tree_item: TreeItem = _get_structure_tree_item(selected_id)
		return tree_item.get_text(_TREE_COLUMN_0)


func _set_selected_id(in_selected_id: int) -> void:
	selected_id = in_selected_id
	if _tree == null:
		return
	if in_selected_id < 0:
		_tree.deselect_all()
		return
	assert(_structure_id_to_tree_item.has(in_selected_id), "Cannot Select")
	var item: TreeItem = _structure_id_to_tree_item[in_selected_id] as TreeItem
	if not item.is_selected(_TREE_COLUMN_0):
		item.select(_TREE_COLUMN_0)
	_tree.scroll_to_item(item, true)


func _on_about_to_popup() -> void:
	assert(not _structure_id_to_tree_item.is_empty())
	# Calculate min size
	_tree.custom_minimum_size.y = 0
	_tree.scroll_vertical_enabled = false
	if _tree.get_combined_minimum_size().y > _TREE_MAXIMUM_HEIGTH:
		_tree.custom_minimum_size.y = _TREE_MAXIMUM_HEIGTH
		_tree.scroll_vertical_enabled = true
	_set_selected_id(selected_id)
	# Disable if needed
	var edited_structure_id: int = \
			0 if _workspace_context.is_creating_object() \
			else _workspace_context.get_current_structure_context().nano_structure.int_guid
	for structure_id: int in _structure_id_to_tree_item.keys():
		var tree_item: TreeItem = _get_structure_tree_item(structure_id)
		var can_select: bool = can_select_current or structure_id != edited_structure_id
		tree_item.set_selectable(_TREE_COLUMN_0, can_select)


func _on_tree_item_selected() -> void:
	selected_id = _structure_id_to_tree_item.find_key(_tree.get_selected())
	nano_structure_clicked.emit(selected_id)
	hide()


func _on_nano_structure_added(in_nano_structure: NanoStructure) -> void:
	if not _can_contain_children(in_nano_structure):
		# NanoShapes, NanoVirtualMotors, etc; are not shown in the graph
		return
	_get_structure_tree_item(in_nano_structure.int_guid)


func _on_nano_structure_removed(in_nano_structure: NanoStructure) -> void:
	if selected_id == in_nano_structure.int_guid:
		selected_id = -1
		nano_structure_clicked.emit(-1)
	if not _can_contain_children(in_nano_structure):
		# NanoShapes, NanoVirtualMotors, etc; are not shown in the graph
		return
	var structure_id: int = in_nano_structure.int_guid
	var tree_item: TreeItem = _get_structure_tree_item_or_null(structure_id)
	if tree_item != null:
		tree_item.get_parent().remove_child(tree_item)
		_free_tree_item_and_all_dependencies(tree_item)


func _free_tree_item_and_all_dependencies(in_item: TreeItem) -> void:
	for child_item: TreeItem in in_item.get_children():
		_free_tree_item_and_all_dependencies(child_item)
	var related_nano_structure_guid: int = _structure_id_to_tree_item.find_key(in_item)
	_structure_id_to_tree_item.erase(related_nano_structure_guid)
	in_item.free()


func _on_nano_structure_renamed(in_nano_structure: NanoStructure, in_new_name: String) -> void:
	var tree_item: TreeItem = _get_structure_tree_item(in_nano_structure.int_guid)
	tree_item.set_text(_TREE_COLUMN_0, in_new_name)


func _on_nano_structure_reparented(in_nano_structure: NanoStructure, in_new_parent: NanoStructure) -> void:
	if not _can_contain_children(in_nano_structure):
		# NanoShapes, NanoVirtualMotors, etc; are not shown in the graph
		return
	assert(_can_contain_children(in_new_parent), "Virtual Objects cannot contain children structures!")
	var structure_id: int = in_nano_structure.int_guid
	var tree_item: TreeItem = _get_structure_tree_item_or_null(structure_id)
	if not is_instance_valid(tree_item):
		return
	var parent_id: int = in_new_parent.int_guid
	var new_parent_tree_item: TreeItem = _get_structure_tree_item(parent_id)
	tree_item.get_parent().remove_child(tree_item)
	new_parent_tree_item.add_child(tree_item)
	if new_parent_tree_item.get_child_count() > 1:
		# Put the new child on top of the list
		tree_item.move_before(new_parent_tree_item.get_child(0))


func _get_structure_tree_item_or_null(in_structure_id: int) -> TreeItem:
	return _structure_id_to_tree_item.get(in_structure_id, null) as TreeItem


func _get_structure_tree_item(in_structure_id: int) -> TreeItem:
	var tree_item: TreeItem = _get_structure_tree_item_or_null(in_structure_id)
	if tree_item == null:
		tree_item = _create_structure_tree_item(in_structure_id)
	return tree_item


func _create_structure_tree_item(in_structure_id: int) -> TreeItem:
	var nano_structure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(in_structure_id)
	assert(nano_structure != null, "Unexpected invalid nano structure")
	var parent_item: TreeItem = _get_structure_tree_item(nano_structure.int_parent_guid)
	var tree_item: TreeItem = _tree.create_item(parent_item, in_structure_id)
	_structure_id_to_tree_item[in_structure_id] = tree_item
	tree_item.set_text(_TREE_COLUMN_0, nano_structure.get_structure_name())
	return tree_item


func _on_nano_structure_history_snapshot_applied() -> void:
	_structure_id_to_tree_item.clear()
	initialize(_workspace_context)
