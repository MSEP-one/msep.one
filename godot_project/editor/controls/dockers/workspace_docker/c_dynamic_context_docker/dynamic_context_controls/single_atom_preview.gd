extends DynamicContextControl


@onready var _element_preview: Control = $ElementPreview


var _workspace_context: WorkspaceContext


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_workspace_context = in_workspace_context
	if !in_workspace_context.selection_in_structures_changed.is_connected(_on_workspace_context_selection_in_structures_changed):
		in_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
	var selected_atoms_count: int = 0
	var selected_contexts: Array[StructureContext] =  \
			in_workspace_context.get_structure_contexts_with_selection()
	for context in selected_contexts:
		if context.is_shape_selected() or context.is_motor_selected():
			return false
		selected_atoms_count += context.get_selected_atoms().size()
		if selected_atoms_count > 2 or not context.get_selected_bonds().is_empty():
			return false
	return selected_atoms_count == 1


func _on_workspace_context_selection_in_structures_changed(_structure_contexts: Array[StructureContext]) -> void:
	var selected_contexts: Array[StructureContext] =  \
			_workspace_context.get_structure_contexts_with_selection()
	if selected_contexts.size() != 1:
		return
	var context: StructureContext = selected_contexts[0]
	if context.is_shape_selected():
		return
	var selected_atoms: PackedInt32Array = context.get_selected_atoms()
	if selected_atoms.size() != 1:
		return
	var atom_idx: int = selected_atoms[0]
	var atomic_number: int = context.nano_structure.atom_get_atomic_number(atom_idx)
	_element_preview.set_element_number(atomic_number)

