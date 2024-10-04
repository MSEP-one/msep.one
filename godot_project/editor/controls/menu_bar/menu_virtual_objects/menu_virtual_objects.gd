extends NanoPopupMenu


signal request_hide


enum {
	ID_GROUPS       = 0,
	ID_ROTARY_MOTOR = 1,
	ID_LINEAR_MOTOR = 2,
	ID_SPRINGS      = 3,
}


func _update_menu() -> void:
	var springs_enabled: bool = FeatureFlagManager.get_flag_value(
			FeatureFlagManager.FEATURE_FLAG_VIRTUAL_SPRINGS)
	var item_exists: bool = get_item_index(ID_SPRINGS) != -1
	if springs_enabled != item_exists:
		if springs_enabled:
			# Create the item
			add_icon_item(preload("res://editor/controls/menu_bar/menu_virtual_objects/icons/icon_spring_x16.svg"),
			tr("Anchors and Springs"), ID_SPRINGS)
		else:
			# Delete item
			remove_item(get_item_index(ID_SPRINGS))


func _on_id_pressed(in_id: int) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context() as WorkspaceContext
	match in_id:
		ID_GROUPS:
			if workspace_context.has_selection():
				MolecularEditorContext.request_workspace_docker_focus(GroupsDocker.UNIQUE_DOCKER_NAME, &"Assign Group to Selection")
			else:
				MolecularEditorContext.request_workspace_docker_focus(GroupsDocker.UNIQUE_DOCKER_NAME, &"Groups")
		ID_ROTARY_MOTOR:
			workspace_context.create_object_parameters.set_selected_virtual_motor_parameters(
				workspace_context.create_object_parameters.new_rotary_motor_parameters)
			workspace_context.create_object_parameters.set_create_mode_type(CreateObjectParameters.CreateModeType.CREATE_VIRTUAL_MOTORS)
			MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME, &"Virtual Motors")
			request_hide.emit()
		ID_LINEAR_MOTOR:
			workspace_context.create_object_parameters.set_selected_virtual_motor_parameters(
				workspace_context.create_object_parameters.new_linear_motor_parameters)
			workspace_context.create_object_parameters.set_create_mode_type(CreateObjectParameters.CreateModeType.CREATE_VIRTUAL_MOTORS)
			MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME, &"Virtual Motors")
			request_hide.emit()
		ID_SPRINGS:
			workspace_context.create_object_parameters.set_create_mode_type(CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS)
			MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME, &"Virtual Springs")
			request_hide.emit()
