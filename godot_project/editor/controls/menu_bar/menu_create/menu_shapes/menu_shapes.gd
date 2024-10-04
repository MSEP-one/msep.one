extends NanoPopupMenu


signal request_hide


# Shape order in this enum MUST MATCH the order
#+in CreateObjectParameters.supported_shapes
enum {
	ID_CYLINDER = 0,
	ID_CONE = 1,
	ID_PYRAMID = 2,
	ID_BOX = 3,
	ID_CAPSULE = 4,
	ID_PLANE = 5,
	ID_PRISM = 6,
	ID_SPHERE = 7,
	ID_TORUS = 8,
}


func _update_menu() -> void:
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	if !is_instance_valid(workspace):
		_update_for_context(null)
		return
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(workspace)
	_update_for_context(workspace_context)


func _update_for_context(in_context: WorkspaceContext) -> void:
	var has_context: bool = is_instance_valid(in_context)
	set_item_disabled(ID_CYLINDER, !has_context)
	set_item_disabled(ID_CONE, !has_context)
	set_item_disabled(ID_PYRAMID, !has_context)
	set_item_disabled(ID_BOX, !has_context)
	set_item_disabled(ID_CAPSULE, !has_context)
	set_item_disabled(ID_PLANE, !has_context)
	set_item_disabled(ID_PRISM, !has_context)
	set_item_disabled(ID_SPHERE, !has_context)
	set_item_disabled(ID_TORUS, !has_context)


func _on_id_pressed(in_id: int) -> void:
	if is_item_disabled(in_id):
		return
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(workspace)
	var supported_shapes: Array[PrimitiveMesh] = workspace_context.create_object_parameters.supported_shapes
	match in_id:
		ID_CYLINDER:
			_start_creating_shape(workspace_context, supported_shapes[ID_CYLINDER])
		ID_CONE:
			_start_creating_shape(workspace_context, supported_shapes[ID_CONE])
		ID_PYRAMID:
			_start_creating_shape(workspace_context, supported_shapes[ID_PYRAMID])
		ID_BOX:
			_start_creating_shape(workspace_context, supported_shapes[ID_BOX])
		ID_CAPSULE:
			_start_creating_shape(workspace_context, supported_shapes[ID_CAPSULE])
		ID_PLANE:
			_start_creating_shape(workspace_context, supported_shapes[ID_PLANE])
		ID_PRISM:
			_start_creating_shape(workspace_context, supported_shapes[ID_PRISM])
		ID_SPHERE:
			_start_creating_shape(workspace_context, supported_shapes[ID_SPHERE])
		ID_TORUS:
			_start_creating_shape(workspace_context, supported_shapes[ID_TORUS])


func _start_creating_shape(in_workspace_context: WorkspaceContext, in_shape: PrimitiveMesh) -> void:
	var structure := NanoShape.new()
	structure.set_shape(in_shape)
	in_workspace_context.start_creating_object(structure)
	in_workspace_context.create_object_parameters.set_selected_shape_for_new_objects(in_shape)
	in_workspace_context.create_object_parameters.set_create_mode_type(CreateObjectParameters.CreateModeType.CREATE_SHAPES)
	MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
	request_hide.emit()
