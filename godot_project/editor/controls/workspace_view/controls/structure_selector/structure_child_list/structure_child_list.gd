class_name StructureChildList extends VBoxContainer
## This class is a container of buttons representing Structures
## Is a helper for the StructureSelectorBar


## Emitted when a button representing a child structure of this list is clicked.
## This signal is being forwarded from StructureSelectorButton
signal structure_context_selected(out_structure_context: StructureContext)
## Emited when one of the "More Children" buttons contained in this list is pressed.
## This signal is being forwarded from StructureSelectorButton
signal more_childs_requested(out_parent_structure_context: StructureContext, clicked_global_button_rect: Rect2)


enum WhatToShow {
	ONLY_IN_PATH_TO_ACTIVE,
	ALL
}
const _STRUCTURE_SELECTOR_BUTTON_SCN = preload("res://editor/controls/workspace_view/controls/structure_selector/structure_button/structure_selector_button.tscn")

var _what_to_show: WhatToShow = WhatToShow.ONLY_IN_PATH_TO_ACTIVE
var _workspace_context: WorkspaceContext
var _parent_structure_context: StructureContext
var _child_id_to_selector_button: Dictionary = {
#	child_structure_id<int> = selector_button<StructureSelectorButton>
}
var _initialzed: bool = false

func initialize(out_workspace_context: WorkspaceContext, in_parent_structure_context: StructureContext) -> void:
	assert(is_instance_valid(out_workspace_context), "Invalid workspace context!")
	_workspace_context = out_workspace_context
	_parent_structure_context = in_parent_structure_context
	_initialzed = true
	rebuild_list()
	_workspace_context.structure_added.connect(_on_workspace_context_structure_added)
	_workspace_context.structure_removed.connect(_on_workspace_context_structure_removed)
	_workspace_context.workspace.structure_reparented.connect(_on_workspace_structure_reparented)
	_workspace_context.history_snapshot_applied.connect(_on_workspace_history_snapshot_applied)


func get_parent_structure_context() -> StructureContext:
	return _parent_structure_context


func rebuild_list() -> void:
	assert(_initialzed, "Cannot rebuild list when context is not initialized")
	for child: Node in get_children():
		child.queue_free()
	_child_id_to_selector_button.clear()
	var children_structures: Array[NanoStructure] = _get_child_structures()
	var path_to_active_structure: Array[NanoStructure] = _get_path_to_current_structure()
	for child: NanoStructure in children_structures:
		var structure_context: StructureContext = _workspace_context.get_nano_structure_context(child)
		var is_in_path: bool = child in path_to_active_structure
		var selector_button: StructureSelectorButton = _child_id_to_selector_button.get(child.int_guid, null)
		if selector_button == null:
			selector_button = _STRUCTURE_SELECTOR_BUTTON_SCN.instantiate()
			_child_id_to_selector_button[child.int_guid] = selector_button
			selector_button.structure_context_selected.connect(_on_selector_button_structure_context_selected)
			selector_button.more_childs_requested.connect(_on_selector_button_more_childs_requested)
			selector_button.initialize(_workspace_context, structure_context)
			add_child(selector_button)
			selector_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector_button.visible = true if is_in_path or _what_to_show == WhatToShow.ALL else false
		selector_button.update_controls()
		if is_in_path:
			# At the end of the frame make this button the first of the list
			move_child.call_deferred(selector_button, 0)


func set_what_to_show(in_what_to_show: WhatToShow) -> void:
	_what_to_show = in_what_to_show
	var path_to_active_structure: Array[NanoStructure] = _get_path_to_current_structure()
	for child in get_children():
		if child.is_queued_for_deletion():
			continue
		if child is StructureSelectorButton:
			var is_in_path: bool = child.get_structure_context().nano_structure in path_to_active_structure
			child.visible = true if is_in_path or _what_to_show == WhatToShow.ALL else false


func toggle_what_to_show() -> void:
	const WHAT_TO_SHOW_INVERTED: Dictionary = {
		WhatToShow.ONLY_IN_PATH_TO_ACTIVE: WhatToShow.ALL,
		WhatToShow.ALL: WhatToShow.ONLY_IN_PATH_TO_ACTIVE
	}
	set_what_to_show(WHAT_TO_SHOW_INVERTED[_what_to_show])


func _on_workspace_context_structure_added(in_nano_structure: NanoStructure) -> void:
	var other_parent_id: int = in_nano_structure.int_parent_guid
	var self_parent_id: int = \
			0 if _parent_structure_context == null else _parent_structure_context.nano_structure.int_guid
	if other_parent_id == self_parent_id:
		rebuild_list()


func _on_workspace_context_structure_removed(in_nano_structure: NanoStructure) -> void:
	var other_parent_id: int = in_nano_structure.int_parent_guid
	var self_parent_id: int = \
			0 if _parent_structure_context == null else _parent_structure_context.nano_structure.int_guid
	if other_parent_id == self_parent_id:
		rebuild_list()


func _on_workspace_structure_reparented(_in_nano_structure: NanoStructure, _in_new_parent: NanoStructure) -> void:
	# Dont take risks, just rebuild
	rebuild_list()


func _on_workspace_history_snapshot_applied() -> void:	
	rebuild_list()


func _on_selector_button_structure_context_selected(out_structure_context: StructureContext) -> void:
	structure_context_selected.emit(out_structure_context)


func _on_selector_button_more_childs_requested(
			out_parent_structure_context: StructureContext,
			in_clicked_global_button_rect: Rect2) -> void:
	more_childs_requested.emit(out_parent_structure_context, in_clicked_global_button_rect)


func _get_child_structures() -> Array[NanoStructure]:
	var children_structures: Array[NanoStructure]
	if _parent_structure_context == null or _parent_structure_context.is_queued_for_deletion():
		children_structures = _workspace_context.workspace.get_root_child_structures()
	else:
		children_structures = _workspace_context.workspace.get_child_structures(
				_parent_structure_context.nano_structure)
	var is_valid_group: Callable = func(in_nano_structure: NanoStructure) -> bool:
		return not in_nano_structure.is_virtual_object()
	return children_structures.filter(is_valid_group)


func _get_path_to_current_structure() -> Array[NanoStructure]:
	var path: Array[NanoStructure] = []
	if _workspace_context.get_current_structure_context() == null:
		return path
	var nano_structure: NanoStructure = \
			_workspace_context.get_current_structure_context().nano_structure
	while nano_structure != null:
		path.push_back(nano_structure)
		nano_structure = _workspace_context.workspace.get_parent_structure(nano_structure)
	path.reverse()
	return path
