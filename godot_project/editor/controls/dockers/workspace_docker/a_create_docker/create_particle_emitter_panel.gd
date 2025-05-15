extends DynamicContextControl


var _particle_emitter_parameters_editor: ParticleEmitterParametersEditor

var _create_object_parameters_wref: WeakRef = weakref(null)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_particle_emitter_parameters_editor = %ParticleEmitterParametersEditor as ParticleEmitterParametersEditor


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	var structure_context: StructureContext = in_workspace_context.get_current_structure_context()
	if !is_instance_valid(structure_context) || !is_instance_valid(structure_context.nano_structure):
		return false
	_ensure_initialized(in_workspace_context)
	
	var check_object_being_created: Callable = func(in_struct: NanoStructure) -> bool:
		return in_struct is NanoParticleEmitter
	
	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS:
		if in_workspace_context.is_creating_object() and \
				in_workspace_context.peek_object_being_created(check_object_being_created):
			in_workspace_context.abort_creating_object()
		return false
	
	if in_workspace_context.is_creating_object() and \
			not in_workspace_context.peek_object_being_created(check_object_being_created):
		# Another object is being created
		in_workspace_context.abort_creating_object()
	
	if not in_workspace_context.is_creating_object():
		in_workspace_context.start_creating_object(NanoParticleEmitter.new())
	
	return true


func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _create_object_parameters_wref.get_ref() == null:
		_create_object_parameters_wref = weakref(in_workspace_context.create_object_parameters)
		var emitter_parameters: NanoParticleEmitterParameters = \
			in_workspace_context.create_object_parameters.get_new_particle_emitter_parameters()
		_particle_emitter_parameters_editor.track_parameters(emitter_parameters)
