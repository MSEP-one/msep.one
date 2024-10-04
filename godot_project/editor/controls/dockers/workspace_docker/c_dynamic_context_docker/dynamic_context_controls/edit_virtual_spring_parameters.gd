extends DynamicContextControl


var _springs_properties_editor: SpringsPropertiesEditor


var _workspace_context_wref: WeakRef = weakref(null)
var _has_selected_springs: bool = false


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(in_workspace_context)
	return _has_selected_springs


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_springs_properties_editor = %SpringsPropertiesEditor as SpringsPropertiesEditor


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext)-> void:
	if _workspace_context_wref.get_ref() != in_workspace_context:
		_workspace_context_wref = weakref(in_workspace_context)
		in_workspace_context.selection_in_structures_changed.connect(
				_on_workspace_context_selection_in_structures_changed)
		in_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
		_springs_properties_editor.ensure_undo_redo_initialized(in_workspace_context)
		_update_edited_springs()
		in_workspace_context.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)


func _on_workspace_context_selection_in_structures_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_update_edited_springs)


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_update_edited_springs)


func _update_edited_springs() -> void:
	var workspace_context: WorkspaceContext = _workspace_context_wref.get_ref() as WorkspaceContext
	var selected_contexts: Array[StructureContext] = workspace_context.get_structure_contexts_with_selection()
	var selected_contexts_with_springs: Array[StructureContext] = []
	for context: StructureContext in selected_contexts:
		if not context.get_selected_springs().is_empty():
			selected_contexts_with_springs.append(context)
	_has_selected_springs = !selected_contexts_with_springs.is_empty()
	if not _has_selected_springs:
		return
	_springs_properties_editor.start_editing_springs(selected_contexts_with_springs)


func _on_workspace_context_history_snapshot_applied() -> void:
	_update_edited_springs()
