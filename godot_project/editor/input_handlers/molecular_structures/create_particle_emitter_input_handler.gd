extends InputHandlerCreateObjectBase

var _new_emitter_parameters: NanoParticleEmitterParameters
var _rendering: Rendering
var _press_down_position: Vector2 = Vector2(-100, -100)

# region virtual

## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return false


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(in_structure_context: StructureContext) -> bool:
	return in_structure_context.nano_structure is NanoParticleEmitter \
			and in_structure_context.workspace_context.is_creating_object() \
			and in_structure_context.workspace_context.create_object_parameters.get_create_mode_enabled() \
			and in_structure_context.workspace_context.create_object_parameters.get_create_mode_type() == \
					CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	_new_emitter_parameters = in_context.create_object_parameters.get_new_particle_emitter_parameters()
	var editor_viewport: WorkspaceEditorViewport = get_workspace_context().get_editor_viewport()
	_rendering = editor_viewport.get_rendering() as Rendering
	var menu: NanoRingMenu = editor_viewport.get_ring_menu()
	menu.closed.connect(_on_ring_menu_closed)
	
	in_context.current_structure_context_changed.connect(_on_current_structure_context_changed)
	in_context.create_object_parameters.create_distance_method_changed.connect(_on_create_distance_method_changed)
	in_context.create_object_parameters.creation_distance_from_camera_factor_changed.connect(_on_creation_distance_from_camera_factor_changed)
	_on_current_structure_context_changed(in_context.get_current_structure_context())
	_on_creation_distance_from_camera_factor_changed(in_context.create_object_parameters.get_creation_distance_from_camera_factor())
	
	update_preview_position()
	_rendering.particle_emitter_preview_hide()


func _on_current_structure_context_changed(in_context: StructureContext) -> void:
	# Always hide until a mouse event is detected
	if !get_workspace_context().is_creating_object() or !in_context.nano_structure is NanoParticleEmitter:
		_rendering.particle_emitter_preview_hide()


func _on_ring_menu_closed() -> void:
	if get_workspace_context().create_object_parameters.get_create_mode_type() == \
			CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS \
			and get_workspace_context().create_object_parameters.get_create_mode_enabled():
		update_preview_position()
		_rendering.particle_emitter_preview_show()


func _on_create_distance_method_changed(_in_new_method: Variant) -> void:
	if _rendering.is_particle_emitter_preview_visible():
		update_preview_position()


func _on_creation_distance_from_camera_factor_changed(_in_distance_factor: float) -> void:
	if _rendering.is_particle_emitter_preview_visible():
		update_preview_position()


## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, in_context: StructureContext) -> bool:
	if in_input_event is InputEventMouseMotion:
		var has_modifiers: bool = input_has_modifiers(in_input_event)
		if has_modifiers:
			_rendering.particle_emitter_preview_hide()
			return false
		
		update_preview_position()
		_rendering.particle_emitter_preview_show()
		return false
	if in_input_event is InputEventMouseButton:
		if in_input_event.button_index == MOUSE_BUTTON_LEFT and !in_input_event.pressed:
			if _press_down_position.distance_squared_to(in_input_event.global_position) > MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED:
				return false
			var has_modifiers: bool = input_has_modifiers(in_input_event)
			if has_modifiers:
				return false
			assert(in_context.workspace_context.is_creating_object(), "This input handler should never work unless a particle emitter is being created")
			var selected_structures: Array[StructureContext] = in_context.workspace_context.get_structure_contexts_with_selection()
			var selection_per_structure: Dictionary = {} #{StructureContext : SelectionSnapshot<Dictionary>}
			for structure_context in selected_structures:
				selection_per_structure[structure_context] = structure_context.get_selection_snapshot()
				
			var position: Vector3 = _rendering.particle_emitter_preview_get_position()
			var rotation: Quaternion = _rendering.particle_emitter_preview_get_rotation()
			var nano_particle_emitter: NanoParticleEmitter = in_context.nano_structure as NanoParticleEmitter
			nano_particle_emitter.set_transform(Transform3D(Basis(rotation), position))
			nano_particle_emitter.set_parameters(_new_emitter_parameters.duplicate())
			nano_particle_emitter.set_structure_name("%s %d" % [str(in_context.nano_structure.get_type()), in_context.workspace_context.workspace.get_nmb_of_structures()+1])
			var new_structure_context:StructureContext = in_context.workspace_context.finish_creating_object()
			new_structure_context.set_particle_emitter_selected(true)
			EditorSfx.create_object()

			# UndoRedo should only take care of adding and removing the object from the workspace
			for structure_context: StructureContext in selection_per_structure.keys():
				structure_context.clear_selection()
			
			# Consecutively allow to create shapes:
			var structure := NanoParticleEmitter.new()
			structure.set_parameters(_new_emitter_parameters)
			in_context.workspace_context.start_creating_object(structure)
			in_context.workspace_context.snapshot_moment("Create %s" % str(new_structure_context.nano_structure.get_readable_type()))
			return true
		elif in_input_event.button_index == MOUSE_BUTTON_LEFT and in_input_event.pressed:
			_press_down_position = in_input_event.global_position
	return false


func set_preview_position(in_position: Vector3) -> void:
	_rendering.particle_emitter_preview_set_position(in_position)


## When returns true no other InputHandlerBase will receive any inputs until this function returns false again,
## which usually will not happen until user is done with current input sequence (eg. drawing drag and drop selection)
func is_exclusive_input_consumer() -> bool:
	return false


## Can be used to react to the fact other InputHandlerBase has started to exclusively consuming inputs
## Usually used to clean up internal state and prepare for fresh input sequence
func handle_inputs_end() -> void:
	_rendering.particle_emitter_preview_hide()


## This method is used to inform an exclusive input consumer ended consuming inputs
## This gives a chance to react to this fact and do some special initialization
func handle_inputs_resume() -> void:
	var parameters: CreateObjectParameters = get_workspace_context().create_object_parameters
	if parameters.get_create_mode_type() != CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS \
			or not parameters.get_create_mode_enabled():
		return
	update_preview_position()
	_rendering.particle_emitter_preview_show()


## Can be overwritten to react to the fact that there was an input event which never has been
## delivered to this input handler.
## Similar to handle_inputs_end() but will happen even if handler serving the event is not an
## exclusive consumer.
func handle_input_omission() -> void:
	_rendering.particle_emitter_preview_hide()


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.CREATE_PARTICLE_EMITTERS_INPUT_HANDLER_PRIORITY

