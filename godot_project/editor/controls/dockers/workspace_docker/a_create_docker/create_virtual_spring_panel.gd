extends DynamicContextControl

var _spring_properties_editor: SpringsPropertiesEditor
var _workspace_context_wref: WeakRef = weakref(null)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_spring_properties_editor = %SpringPropertiesEditor as SpringsPropertiesEditor
		_spring_properties_editor.user_changed_constant_force.connect(_on_spring_properties_editor_user_changed_constant_force)
		_spring_properties_editor.user_changed_equilibrium_length_is_auto.connect(_on_spring_properties_editor_user_changed_equilibrium_length_is_auto)
		_spring_properties_editor.user_changed_manual_equilibrium_length.connect(_on_spring_properties_editor_user_changed_manual_equilibrium_length)


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_ensure_workspace_initialized(in_workspace_context)
	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS:
		return false
	return true


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context_wref.get_ref() == in_workspace_context:
		return
	_workspace_context_wref = weakref(in_workspace_context)
	# Create docker doesn't need Undo/Redo. Because of this we don't execute
	# `_spring_properties_editor.ensure_undo_redo_initialized(in_workspace_context)`
	_spring_properties_editor.setup_values(
		in_workspace_context.create_object_parameters.get_spring_constant_force(),
		in_workspace_context.create_object_parameters.get_spring_equilibrium_length_is_auto(),
		in_workspace_context.create_object_parameters.get_spring_equilibrium_manual_length()
	)


func get_create_object_parameters() -> CreateObjectParameters:
	if not is_instance_valid(_workspace_context_wref.get_ref()):
		return null
	return _workspace_context_wref.get_ref().create_object_parameters as CreateObjectParameters


func _on_spring_properties_editor_user_changed_constant_force(in_force_constant: float) -> void:
	get_create_object_parameters().set_spring_constant_force(in_force_constant)


func _on_spring_properties_editor_user_changed_equilibrium_length_is_auto(in_is_auto: bool) -> void:
	get_create_object_parameters().set_spring_equilibrium_length_is_auto(in_is_auto)


func _on_spring_properties_editor_user_changed_manual_equilibrium_length(in_manual_equilibrium_length: float) -> void:
	get_create_object_parameters().set_spring_equilibrium_manual_length( in_manual_equilibrium_length)


