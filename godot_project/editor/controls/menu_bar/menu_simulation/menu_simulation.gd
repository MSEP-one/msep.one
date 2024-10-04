extends NanoPopupMenu


enum {
	ID_RELAXATION                     = 0,
	ID_MOLECULAR_MECHANICS_SIMULATION = 1,
	ID_VALIDATE_BONDS                 = 2,
}


func _update_menu() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	_update_for_context(workspace_context)


func _update_for_context(in_context: WorkspaceContext) -> void:
	var can_run_simulations: bool = is_instance_valid(in_context)
	set_item_disabled(get_item_index(ID_RELAXATION), !can_run_simulations)
	set_item_disabled(get_item_index(ID_MOLECULAR_MECHANICS_SIMULATION), !can_run_simulations)
	set_item_disabled(get_item_index(ID_VALIDATE_BONDS), !can_run_simulations)


func _on_id_pressed(in_id: int) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context() as WorkspaceContext
	match in_id:
		ID_RELAXATION:
			workspace_context.create_object_parameters.set_simulation_type(
					CreateObjectParameters.SimulationType.RELAXATION)
			MolecularEditorContext.request_workspace_docker_focus(SimulationsDocker.UNIQUE_DOCKER_NAME, &"Relax")
		ID_MOLECULAR_MECHANICS_SIMULATION:
			workspace_context.create_object_parameters.set_simulation_type(
					CreateObjectParameters.SimulationType.MOLECULAR_MECHANICS)
			MolecularEditorContext.request_workspace_docker_focus(SimulationsDocker.UNIQUE_DOCKER_NAME, &"Molecular Dynamics Simulation")
		ID_VALIDATE_BONDS:
			workspace_context.create_object_parameters.set_simulation_type(
					CreateObjectParameters.SimulationType.VALIDATION)
			MolecularEditorContext.request_workspace_docker_focus(SimulationsDocker.UNIQUE_DOCKER_NAME, &"Validate Model")
