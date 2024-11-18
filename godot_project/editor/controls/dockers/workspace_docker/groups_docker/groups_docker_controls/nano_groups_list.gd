extends DynamicContextControl


const _WORKSPACE_ROOT_ID: int = 0
const _TREE_COLUMN_0: int = 0
const _TREE_BUTTON_ID_RENAME: int = 0
const _TREE_BUTTON_ID_DISSOLVE: int = 1
const _TREE_BUTTON_ID_DELETE: int = 2
const _WIDGET_HEIGHT_RELATIVE_TO_DOCKER: float = 0.6
const _BUTTON_ICONS: Dictionary = {
	_TREE_BUTTON_ID_RENAME: preload("res://editor/controls/dockers/workspace_docker/groups_docker/groups_docker_controls/icons/icon_rename.svg"),
	_TREE_BUTTON_ID_DISSOLVE: preload("res://editor/controls/dockers/workspace_docker/groups_docker/groups_docker_controls/icons/icon_dissolve.svg"),
	_TREE_BUTTON_ID_DELETE: preload("res://editor/controls/dockers/workspace_docker/groups_docker/groups_docker_controls/icons/icon_delete.svg")
}

var _workspace_context: WorkspaceContext = null
var _structures_tree: Tree
var _structure_id_to_tree_item: Dictionary = {
#	nano_structure_id<int> = tree_item<TreeItem>
}
var _edited_structure_tree_item: TreeItem = null: set = _set_edited_structure_tree_item
var _changing_selection: bool = false
var _multiselect_served_at_frame: int = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_structures_tree = $GroupsTree as Tree
		_structures_tree.gui_input.connect(_on_structures_tree_gui_input)
		_structures_tree.multi_selected.connect(_on_structures_tree_multi_selected)
		_structures_tree.set_drag_forwarding(_on_structures_tree_get_drag_data, _on_structures_tree_can_drop_data, _on_structures_tree_drop_data)
		var root_item: TreeItem = _structures_tree.create_item(null, _WORKSPACE_ROOT_ID)
		_structure_id_to_tree_item[_WORKSPACE_ROOT_ID] = root_item
		_structures_tree.hide_root = true
		_structures_tree.button_clicked.connect(_on_structures_tree_button_clicked)
		_structures_tree.item_edited.connect(_on_structures_tree_item_edited)
		_structures_tree.item_collapsed.connect(_on_structures_tree_item_collapsed)
		_structures_tree.cell_selected.connect(_on_structure_tree_cell_selected, CONNECT_DEFERRED)
		
	if what == NOTIFICATION_READY:
		var groups_docker: GroupsDocker = _find_docker()
		assert(groups_docker, "Could not find GroupsDocker")
		groups_docker.resized.connect(_on_groups_docker_resized.bind(groups_docker))


func should_show(out_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(out_workspace_context)
	return true


func _find_docker() -> GroupsDocker:
	var parent: Node = get_parent()
	while parent != null and not parent is GroupsDocker:
		parent = parent.get_parent()
	return parent as GroupsDocker


func _on_groups_docker_resized(groups_docker: GroupsDocker) -> void:
	custom_minimum_size.y = groups_docker.size.y * _WIDGET_HEIGHT_RELATIVE_TO_DOCKER


func _on_structures_tree_get_drag_data(at_position: Vector2) -> Variant:
	var item: TreeItem = _structures_tree.get_item_at_position(at_position)
	if item == null:
		return null
	#item.get_parent().remove_child(item)
	return {
		type = &"NanoStructure reparent",
		structure_id = _structure_id_to_tree_item.find_key(item)
	}


func _on_structures_tree_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get(&"type", StringName()) != &"NanoStructure reparent":
		return false
	var drop_on_item: TreeItem = _structures_tree.get_item_at_position(at_position)
	if drop_on_item == null:
		return false
	var parent_candidate_structure_id: int = _structure_id_to_tree_item.find_key(drop_on_item)
	var dragged_structure_id: int = data.structure_id
	if dragged_structure_id == parent_candidate_structure_id:
		return false # Can't reparent the group to itself
	if parent_candidate_structure_id == 0:
		return true
	var workspace: Workspace = _workspace_context.workspace
	var parent_candidate: NanoStructure = \
			null if parent_candidate_structure_id == 0 else \
			workspace.get_structure_by_int_guid(parent_candidate_structure_id)
	var dragged_structure: NanoStructure = workspace.get_structure_by_int_guid(dragged_structure_id)
	return not workspace.is_a_ancestor_of_b(dragged_structure, parent_candidate)


func _on_structures_tree_drop_data(at_position: Vector2, data: Variant) -> void:
	var drop_on_item: TreeItem = _structures_tree.get_item_at_position(at_position)
	assert(drop_on_item != null, "Invalid item")
	var parent_structure_id: int = _structure_id_to_tree_item.find_key(drop_on_item)
	var dragged_structure_id: int = data.structure_id
	var workspace: Workspace = _workspace_context.workspace
	var parent_structure: NanoStructure = workspace.get_structure_by_int_guid(parent_structure_id)
	var dragged_structure: NanoStructure = workspace.get_structure_by_int_guid(dragged_structure_id)
	_reparent_structure(dragged_structure, parent_structure)


func _reparent_structure(in_child_structure: NanoStructure, in_new_parent: NanoStructure) -> void:
	var workspace: Workspace = get_workspace_context().workspace
	var old_parent_int_guid: int = in_child_structure.int_parent_guid
	var old_parent: NanoStructure = \
			null if old_parent_int_guid == 0 \
			else workspace.get_structure_by_int_guid(old_parent_int_guid)
	if old_parent == in_new_parent:
		return
	
	# Deselect the reparented structure (and children), but only if it's moved outside of the active group.
	var current_nano_structure: NanoStructure = get_workspace_context().get_current_structure_context().nano_structure
	if not workspace.is_a_ancestor_of_b(current_nano_structure, in_new_parent):
		# New parent is outside of the active group, 
		for structure_context: StructureContext in get_workspace_context().get_structure_contexts_with_selection():
			var nano_structure: NanoStructure = structure_context.nano_structure
			if not workspace.is_a_ancestor_of_b(in_child_structure, nano_structure) and \
					in_child_structure != nano_structure:
				continue # Not the reparented structure or one of its children, ignore.
			structure_context.clear_selection()
	
	workspace.reparent_structure(in_child_structure, in_new_parent)
	_workspace_context.snapshot_moment("Reparent group '%s'" % in_child_structure.get_structure_name())


# TODO: This method can be simplified since we're not manually handling undo redo
func _delete_structure(in_structure: NanoStructure) -> void:
	var workspace: Workspace = get_workspace_context().workspace
	assert(in_structure.int_parent_guid != 0, "Can't delete the root structure.")
	
	# Sort the descendants structures based on how deep they are in the tree,
	# starting from the structure being deleted.
	# Leaf groups (structures without children) have to be deleted first, but
	# when undoing the operation, groups have to be re-added in the reverse order.
	var hierarchy: Dictionary = {
		0: [in_structure]
	}
	assert(workspace.has_structure(in_structure))
	var descendant_structures: Array[NanoStructure] = workspace.get_descendant_structures(in_structure)
	for descendant: NanoStructure in descendant_structures:
		var level: int = 0
		var parent: NanoStructure = descendant
		while parent != in_structure:
			level += 1
			parent = workspace.get_parent_structure(parent)
		if not level in hierarchy:
			hierarchy[level] = []
		hierarchy[level].push_back(descendant)
	var undelete_levels: PackedInt32Array = range(hierarchy.size())
	var delete_levels: PackedInt32Array = undelete_levels.duplicate()
	delete_levels.reverse()
	
	# Do: If the current group will be deleted, activate the parent group first.
	if _is_current_structure_related_to(in_structure):
		_activate_parent_structure(in_structure)
	
	# Do: Delete from leaf groups
	for level: int in delete_levels:
		for structure: NanoStructure in hierarchy[level]:
			workspace.remove_structure(structure)
	
	_workspace_context.snapshot_moment("Delete group '%s'" % in_structure.get_structure_name())


func _dissolve_structure(in_structure: NanoStructure) -> void:
	assert(not in_structure.is_virtual_object(), "Virtual Objects can't be dissolved.")
	var workspace: Workspace = get_workspace_context().workspace
	var parent_structure: AtomicStructure = workspace.get_parent_structure(in_structure)
	assert(is_instance_valid(parent_structure), "Can't dissolve: structure has no parent.")
	
	var current_structure_context: StructureContext = get_workspace_context().get_current_structure_context()
	if current_structure_context.nano_structure == in_structure:
		_activate_parent_structure(in_structure)
	
	# Structure will be deleted, reparent the direct children first.
	for child_structure: NanoStructure in workspace.get_child_structures(in_structure):
		workspace.reparent_structure(child_structure, parent_structure)
	
	# clear anchor connections from structure
	var springs: PackedInt32Array = in_structure.springs_get_all()
	for spring_id: int in springs:
		var anchor_id: int = in_structure.spring_get_anchor_id(spring_id)
		var anchor: NanoVirtualAnchor = workspace.get_structure_by_int_guid(anchor_id)
		anchor.handle_spring_removed(in_structure, spring_id)
	
	var _merge_result: NanoMolecularStructure.MergeStructureResult = parent_structure.merge_structure(in_structure,
			Transform3D(), workspace)
	
	workspace.remove_structure(in_structure)
	var snapshot_name: String = "Merge group '%s' into '%s'" % [in_structure.get_structure_name(), parent_structure.get_structure_name()]
	get_workspace_context().snapshot_moment(snapshot_name)


func _is_current_structure_related_to(in_structure: NanoStructure) -> bool:
	var workspace: Workspace = get_workspace_context().workspace
	var current_structure_context: StructureContext = get_workspace_context().get_current_structure_context()
	var structure_context: StructureContext = get_workspace_context().get_nano_structure_context(in_structure)
	return current_structure_context == structure_context or \
			workspace.is_a_ancestor_of_b(in_structure, current_structure_context.nano_structure)


func _activate_parent_structure(in_structure: NanoStructure) -> void:
	var workspace: Workspace = get_workspace_context().workspace
	var parent_structure: NanoStructure = workspace.get_parent_structure(in_structure)
	var parent_context: StructureContext = get_workspace_context().get_nano_structure_context(parent_structure)
	get_workspace_context().change_current_structure_context(parent_context)


func _ensure_workspace_initialized(out_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == null:
		_workspace_context = out_workspace_context
		out_workspace_context.structure_added.connect(_on_nano_structure_added)
		out_workspace_context.structure_about_to_remove.connect(_on_nano_structure_removed)
		out_workspace_context.workspace.structure_reparented.connect(_on_workspace_structure_reparented)
		out_workspace_context.current_structure_context_changed.connect(_on_workspace_context_current_structure_context_changed)
		out_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		out_workspace_context.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)
		_rebuild()


func _on_workspace_context_history_snapshot_applied() -> void:
	for structure_id: int in _structure_id_to_tree_item:
		var tree_item: TreeItem = _get_structure_tree_item_or_null(structure_id)
		if tree_item != null:
			var tree_item_parent: TreeItem = tree_item.get_parent()
			if is_instance_valid(tree_item_parent):
				tree_item_parent.remove_child(tree_item)
				_free_tree_item_and_all_dependencies(tree_item)
	
	_structures_tree.clear()
	_structure_id_to_tree_item.clear()
	var root_item: TreeItem = _structures_tree.create_item(null, _WORKSPACE_ROOT_ID)
	_structure_id_to_tree_item[_WORKSPACE_ROOT_ID] = root_item
	_rebuild()


func _rebuild() -> void:
	var structures: Array = _workspace_context.workspace.get_structures()
	for nano_structure: NanoStructure in structures:
		# Ensure all tree items exists
		if _can_appear_in_tree(nano_structure):
			_get_structure_tree_item(nano_structure.int_guid)
	_edited_structure_tree_item = _get_structure_tree_item(_workspace_context.get_current_structure_context().nano_structure.int_guid)


func get_workspace_context() -> WorkspaceContext:
	return _workspace_context


func _on_structures_tree_gui_input(in_event: InputEvent) -> void:
	if not in_event is InputEventMouseButton or not in_event.double_click:
		return
	var activated_item: TreeItem = _structures_tree.get_item_at_position(in_event.position)
	if activated_item != null and activated_item != _edited_structure_tree_item:
		var structure_id: int = _structure_id_to_tree_item.find_key(activated_item)
		if structure_id == 0:
			# Root workspace cannot be activated
			return
		
		var nano_structure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(structure_id)
		var structure_context: StructureContext = _workspace_context.get_nano_structure_context(nano_structure)
		_workspace_context.change_current_structure_context(structure_context)
		# We changed currently active structure, now lets make the content's selected following
		# "group propagation rules"
		_on_structures_tree_multi_selected(activated_item, _TREE_COLUMN_0, true)


func _on_structures_tree_multi_selected(out_item: TreeItem, _in_column: int, in_is_selected: bool) -> void:
	if _changing_selection or not in_is_selected: return
	_multiselect_served_at_frame = Engine.get_process_frames()
	var workspace_context: WorkspaceContext = get_workspace_context()
	var structure_id: int = _structure_id_to_tree_item.find_key(out_item)
	var clicked_structure_context: StructureContext = workspace_context.get_structure_context(structure_id)
	if not clicked_structure_context.is_editable():
		return
	
	_changing_selection = true
	workspace_context.clear_all_selection()
	clicked_structure_context.select_all(true)
	_changing_selection = false



func _on_structure_tree_cell_selected() -> void:
	if _changing_selection:
		return
	const NMB_OF_FRAMES_TO_IGNORE_AFTER_MULTISELECTED_SIGNAL = 3
	var frame_delta: int = Engine.get_process_frames() - _multiselect_served_at_frame
	if frame_delta < NMB_OF_FRAMES_TO_IGNORE_AFTER_MULTISELECTED_SIGNAL:
		# workaround, we want for _on_structure_tree_cell_selected to never be called together with
		# _on_structures_tree_multi_selected as a result of the same user click
		return
	var workspace_context: WorkspaceContext = get_workspace_context()
	var tree_item: TreeItem = _structures_tree.get_selected()
	if not is_instance_valid(tree_item):
		return
	
	var structure_id: int = _structure_id_to_tree_item.find_key(tree_item)
	var structure_context: StructureContext = workspace_context.get_structure_context(structure_id)
	_changing_selection = true
	workspace_context.clear_all_selection()
	structure_context.select_all(true)
	_changing_selection = false


func _on_structures_tree_button_clicked(out_item: TreeItem, _in_column: int, in_id: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var structure_id: int = _structure_id_to_tree_item.find_key(out_item)
	var workspace: Workspace = get_workspace_context().workspace
	var structure_clicked: NanoStructure = workspace.get_structure_by_int_guid(structure_id)
	match in_id:
		_TREE_BUTTON_ID_RENAME:
			out_item.select(_TREE_COLUMN_0)
			# HACK: ensure item rect internal state is updated, this step happens during draw step
			# wait for the control to redraw before proceed to edit selected item
			await _structures_tree.draw
			_structures_tree.edit_selected(true)
		_TREE_BUTTON_ID_DISSOLVE:
			_dissolve_structure(structure_clicked)
		_TREE_BUTTON_ID_DELETE:
			_delete_structure(structure_clicked)
		_:
			assert(false, "Invalid button ID '%d'" % in_id)
			return


func _on_structures_tree_item_edited() -> void:
	var edited_item: TreeItem = _structures_tree.get_edited()
	var structure_id: int = _structure_id_to_tree_item.find_key(edited_item)
	assert(structure_id != -1, "Invalid item tree")
	var new_group_name: String = edited_item.get_text(_TREE_COLUMN_0)
	var nano_structure: NanoStructure = get_workspace_context().workspace.get_structure_by_int_guid(structure_id)
	if new_group_name.is_empty() or nano_structure.get_structure_name() == new_group_name:
		# Don't change group name, ensure tree view is reset to original value
		edited_item.set_text(_TREE_COLUMN_0, nano_structure.get_structure_name())
		return
	nano_structure.set_structure_name(new_group_name)
	_workspace_context.snapshot_moment("Group Renamed (" + new_group_name + ")")


func _on_structures_tree_item_collapsed(in_item: TreeItem) -> void:
	# WORKAROUND: the `hide_folding` property causes grafical glitches
	# To prevent them, instead of seting such property to true, we are using empty textures for
	# folding arrows. Since it is still posible to fold the list in other ways we need to revert
	# the folding as soon as it happens
	in_item.collapsed = false
	

func _on_nano_structure_added(in_nano_structure: NanoStructure) -> void:
	if not _can_appear_in_tree(in_nano_structure):
		return
	_get_structure_tree_item(in_nano_structure.int_guid)


func _on_nano_structure_removed(in_nano_structure: NanoStructure) -> void:
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


func _on_workspace_structure_reparented(in_struct: NanoStructure, in_new_parent: NanoStructure) -> void:
	if not _can_appear_in_tree(in_struct):
		return
	var child_id: int = in_struct.int_guid
	var parent_id: int = 0 if in_new_parent == null else in_new_parent.int_guid
	var child_item: TreeItem = _get_structure_tree_item(child_id)
	var parent_item: TreeItem = _get_structure_tree_item(parent_id)
	child_item.get_parent().remove_child(child_item)
	parent_item.add_child(child_item)
	if parent_item.get_child_count() > 1:
		# Put the new child on top of the list
		child_item.move_before(parent_item.get_child(0))


func _on_workspace_context_current_structure_context_changed(in_structure_context: StructureContext) -> void:
	if not _can_appear_in_tree(in_structure_context.nano_structure):
		return
	var tree_item: TreeItem = _get_structure_tree_item_or_null(in_structure_context.nano_structure.int_guid)
	if is_instance_valid(tree_item):
		_edited_structure_tree_item = tree_item


func _on_workspace_context_selection_in_structures_changed(in_structure_contexts: Array[StructureContext]) -> void:
	for context: StructureContext in in_structure_contexts:
		var item: TreeItem = _get_structure_tree_item_or_null(context.nano_structure.int_guid)
		if not item:
			continue
		if context.is_fully_selected():
			item.select(_TREE_COLUMN_0)
		else:
			item.deselect(_TREE_COLUMN_0)


## Returns true is the structure is a molecular structure.
## Returns false otherwise.
## NanoShape and Motors, etc can't be displayed here but shapes also extends NanoMolecularStructure
## so we have to be explicit on the check here.
func _can_appear_in_tree(nano_structure: NanoStructure) -> bool:
	return not nano_structure.is_virtual_object()


func _get_structure_tree_item_or_null(in_structure_id: int) -> TreeItem:
	return _structure_id_to_tree_item.get(in_structure_id, null) as TreeItem


func _get_structure_tree_item(in_structure_id: int) -> TreeItem:
	var tree_item: TreeItem = _get_structure_tree_item_or_null(in_structure_id)
	if tree_item == null:
		tree_item = _create_structure_tree_item(in_structure_id)
	return tree_item


func _create_structure_tree_item(in_structure_id: int) -> TreeItem:
	var nano_structure: NanoStructure = get_workspace_context().workspace.get_structure_by_int_guid(in_structure_id)
	assert(nano_structure != null, "Unexpected invalid nano structure")
	assert(_can_appear_in_tree(nano_structure), "Attempting to create an item that should not appear in tree")
	var structure_context: StructureContext = get_workspace_context().get_nano_structure_context(nano_structure)
	var parent_item: TreeItem = _get_structure_tree_item(nano_structure.int_parent_guid)
	var tree_item: TreeItem = _structures_tree.create_item(parent_item, in_structure_id)
	_structure_id_to_tree_item[in_structure_id] = tree_item
	if structure_context == get_workspace_context().get_current_structure_context():
		_edited_structure_tree_item = tree_item
	tree_item.set_text(_TREE_COLUMN_0, nano_structure.get_structure_name())
	tree_item.add_button(_TREE_COLUMN_0, _BUTTON_ICONS[_TREE_BUTTON_ID_RENAME],
			_TREE_BUTTON_ID_RENAME, false, tr(&"Edit the name of this structure"))
	if nano_structure != get_workspace_context().workspace.get_main_structure():
		tree_item.add_button(_TREE_COLUMN_0, _BUTTON_ICONS[_TREE_BUTTON_ID_DISSOLVE],
				_TREE_BUTTON_ID_DISSOLVE, false,
				tr(&"Dissolve this structure (make it's contents part if the parent structure)"))
		tree_item.add_button(_TREE_COLUMN_0, _BUTTON_ICONS[_TREE_BUTTON_ID_DELETE],
				_TREE_BUTTON_ID_DELETE, false,
				tr(&"Delete this structure"))
	return tree_item

func _set_edited_structure_tree_item(out_tree_item: TreeItem) -> void:
	if _edited_structure_tree_item == out_tree_item:
		return
	if is_instance_valid(_edited_structure_tree_item):
		# Remove highlight
		_edited_structure_tree_item.clear_custom_color(_TREE_COLUMN_0)
	_edited_structure_tree_item = out_tree_item
	if is_instance_valid(out_tree_item):
		# Set highlight
		out_tree_item.set_custom_color(_TREE_COLUMN_0, Color.YELLOW)
