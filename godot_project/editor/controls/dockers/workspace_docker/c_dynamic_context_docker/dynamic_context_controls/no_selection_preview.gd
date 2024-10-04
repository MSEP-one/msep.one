extends DynamicContextControl


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	var visible_structures: Array[StructureContext] =  \
			in_workspace_context.get_visible_structure_contexts(false)
	return visible_structures.is_empty()
