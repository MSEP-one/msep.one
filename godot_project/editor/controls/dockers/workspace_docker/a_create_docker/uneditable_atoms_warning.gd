extends DynamicContextControl


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	if not in_workspace_context.create_object_parameters.get_create_mode_type() in [
			CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS,
			CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS,
		]:
		return false
	if not in_workspace_context.get_current_structure_context().nano_structure.can_create_and_delete_atoms():
		return true
	return false
