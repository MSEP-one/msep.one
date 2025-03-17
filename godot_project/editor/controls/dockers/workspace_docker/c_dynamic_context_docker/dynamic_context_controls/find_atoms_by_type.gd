extends DynamicContextControl


const DELETE_ICON: Texture2D = preload("res://editor/controls/menu_bar/menu_edit/icons/icon_delete.svg")


var _workspace_context: WorkspaceContext
var _selected_types: Dictionary = {}

@onready var _elements_tree: Tree = %ElementsTree as Tree
@onready var _element_picker: ElementPickerBase = %ElementPicker as ElementPickerBase
@onready var _groups_tree: Tree = %GroupsTree as Tree


func _ready() -> void:
	_element_picker.atom_type_change_requested.connect(_on_element_picker_atom_type_change_requested)
	_elements_tree.button_clicked.connect(_on_tree_delete_button_clicked)
	_groups_tree.item_selected.connect(_on_groups_tree_item_selected)
	_refresh_filters_ui()
	_refresh_groups_ui()


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_workspace_context = in_workspace_context
	if not _workspace_context.history_changed.is_connected(_on_workspace_context_history_changed):
		_workspace_context.history_changed.connect(_on_workspace_context_history_changed)

	var visible_structures: Array[StructureContext] = \
			in_workspace_context.get_visible_structure_contexts(false)
	return not visible_structures.is_empty()


func _refresh_filters_ui() -> void:
	ScriptUtils.call_deferred_once(_refresh_tree_selection_filters)


func _refresh_groups_ui() -> void:
	ScriptUtils.call_deferred_once(_refresh_groups_tree)


func _refresh_tree_selection_filters() -> void:
	_elements_tree.clear()
	_elements_tree.visible = not _selected_types.is_empty()
	var root: TreeItem = _elements_tree.create_item()
	for atom_element: int in _selected_types:
		var tree_item: TreeItem = _elements_tree.create_item(root)
		var element_data: ElementData = PeriodicTable.get_by_atomic_number(atom_element)
		tree_item.set_text(0, element_data.name)
		tree_item.add_button(0, DELETE_ICON, atom_element)
	_elements_tree.update_minimum_size()


func _refresh_groups_tree() -> void:
	_groups_tree.clear()
	var root: TreeItem = _groups_tree.create_item()
	_groups_tree.hide_root = true
	for structure: NanoStructure in _workspace_context.workspace.get_root_child_structures():
		if not structure is AtomicStructure:
			continue
		_add_groups_recursively(structure, root)


func _add_groups_recursively(in_structure: AtomicStructure, in_parent_item: TreeItem) -> void:
	var group_item: TreeItem = _groups_tree.create_item(in_parent_item)
	var count: int = _count_found_atoms(in_structure)
	const COL_0 := 0
	group_item.set_text(COL_0, "%s (%d)" % [in_structure.get_structure_name(), count])
	group_item.set_meta(&"group_id", in_structure.int_guid)
	group_item.set_meta(&"count", count)
	group_item.set_selectable(COL_0, count > 0)
	for structure: NanoStructure in _workspace_context.workspace.get_child_structures(in_structure):
		if not structure is AtomicStructure:
			continue
		_add_groups_recursively(structure, group_item)


func _count_found_atoms(in_structure: AtomicStructure) -> int:
	var types := PackedInt32Array(_selected_types.keys())
	return _workspace_context.get_structure_context(in_structure.int_guid).count_by_type(types)


func _on_element_picker_atom_type_change_requested(element: int) -> void:
	_selected_types[element] = true
	_refresh_filters_ui()
	_refresh_groups_ui()


func _on_tree_delete_button_clicked(_item: TreeItem, _column: int, id: int, _mouse_button_index: int) -> void:
	if _selected_types.has(id):
		_selected_types.erase(id)
	_refresh_filters_ui()
	_refresh_groups_ui()


func _on_groups_tree_item_selected() -> void:
	var item: TreeItem = _groups_tree.get_selected()
	if item == null:
		return
	var group_id: int = item.get_meta(&"group_id", -1)
	var count: int = item.get_meta(&"count", 0)
	if count == 0:
		return
	var structure_context: StructureContext = _workspace_context.get_structure_context(group_id)
	assert(structure_context != null, "Invalid structure context for group with id %d" % group_id)
	_workspace_context.set_current_structure_context(structure_context)
	var types := PackedInt32Array(_selected_types.keys())
	_workspace_context.clear_all_selection()
	structure_context.select_by_type(types)
	_workspace_context.snapshot_moment("Select Atom")


func _on_workspace_context_history_changed() -> void:
	_refresh_groups_ui()
