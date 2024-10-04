extends DynamicContextControl


const DELETE_ICON: Texture2D = preload("res://editor/controls/menu_bar/menu_edit/icons/icon_delete.svg")


var _workspace_context: WorkspaceContext
var _selected_types: Dictionary = {}

@onready var _tree: Tree = %Tree
@onready var _button_select: Button = %ButtonSelect
@onready var _button_add_to_selection: Button = %ButtonAddToSelection
@onready var _button_clear_filters: Button = %ButtonClearFilters
@onready var _element_picker: VBoxContainer = %ElementPicker


func _ready() -> void:
	_button_select.pressed.connect(_select_atoms_by_type.bind(true))
	_button_add_to_selection.pressed.connect(_select_atoms_by_type)
	_button_clear_filters.pressed.connect(_clear_filters)
	_element_picker.atom_type_change_requested.connect(_on_element_picker_atom_type_change_requested)
	_tree.button_clicked.connect(_on_tree_delete_button_clicked)
	_refresh_ui()


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_workspace_context = in_workspace_context
	if not _workspace_context.selection_in_structures_changed.is_connected(_on_selection_in_structures_changed):
		_workspace_context.selection_in_structures_changed.connect(_on_selection_in_structures_changed)

	var visible_structures: Array[StructureContext] = \
			in_workspace_context.get_visible_structure_contexts(false)
	return not visible_structures.is_empty()


func _refresh_ui() -> void:
	ScriptUtils.call_deferred_once(_refresh_tree_selection_filters)
	ScriptUtils.call_deferred_once(_refresh_buttons_visibility)


func _refresh_tree_selection_filters() -> void:
	_tree.clear()
	_tree.visible = not _selected_types.is_empty()
	var root: TreeItem = _tree.create_item()
	for atom_element: int in _selected_types:
		var tree_item: TreeItem = _tree.create_item(root)
		var element_data: ElementData = PeriodicTable.get_by_atomic_number(atom_element)
		tree_item.set_text(0, element_data.name)
		tree_item.add_button(0, DELETE_ICON, atom_element)
	_tree.update_minimum_size()


func _refresh_buttons_visibility() -> void:
	var no_types_selected: bool = _selected_types.is_empty()
	_button_select.disabled = no_types_selected
	_button_add_to_selection.disabled = no_types_selected or not _workspace_context.has_selection()
	_button_clear_filters.visible = not no_types_selected


func _clear_filters() -> void:
	_selected_types.clear()
	_refresh_ui()


func _select_atoms_by_type(replace_current_selection: bool = false) -> void:
	if replace_current_selection:
		_workspace_context.clear_all_selection()
	var types := PackedInt32Array(_selected_types.keys())
	_workspace_context.select_by_type(types)
	_clear_filters()


func _on_element_picker_atom_type_change_requested(element: int) -> void:
	_selected_types[element] = true
	_refresh_ui()


func _on_tree_delete_button_clicked(_item: TreeItem, _column: int, id: int, _mouse_button_index: int) -> void:
	if _selected_types.has(id):
		_selected_types.erase(id)
	_refresh_ui()


func _on_selection_in_structures_changed(_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_refresh_buttons_visibility)
