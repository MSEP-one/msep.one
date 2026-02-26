extends DynamicContextControl


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	match in_workspace_context.create_object_parameters.get_create_mode_type():
		CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS, \
		CreateObjectParameters.CreateModeType.CREATE_FRAGMENT, \
		CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS:
			if not in_workspace_context.get_current_structure_context().nano_structure.can_create_and_delete_atoms():
				return true
		CreateObjectParameters.CreateModeType.CREATE_SHAPES, \
		CreateObjectParameters.CreateModeType.CREATE_DNA_CHAIN, \
		CreateObjectParameters.CreateModeType.CREATE_VIRTUAL_MOTORS, \
		CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS:
			if not in_workspace_context.get_current_structure_context().nano_structure.can_contain_child_structure():
				return true
	return false
