extends Control


const _STRUCTURE_CHILD_LIST = preload("res://editor/controls/workspace_view/controls/structure_selector/structure_child_list/structure_child_list.tscn")


var _workspace_context: WorkspaceContext
var _top_bar_container: Control
var _structure_id_to_children_list: Dictionary = {
#	structure_id<int> = list<StructureChildList>
}
var _h_separation: int = 1
var _showing_more_childs: bool = false
var _initialzed: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_top_bar_container = %TopBarContainer as Control
		_h_separation = _top_bar_container.get(&"theme_override_constants/separation")


func initialize(out_workspace_context: WorkspaceContext) -> void:
	_initialzed = true
	_workspace_context = out_workspace_context
	out_workspace_context.structure_added.connect(_on_workspace_context_structure_added)
	out_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
	out_workspace_context.structure_renamed.connect(_on_workspace_context_structure_renamed)
	out_workspace_context.workspace.structure_reparented.connect(_on_workspace_structure_reparented)
	out_workspace_context.current_structure_context_changed.connect(_on_workspace_context_current_structure_context_changed)
	out_workspace_context.history_snapshot_applied.connect(_on_workspace_history_snapshot_applied)
	rebuild_if_needed()


func _has_point(point: Vector2) -> bool:
	if _showing_more_childs:
		return Rect2(Vector2(), size).has_point(point)
	return false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# On click Release
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed == false:
			_showing_more_childs = false
			var id_path_to_active: Array[int] = _get_id_path_to_structure(
					_workspace_context.get_current_structure_context().nano_structure)
			for structure_id: int in _structure_id_to_children_list.keys():
				var is_in_path_to_active: bool = structure_id in id_path_to_active
				var list: StructureChildList = _structure_id_to_children_list[structure_id]
				list.set_what_to_show(StructureChildList.WhatToShow.ONLY_IN_PATH_TO_ACTIVE)
				if not is_in_path_to_active:
					list.hide()
	get_viewport().set_input_as_handled()


func rebuild_if_needed() -> void:
	ScriptUtils.call_deferred_once(_rebuild_if_needed)


func _rebuild_if_needed() -> void:
	# Remove all lists from the tree, will be readded in order
	for list: StructureChildList in _structure_id_to_children_list.values():
		if list.get_parent() != null:
			list.get_parent().remove_child(list)
	var lists_not_in_path: Array = _structure_id_to_children_list.keys()
	
	var path: Array[int] = _get_id_path_to_structure(_workspace_context.get_current_structure_context().nano_structure)
	path.pop_back() # we don't need the list of the currently active structure
	for structure_id: int in path:
		lists_not_in_path.erase(structure_id)
		var list: StructureChildList = _get_or_create_list(structure_id)
		list.rebuild_list()
		# ensure list is in the _top_bar_container, if the parent is the topbar we still remove
		# and add it back, this ensure sorting the members in the desired order
		_top_bar_container.add_child(list)
		list.set_what_to_show(StructureChildList.WhatToShow.ONLY_IN_PATH_TO_ACTIVE)
		list.show()
	for structure_id: int in lists_not_in_path:
		var list: StructureChildList = _structure_id_to_children_list[structure_id]
		add_child(list)
		list.set_what_to_show(StructureChildList.WhatToShow.ONLY_IN_PATH_TO_ACTIVE)
		_hide_list_if_exists(structure_id)


func _get_id_path_to_structure(in_nano_structure: NanoStructure) -> Array[int]:
	if in_nano_structure == null:
		# Target is workspace
		return [0]
	var path: Array[int] = []
	var nano_structure: NanoStructure = in_nano_structure
	while nano_structure != null:
		path.push_back(nano_structure.int_guid)
		nano_structure = _workspace_context.workspace.get_parent_structure(nano_structure)
	path.push_back(0)
	path.reverse()
	return path


func _hide_list_if_exists(in_parent_structure_id: int) -> void:
	var list: StructureChildList = _structure_id_to_children_list.get(in_parent_structure_id, null) as StructureChildList
	if is_instance_valid(list):
		list.hide()


func _get_or_create_list(in_parent_structure_id: int) -> StructureChildList:
	var list: StructureChildList = _structure_id_to_children_list.get(in_parent_structure_id, null)
	if list == null:
		list = _STRUCTURE_CHILD_LIST.instantiate()
		_structure_id_to_children_list[in_parent_structure_id] = list
		var parent_structure_context: StructureContext = null
		if in_parent_structure_id != 0:
			var nano_structure: NanoStructure = \
					_workspace_context.workspace.get_structure_by_int_guid(in_parent_structure_id)
			parent_structure_context = _workspace_context.get_nano_structure_context(nano_structure)
		list.initialize(_workspace_context, parent_structure_context)
		list.structure_context_selected.connect(_on_structure_list_structure_context_selected)
		list.more_childs_requested.connect(_on_structure_list_more_childs_requested)
	return list


func _on_workspace_context_structure_added(_in_nano_structure: NanoStructure) -> void:
	rebuild_if_needed()


func _on_workspace_context_structure_about_to_remove(out_nano_structure: NanoStructure) -> void:
	var id: int = out_nano_structure.int_guid
	var list: StructureChildList = _structure_id_to_children_list.get(id, null) as StructureChildList
	if is_instance_valid(list):
		list.queue_free()
		_structure_id_to_children_list.erase(id)
	rebuild_if_needed()


func _on_workspace_structure_reparented(_in_struct: NanoStructure, _in_new_parent: NanoStructure) -> void:
	rebuild_if_needed()


func _on_workspace_context_structure_renamed(_in_nano_structure: NanoStructure, _in_new_name: String) -> void:
	rebuild_if_needed()


func _on_workspace_context_current_structure_context_changed(_in_structure_context: StructureContext) -> void:
	rebuild_if_needed()


func _on_workspace_history_snapshot_applied() -> void:
	rebuild_if_needed()


func _on_structure_list_structure_context_selected(out_selected_structure_context: StructureContext) -> void:
	_showing_more_childs = false
	_workspace_context.change_current_structure_context(out_selected_structure_context)
	# Select all when changing active structure
	var edited_structures: Array[StructureContext] = _workspace_context.get_editable_structure_contexts()
	for context: StructureContext in edited_structures:
		context.select_all(false)
	_workspace_context.snapshot_moment("Change Active Group")


func _on_structure_list_more_childs_requested(
			out_parent_structure_context: StructureContext,
			in_clicked_global_button_rect: Rect2) -> void:
	_showing_more_childs = true
	var parent_id: int = 0 if out_parent_structure_context == null else out_parent_structure_context.nano_structure.int_guid
	var active_id: int = _workspace_context.get_current_structure_context().nano_structure.int_guid
	var list: StructureChildList = _get_or_create_list(parent_id)
	var id_path_to_active: Array[int] = _get_id_path_to_structure(_workspace_context.get_current_structure_context().nano_structure)
	var is_docked_to_topbar: bool = parent_id in id_path_to_active and parent_id != active_id
	var desired_parent: Control = _top_bar_container if is_docked_to_topbar else self
	if list.get_parent() != desired_parent:
		if list.get_parent() != null:
			list.get_parent().remove_child(list)
		desired_parent.add_child(list)
	if list.get_parent() == self:
		var floating_position: Vector2 = in_clicked_global_button_rect.position
		floating_position.x += in_clicked_global_button_rect.size.x
		floating_position.x += _h_separation
		list.global_position = floating_position
	list.toggle_what_to_show()
	list.rebuild_list()
	list.show()
	_hide_floating_lists_not_in_path_to(null if parent_id == 0 else out_parent_structure_context.nano_structure)


func _hide_floating_lists_not_in_path_to(in_nano_structure: NanoStructure) -> void:
	var id_path_to_target: Array[int] = _get_id_path_to_structure(in_nano_structure)
	var id_path_to_active: Array[int] = _get_id_path_to_structure(_workspace_context.get_current_structure_context().nano_structure)
	for structure_id: int in _structure_id_to_children_list.keys():
		var is_in_path_to_target: bool = structure_id in id_path_to_target
		var is_in_path_to_active: bool = structure_id in id_path_to_active
		if is_in_path_to_target or is_in_path_to_active:
			var path_to_target_index: int = id_path_to_target.find(structure_id)
			if id_path_to_target.size() > path_to_target_index + 1:
				var next_id_in_path: int = id_path_to_target[path_to_target_index + 1]
				var next_is_in_path_to_active: bool = next_id_in_path in id_path_to_active
				if next_is_in_path_to_active:
					var list: StructureChildList = _structure_id_to_children_list[structure_id]
					list.set_what_to_show(StructureChildList.WhatToShow.ONLY_IN_PATH_TO_ACTIVE)
			continue
		var list: StructureChildList = _structure_id_to_children_list[structure_id]
		list.set_what_to_show(StructureChildList.WhatToShow.ONLY_IN_PATH_TO_ACTIVE)
		list.hide()
