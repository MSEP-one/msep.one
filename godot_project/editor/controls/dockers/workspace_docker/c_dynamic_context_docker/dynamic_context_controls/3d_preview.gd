extends DynamicContextControl

@onready var three_d_preview_container: TextureRect = $"3DPreviewContainer"

var _workspace_context: WorkspaceContext = null


func _ready() -> void:
	three_d_preview_container.gui_input.connect(_on_3d_preview_container_gui_input)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		in_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		in_workspace_context.structure_contents_changed.connect(_on_workspace_context_structure_contents_changed)
		in_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
		in_workspace_context.atoms_position_in_structure_changed.connect(_on_workspace_context_atoms_position_in_structure_changed)
		in_workspace_context.virtual_object_transform_changed.connect(_on_workspace_virtual_object_transform_changed)
	
	var selected_atoms_count: int = 0
	var contexts_with_selection: Array[StructureContext] = in_workspace_context.get_structure_contexts_with_selection()
	for context in contexts_with_selection:
		# Check what is selected, return as soon as possible
		if context.nano_structure.is_virtual_object() and context.is_virtual_object_selected():
			return true
		if context.get_selected_bonds().size():
			return true
		selected_atoms_count += context.get_selected_atoms().size()
		if selected_atoms_count > 1:
			return true
	return selected_atoms_count > 1


func _on_3d_preview_container_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseMotion and in_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var rotation_strength: float = deg_to_rad(-in_event.relative.x)
		_workspace_context.get_rendering().rotate_selection_preview(rotation_strength)


func _on_workspace_context_structure_contents_changed(_in_structure_context: StructureContext) -> void:
	ScriptUtils.call_deferred_once(_internal_update)


func _on_workspace_context_selection_in_structures_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_internal_update)


func _on_workspace_context_structure_about_to_remove(_in_nano_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_internal_update)


func _on_workspace_context_atoms_position_in_structure_changed(_in_structure_context: StructureContext,
			_in_atoms: PackedInt32Array) -> void:
	ScriptUtils.call_deferred_once(_internal_update)


func _on_workspace_virtual_object_transform_changed(_structure_context: StructureContext) -> void:
	ScriptUtils.call_deferred_once(_internal_update)


func _internal_update() -> void:
	three_d_preview_container.texture = _workspace_context.get_rendering().get_selection_preview_texture()
