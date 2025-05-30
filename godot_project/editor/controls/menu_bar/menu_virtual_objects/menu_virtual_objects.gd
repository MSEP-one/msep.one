extends NanoPopupMenu


signal request_hide


enum {
	ID_GROUPS       = 0,
	ID_ROTARY_MOTOR = 1,
	ID_LINEAR_MOTOR = 2,
	ID_SPRINGS      = 3,
	ID_PARTICLE_EMITTERS = 4,
}

var feature_flag_items: Dictionary = {
	ID_SPRINGS: {
		&"flag": FeatureFlagManager.FEATURE_FLAG_VIRTUAL_SPRINGS,
		&"icon": preload("res://editor/controls/menu_bar/menu_virtual_objects/icons/icon_spring_x16.svg"),
		&"text": tr("Anchors and Springs")
	},
	ID_PARTICLE_EMITTERS: {
		&"flag": FeatureFlagManager.FEATURE_FLAG_PARTICLE_EMITTERS,
		&"icon": preload("res://editor/icons/icon_particle_emitter_x16.svg"),
		&"text": tr("Particle Emitters")
	},
}

func _update_menu() -> void:
	for id: int in feature_flag_items:
		var data: Dictionary = feature_flag_items[id]
		var flag_enabled: bool = FeatureFlagManager.get_flag_value(data[&"flag"])
		var menu_item_exists: bool = get_item_index(id) != -1
		if flag_enabled != menu_item_exists:
			if flag_enabled:
				add_icon_item(data[&"icon"], data[&"text"], id)
			else:
				remove_item(get_item_index(id))


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
		ID_PARTICLE_EMITTERS:
			workspace_context.create_object_parameters.set_create_mode_type(CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS)
			MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME, &"Particle Emitters")
			request_hide.emit()
