extends DynamicContextControl


var _select_one_info_label: InfoLabel
var _particle_emitter_parameters_editor: ParticleEmitterParametersEditor
var _escape_velocity_warning_label: InfoLabel

var _workspace_context: WorkspaceContext
var _tracked_emitter: NanoParticleEmitter

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_select_one_info_label = %SelectOneInfoLabel as InfoLabel
		_particle_emitter_parameters_editor = %ParticleEmitterParametersEditor as ParticleEmitterParametersEditor
		_escape_velocity_warning_label = %EscapeVelocityWarningLabel as InfoLabel


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_workspace_context = in_workspace_context
	_particle_emitter_parameters_editor.ensure_undo_redo_initialized(in_workspace_context)
	var check_particle_emitter_selected: Callable = func(in_structure_context: StructureContext) -> bool:
		return in_structure_context.nano_structure is NanoParticleEmitter
	
	var selected_structures: Array[StructureContext] = in_workspace_context.get_structure_contexts_with_selection()
	
	_update_contents(selected_structures)
	if selected_structures.any(check_particle_emitter_selected):
		return true
	
	return false



func _update_contents(in_selected_structures: Array[StructureContext] ) -> void:
	var selected_emitters_count: int = 0
	var emitter_to_track: NanoParticleEmitter = null
	for context: StructureContext in in_selected_structures:
		if context.nano_structure is NanoParticleEmitter:
			selected_emitters_count += 1
			emitter_to_track = context.nano_structure as NanoParticleEmitter
			if selected_emitters_count > 1:
				break # early stop
	if selected_emitters_count > 1:
		# More than 1 emitter selected, show message label
		_select_one_info_label.show()
		_particle_emitter_parameters_editor.hide()
		_particle_emitter_parameters_editor.track_parameters(null)
		_escape_velocity_warning_label.hide()
		emitter_to_track = null
	elif selected_emitters_count == 0:
		# Entire editor should not be shown, just stop tracking any parameter if this was the case
		_particle_emitter_parameters_editor.track_parameters(null)
	else:
		# Selected unique linear emitter
		_select_one_info_label.hide()
		_particle_emitter_parameters_editor.track_parameters(emitter_to_track.get_parameters())
		_particle_emitter_parameters_editor.show()
		_escape_velocity_warning_label.show()
	if emitter_to_track != _tracked_emitter:
		if _tracked_emitter != null:
			_tracked_emitter.get_parameters().changed.disconnect(_on_tracked_parameters_changed)
			_tracked_emitter.transform_changed.disconnect(_on_tracked_emitter_transform_changed)
		if emitter_to_track != null:
			emitter_to_track.get_parameters().changed.connect(_on_tracked_parameters_changed)
			emitter_to_track.transform_changed.connect(_on_tracked_emitter_transform_changed.unbind(1))
	_tracked_emitter = emitter_to_track
	_update_escape_velocity_warning()


func _on_tracked_parameters_changed() -> void:
	_update_escape_velocity_warning()


func _on_tracked_emitter_transform_changed() -> void:
	_update_escape_velocity_warning()


func _update_escape_velocity_warning() -> void:
	if _tracked_emitter == null:
		_escape_velocity_warning_label.hide()
		return
	var emitter_parameters: NanoParticleEmitterParameters = _tracked_emitter.get_parameters()
	var axis_direction: Vector3 = _tracked_emitter.get_transform().basis * Vector3.FORWARD
	var template_aabb: AABB = emitter_parameters.get_molecule_template().get_aabb()
	if WorkspaceUtils.is_particle_emitter_escape_velocity_safe(
			_workspace_context, emitter_parameters, template_aabb, axis_direction):
		_escape_velocity_warning_label.hide()
	else:
		_escape_velocity_warning_label.message = tr("Initial speed may be not large enough to leave emission space without crowding the space.\nThis could lead to a simulation Failure.\nYou may want to increase the [b]'Initial Speed'[/b] or [b]'Every'[/b] rate to ensure simulation doesn't fail")
		_escape_velocity_warning_label.show()
