extends DynamicContextControl


const _METADATA_ID_COUNT: int = 0
const _METADATA_ID_ELEMENT: int = 1


@onready var _tree: Tree = %Tree
@onready var _selection_description: Label = %SelectionDescription
@onready var _button_change_to: Button = %ButtonChangeTo
@onready var _element_picker_popup: PopupPanel = %ElementPickerPopup
@onready var _element_picker: VBoxContainer = %ElementPicker


var _workspace_context: WorkspaceContext


func _ready() -> void:
	_button_change_to.pressed.connect(_on_button_change_to_pressed)
	_element_picker.atom_type_change_requested.connect(_on_element_picker_atom_type_change_requested)
	_tree.item_mouse_selected.connect(_on_tree_item_mouse_selected, CONNECT_DEFERRED)
	# Second columns is fully invisibly, and is meant to only store element id
	_tree.columns = 2
	_tree.set_column_expand(_METADATA_ID_COUNT, true)
	_tree.set_column_expand(1, true)
	_tree.set_column_expand_ratio(_METADATA_ID_COUNT, 1)
	_tree.set_column_expand_ratio(1, 0)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_workspace_context = in_workspace_context
	if !in_workspace_context.selection_in_structures_changed.is_connected(_on_workspace_context_selection_in_structures_changed):
		in_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		in_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
	
	var selected_contexts: Array[StructureContext] =  \
			in_workspace_context.get_structure_contexts_with_selection()
	for context in selected_contexts:
		if context.get_selected_atoms().size() > 0:
			_refresh_target_list()
			return true
	return false


func _on_button_change_to_pressed() -> void:
	var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect()
	var desired_position: Vector2 = DisplayServer.window_get_position()
	var popup_separation: int = 4
	var button_rect: Rect2 = _button_change_to.get_global_rect().grow(popup_separation)
	desired_position += button_rect.end - Vector2(button_rect.size.x, 0)
	if desired_position.x + _element_picker_popup.size.x > screen_rect.size.x:
		desired_position.x -= (_element_picker_popup.size.x - button_rect.size.x)
	if desired_position.y + _element_picker_popup.size.y > screen_rect.size.y:
		desired_position.y -= button_rect.size.y + _element_picker_popup.size.y
	_element_picker_popup.position = desired_position
	_element_picker_popup.popup()


func _on_element_picker_atom_type_change_requested(in_to_element: int) -> void:
	_element_picker_popup.hide()
	
	var target_element_data: ElementData = PeriodicTable.get_by_atomic_number(in_to_element)
	var target_element_name: String = target_element_data.name
	
	var elements_to_change: PackedInt32Array = []
	var root: TreeItem = _tree.get_root()
	var root_element: int = root.get_metadata(_METADATA_ID_ELEMENT)
	if root_element != 0:
		elements_to_change.push_back(root_element)
	for child in root.get_children():
		if child.is_checked(0):
			elements_to_change.push_back(child.get_metadata(_METADATA_ID_ELEMENT))
	
	var did_create_undo_action: bool = false
	var selected_contexts: Array[StructureContext] =  \
			_workspace_context.get_structure_contexts_with_selection()
	for context in selected_contexts:
		var should_change_callback: Callable = func(atom_id: int) -> bool:
			var element: int = context.nano_structure.atom_get_atomic_number(atom_id)
			return element in elements_to_change
		var all_selected_atoms: PackedInt32Array = context.get_selected_atoms()
		var atoms_to_change: PackedInt32Array = Array(all_selected_atoms).filter(should_change_callback)
		if atoms_to_change.size() == 0:
			continue
		if !did_create_undo_action:
			did_create_undo_action = true
		_register_change_atom_element(context, atoms_to_change, in_to_element)
	if did_create_undo_action:
		EditorSfx.create_object()
		#<NOTE> undo/redo ensures to "reset" before/after selection,
		#+however the selection changed signal is not warrangeed to change
		#+because of that, we need to ensure the target list is updated
		_refresh_target_list()
		#</NOTE>
		var snapshot_name: String = tr(&"Change Atoms to {0}").format([target_element_name])
		_workspace_context.snapshot_moment(snapshot_name)


func _register_change_atom_element(out_structure_context: StructureContext, in_atoms_to_change: PackedInt32Array, in_to_element: int) -> void:
	assert(in_atoms_to_change.size() > 0)
	var nano_structure: NanoStructure = out_structure_context.nano_structure
	var undo_map: Dictionary = {
		#element: int = atoms: PackedInt32Array
	}
	for atom_id in in_atoms_to_change:
		var element: int = nano_structure.atom_get_atomic_number(atom_id)
		if !element in undo_map.keys():
			undo_map[element] = PackedInt32Array()
		undo_map[element].push_back(atom_id)
	
	_do_change_atom_element(nano_structure, in_atoms_to_change, in_to_element)
	_do_refresh_hydrogen_visibility_status(in_to_element, nano_structure)


func _do_change_atom_element(out_structure: NanoStructure, in_atoms_to_change: PackedInt32Array, in_to_element: int) -> void:
	out_structure.start_edit()
	for atom_id in in_atoms_to_change:
		out_structure.atom_set_atomic_number(atom_id, in_to_element)
	out_structure.end_edit()


func _do_refresh_hydrogen_visibility_status(in_to_element: int, out_structure: NanoStructure) -> void:
	if in_to_element == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
		if not out_structure.are_hydrogens_visible():
			out_structure.enable_hydrogens_visibility()


func _undo_refresh_hydrogen_visibility_status(in_hydrogens_visible_originally: bool, out_structure: NanoStructure) -> void:
	if not in_hydrogens_visible_originally:
		if out_structure.are_hydrogens_visible():
			out_structure.disable_hydrogens_visibility()


func _on_tree_item_mouse_selected(in_position: Vector2, in_mouse_button_index: int) -> void:
	if in_mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var item: TreeItem = _tree.get_item_at_position(in_position)
	if item != null:
		if item == _tree.get_root():
			if item.is_indeterminate(0):
				item.set_indeterminate(0, false)
			else:
				item.set_checked(0, !item.is_checked(0))
		_tree.get_root().set_indeterminate(0, false)
		item.propagate_check(0, true)
	_update_selection_description()


func _on_workspace_context_selection_in_structures_changed(_structure_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_refresh_target_list)


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_refresh_target_list)


func _refresh_target_list() -> void:
	var total: int = 0
	var per_element_count: Dictionary = {
		# element_id:int = count: int
	}
	
	var selected_contexts: Array[StructureContext] =  \
			_workspace_context.get_structure_contexts_with_selection()
	for context in selected_contexts:
		var atoms: PackedInt32Array = context.get_selected_atoms()
		total += atoms.size()
		for atom_id in atoms:
			var element: int = context.nano_structure.atom_get_atomic_number(atom_id)
			per_element_count[element] = per_element_count.get(element, 0) + 1
	
	_tree.clear()
	var item_all: TreeItem = _tree.create_item()
	var last_item: TreeItem = item_all
	item_all.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	if per_element_count.keys().size() == 1:
		# All selected atoms are of the same size
		_setup_tree_item(item_all, per_element_count.keys()[0], total)
		_update_selection_description()
		return
	item_all.set_text(0, "({0}) {1}".format([total, tr(&"All")]))
	item_all.set_metadata(_METADATA_ID_COUNT, total)
	item_all.set_metadata(_METADATA_ID_ELEMENT, 0)
	var elements: PackedInt32Array = per_element_count.keys()
	elements.sort()
	for element in elements:
		var item: TreeItem = _tree.create_item(item_all)
		_setup_tree_item(item, element, per_element_count[element])
		last_item = item
	var last_item_rect: Rect2 = _tree.get_item_area_rect(last_item)
	var margins_offset: float = 30
	_tree.custom_minimum_size.y = last_item_rect.end.y + margins_offset
	last_item.propagate_check(0, false)
	_update_selection_description()


func _setup_tree_item(in_item: TreeItem, in_element: int, in_count: int) -> void:
	in_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	in_item.set_editable(0, true)
	in_item.set_metadata(_METADATA_ID_COUNT, in_count)
	in_item.set_metadata(_METADATA_ID_ELEMENT, in_element)
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(in_element)
	var desc: String = "({0}) {1}: {2}(s)".format([in_count, element_data.symbol, tr(element_data.name)])
	in_item.set_text(0, desc)
	# By default do not replace hydrogens
	in_item.set_checked(0, false if in_element == 1 else true)


func _update_selection_description() -> void:
	var selected_count: int = _get_count_selected()
	if selected_count == 0:
		_selection_description.text = tr(&"No Atoms selected")
	else:
		_selection_description.text = tr(&"{0} Atoms selected").format([selected_count])


func _get_count_selected() -> int:
	var selected_count: int = 0
	var root: TreeItem = _tree.get_root()
	if root == null or root.get_metadata(_METADATA_ID_COUNT) == 0:
		return 0
	
	if !root.is_indeterminate(0):
		return root.get_metadata(_METADATA_ID_COUNT) if root.is_checked(0) else 0
	
	for child in root.get_children():
		if child.is_checked(0):
			selected_count += child.get_metadata(_METADATA_ID_COUNT)
	return selected_count

