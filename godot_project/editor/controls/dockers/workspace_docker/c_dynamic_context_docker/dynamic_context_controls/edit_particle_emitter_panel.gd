extends DynamicContextControl


var _select_one_info_label: InfoLabel
var _particle_emitter_parameters_editor: ParticleEmitterParametersEditor


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_select_one_info_label = %SelectOneInfoLabel as InfoLabel
		_particle_emitter_parameters_editor = %ParticleEmitterParametersEditor as ParticleEmitterParametersEditor


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_particle_emitter_parameters_editor.ensure_undo_redo_initialized(in_workspace_context)
	var check_particle_emitter_selected: Callable = func(in_structure_context: StructureContext) -> bool:
		return in_structure_context.nano_structure is NanoParticleEmitter
	
	var selected_structures: Array[StructureContext] = in_workspace_context.get_structure_contexts_with_selection()
	
	_update_contents(selected_structures)
	if selected_structures.any(check_particle_emitter_selected):
		return true
	
	return false



func _update_contents(in_selected_structures: Array[StructureContext] ) -> void:
	var selected_motors_count: int = 0
	var parameters_to_track: NanoParticleEmitterParameters = null
	for context: StructureContext in in_selected_structures:
		if context.nano_structure is NanoParticleEmitter:
			selected_motors_count += 1
			parameters_to_track = context.nano_structure.get_parameters()
			if selected_motors_count > 1:
				break # early stop
	if selected_motors_count > 1:
		# More than 1 motor selected, show message label
		_select_one_info_label.show()
		_particle_emitter_parameters_editor.hide()
		_particle_emitter_parameters_editor.track_parameters(null)
	elif selected_motors_count == 0:
		# Entire editor should not be shown, just stop tracking any parameter if this was the case
		_particle_emitter_parameters_editor.track_parameters(null)
	else:
		# Selected unique linear motor
		_select_one_info_label.hide()
		_particle_emitter_parameters_editor.track_parameters(parameters_to_track)
		_particle_emitter_parameters_editor.show()
