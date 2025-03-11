extends DynamicContextControl


const MAXIMUM_HEIGTH: float = 300
const _TREE_COLUMN_0: int = 0

var _select_one_info_label: InfoLabel
var _structures_tree: Tree

var _workspace_context: WorkspaceContext
var _tracked_motor_wref: WeakRef = weakref(null) # WeakRef<NanoVirtualMotor>
var _tree_items: Dictionary = {
#	structure_id<int> = tree_item<TreeItem>
}
var _editing_connection: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_select_one_info_label = %SelectOneInfoLabel as InfoLabel
		_structures_tree = %StructuresTree as Tree
		_structures_tree.item_edited.connect(_on_structures_tree_item_edited)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(in_workspace_context)
	var check_motor_selected: Callable = func(in_structure_context: StructureContext) -> bool:
		return in_structure_context.nano_structure is NanoVirtualMotor
	
	_update_connections()
	
	var selected_structures: Array[StructureContext] = in_workspace_context.get_structure_contexts_with_selection()
	if selected_structures.any(check_motor_selected):
		return true
	
	return false


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		_workspace_context.structure_added.connect(_on_workspace_context_structure_added)
		_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
		_workspace_context.workspace.structure_reparented.connect(_on_workspace_structure_reparented)
		_workspace_context.structure_renamed.connect(_on_nano_structure_renamed)
		_workspace_context.history_snapshot_applied.connect(_on_nano_structure_history_snapshot_applied)
		_initialize_structures_list(in_workspace_context)


func _initialize_structures_list(in_workspace_context: WorkspaceContext) -> void:
	var workspace: Workspace = in_workspace_context.workspace
	var childs_of_root: Array[NanoStructure] = workspace.get_root_child_structures()
	_structures_tree.clear()
	_structures_tree.hide_root = true
	var root: TreeItem = _structures_tree.create_item()
	for child: NanoStructure in childs_of_root:
		if child.is_virtual_object():
			# Dont show virtual objects
			continue
		_add_structures_recursively(workspace, child, root, _get_tracked_motor())


func _add_structure_to_tree(
			in_structure: NanoStructure, in_parent_tree_item: TreeItem,
			in_tracked_motor: NanoVirtualMotor) -> TreeItem:
	assert(not in_structure.is_virtual_object(), "Virtual Objects are not meant to be directly connected to motors")
	var structure_item: TreeItem = _tree_items.get(in_structure.int_guid, null) as TreeItem
	if structure_item == null:
		structure_item = _structures_tree.create_item(in_parent_tree_item, in_structure.int_guid)
	var is_checkable: bool = not in_structure is NanoVirtualMotor
	structure_item.set_cell_mode(_TREE_COLUMN_0, TreeItem.CELL_MODE_CHECK if is_checkable else TreeItem.CELL_MODE_STRING)
	structure_item.set_editable(_TREE_COLUMN_0, is_checkable)
	structure_item.set_text(_TREE_COLUMN_0, in_structure.get_structure_name())
	if is_instance_valid(in_tracked_motor):
		structure_item.set_checked(_TREE_COLUMN_0, in_tracked_motor.is_structure_connected(in_structure))
	_tree_items[in_structure.int_guid] = structure_item
	return structure_item


func _add_structures_recursively(
			in_workspace: Workspace, in_structure: NanoStructure,
			in_parent_tree_item: TreeItem, in_tracked_motor: NanoVirtualMotor) -> void:
	var structure_item: TreeItem = _add_structure_to_tree(in_structure, in_parent_tree_item, in_tracked_motor)
	for child: NanoStructure in in_workspace.get_child_structures(in_structure):
		if child.is_virtual_object():
			# Dont show virtual objects
			continue
		_add_structures_recursively(in_workspace, child, structure_item, in_tracked_motor)


func _rebuild() -> void:
	_editing_connection = false
	_structures_tree.clear()
	_tree_items.clear()
	_initialize_structures_list(_workspace_context)


func _on_workspace_context_structure_added(in_structure: NanoStructure) -> void:
	if in_structure.is_virtual_object():
		# Dont show virtual objects
		return
	var parent_tree_item: TreeItem = null
	if in_structure.int_parent_guid != 0:
		# Has a parent
		parent_tree_item = _tree_items[in_structure.int_parent_guid] as TreeItem
		assert(parent_tree_item != null)
	_add_structure_to_tree(in_structure, parent_tree_item, _get_tracked_motor())


func _on_workspace_context_structure_about_to_remove(in_structure: NanoStructure) -> void:
	var structure_item: TreeItem = _tree_items.get(in_structure.int_guid, null)
	if structure_item != null:
		_free_tree_item_and_all_dependencies(structure_item)


func _free_tree_item_and_all_dependencies(in_item: TreeItem) -> void:
	for child_item: TreeItem in in_item.get_children():
		_free_tree_item_and_all_dependencies(child_item)
	var related_nano_structure_guid: int = _tree_items.find_key(in_item)
	_tree_items.erase(related_nano_structure_guid)
	in_item.free()
 

func _on_workspace_structure_reparented(in_structure: NanoStructure, in_new_parent: NanoStructure) -> void:
	if in_structure.is_virtual_object():
		# Dont show virtual objects
		return
	var structure_item: TreeItem = _tree_items.get(in_structure.int_guid, null)
	var new_parent_item: TreeItem = _tree_items.get(in_new_parent.int_guid, null)
	assert(structure_item != null and structure_item.get_parent() != null,
			"structure_item TreeItem cannot be <null> or <root>")
	assert(new_parent_item != null and new_parent_item.get_parent() != null,
			"new_parent_item TreeItem cannot be <null> or <root>")
	structure_item.get_parent().remove_child(structure_item)
	new_parent_item.add_child(structure_item)


func _on_nano_structure_renamed(in_nano_structure: NanoStructure, in_new_name: String) -> void:
	var structure_item: TreeItem = _tree_items.get(in_nano_structure.int_guid, null)
	if structure_item != null:
		structure_item.set_text(_TREE_COLUMN_0, in_new_name)


func _on_nano_structure_history_snapshot_applied() -> void:
	_rebuild()



func _update_connections() -> void:
	var strucutre_contexts: Array[StructureContext] = _workspace_context.get_all_structure_contexts()
	var selected_motors_count: int = 0
	var motor_to_track: NanoVirtualMotor = null
	var connected_groups: PackedInt32Array = []
	for context: StructureContext in strucutre_contexts:
		if context.nano_structure is NanoVirtualMotor:
			var motor: NanoVirtualMotor = context.nano_structure
			if context.is_motor_selected():
				selected_motors_count += 1
				motor_to_track = motor
				if selected_motors_count > 1:
					# early return
					break
			connected_groups.append_array(motor.get_connected_structures())
	if selected_motors_count > 1:
		# More than 1 motor selected, show message label
		_select_one_info_label.show()
		_structures_tree.hide()
		_set_tracked_motor(null)
	elif selected_motors_count == 0:
		# Entire editor should not be shown, just stop tracking any motor if this was the case
		_set_tracked_motor(null)
	else:
		_select_one_info_label.hide()
		_set_tracked_motor(motor_to_track, connected_groups)
		_structures_tree.show()
		pass


func _on_structures_tree_item_edited() -> void:
	var motor: NanoVirtualMotor = _get_tracked_motor()
	assert(motor != null, "Cannot edit connected objects while motor is <null>")
	var structure_item: TreeItem = _structures_tree.get_edited()
	if structure_item != null:
		_editing_connection = true
		var structure_id: int = _tree_items.find_key(structure_item)
		var structure_name: String = structure_item.get_text(_TREE_COLUMN_0)
		var motor_name: String = motor.get_structure_name()
		if structure_item.is_checked(_TREE_COLUMN_0):
			if not motor.is_structure_id_connected(structure_id):
				motor.connect_structure_by_id(structure_id)
				var snapshot_name: String = "Connect '{0}' to '{1}'".format([structure_name, motor_name])
				_safely_snapshot_moment(snapshot_name)
		else:
			if motor.is_structure_id_connected(structure_id):
				motor.disconnect_structure_by_id(structure_id)
				var snapshot_name: String = "Disconnect '{0}' from '{1}'".format([structure_name, motor_name])
				_safely_snapshot_moment(snapshot_name)
		_editing_connection = false


func _safely_snapshot_moment(in_snapshot_name: String) -> void:
	# Snapshot cannot happen while tree is being edited, this is because of
	# internal state of Tree class causing errors when trying to modify it while is being edited,
	# and this can happen if we edit the tree while a simulation is happening.
	# For this reason we use call_deferred to run snalshot_moment
	_workspace_context.snapshot_moment.call_deferred(in_snapshot_name)


func _set_tracked_motor(in_motor: NanoVirtualMotor, in_connected_groups: PackedInt32Array = []) -> void:
	var prev_motor: NanoVirtualMotor = _get_tracked_motor()
	if in_motor == prev_motor:
		return
	_tracked_motor_wref = weakref(in_motor)
	if is_instance_valid(prev_motor):
		prev_motor.structure_connected.disconnect(_on_tracked_motor_structure_connected)
		prev_motor.structure_disconnected.disconnect(_on_tracked_motor_structure_disconnected)
	if is_instance_valid(in_motor):
		# Dont emit signals while updating connected state
		_structures_tree.set_block_signals(true)
		in_motor.structure_connected.connect(_on_tracked_motor_structure_connected)
		in_motor.structure_disconnected.connect(_on_tracked_motor_structure_disconnected)
		var font_color: Color = _structures_tree.get_theme_color(&"font_color")
		var font_color_disabled: Color = _structures_tree.get_theme_color(&"font_color_disabled")
		for structure_id: int in _tree_items.keys():
			var structure_item: TreeItem = _tree_items.get(structure_id, null) as TreeItem
			structure_item.set_selectable(_TREE_COLUMN_0, true) # needs to be true to change selection
			structure_item.deselect(_TREE_COLUMN_0)
			if structure_item != null and structure_item.get_cell_mode(_TREE_COLUMN_0) == TreeItem.CELL_MODE_CHECK:
				var is_structure_connected: bool = in_motor.is_structure_id_connected(structure_id)
				var is_editable: bool = is_structure_connected or (not structure_id in in_connected_groups)
				structure_item.set_editable(_TREE_COLUMN_0, is_editable)
				structure_item.set_selectable(_TREE_COLUMN_0, is_editable) # needs to be true to change selection
				structure_item.set_custom_color(_TREE_COLUMN_0, font_color if is_editable else font_color_disabled)
				structure_item.set_checked(_TREE_COLUMN_0, is_structure_connected)
				
		_structures_tree.set_block_signals(false)


func _get_tracked_motor() -> NanoVirtualMotor:
	return _tracked_motor_wref.get_ref() as NanoVirtualMotor


func _on_tracked_motor_structure_connected(in_new_structure_id: int) -> void:
	if _editing_connection: return
	var structure_item: TreeItem = _tree_items.get(in_new_structure_id, null) as TreeItem
	if structure_item.get_cell_mode(_TREE_COLUMN_0) != TreeItem.CELL_MODE_CHECK:
		return
	structure_item.set_checked(_TREE_COLUMN_0, true)


func _on_tracked_motor_structure_disconnected(in_disconnected_structure_id: int) -> void:
	if _editing_connection: return
	var structure_item: TreeItem = _tree_items.get(in_disconnected_structure_id, null) as TreeItem
	if structure_item.get_cell_mode(_TREE_COLUMN_0) != TreeItem.CELL_MODE_CHECK:
		return
	structure_item.set_checked(_TREE_COLUMN_0, false)

