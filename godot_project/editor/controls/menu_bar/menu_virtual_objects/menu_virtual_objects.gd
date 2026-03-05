extends NanoPopupMenu


signal request_hide


enum {
	ID_GROUPS       = 0,
	ID_ROTARY_MOTOR = 1,
	ID_LINEAR_MOTOR = 2,
	ID_SPRINGS      = 3,
	ID_PARTICLE_EMITTERS = 4,
	ID_DNA_OBJECT = 5,
}

@onready var shapes: NanoPopupMenu = $Shapes

func _ready() -> void:
	add_submenu_item(tr("Shapes"), shapes.name)


func _update_menu() -> void:
	shapes._update_menu()
	var has_context: bool = MolecularEditorContext.get_current_workspace() != null
	for i in item_count:
		set_item_disabled(i, not has_context)


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
		ID_DNA_OBJECT:
			workspace_context.create_object_parameters.set_create_mode_type(CreateObjectParameters.CreateModeType.CREATE_DNA_CHAIN)
			MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME, &"DNA Object")
			request_hide.emit()
