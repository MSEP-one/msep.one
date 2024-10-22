extends InputHandlerCreateObjectBase


var _render_candidates: bool = false
var _candidate_spring_ends: PackedVector3Array = []
var _springs_end_candidates_outdated: bool = false
var _press_down_position: Vector2 = Vector2(-100, -100)

# region virtual
## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return true


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(in_structure_context: StructureContext) -> bool:
	if in_structure_context.workspace_context.create_object_parameters.get_create_mode_type() \
				!= CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS:
		return false
	var workspace_context: WorkspaceContext = in_structure_context.workspace_context
	if workspace_context.is_creating_object():
		workspace_context.abort_creating_object()
	return true


func handle_inputs_end() -> void:
	_hide_preview()


func handle_inputs_resume() -> void:
	var parameters: CreateObjectParameters = get_workspace_context().create_object_parameters
	if parameters.get_create_mode_type() != CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS \
			or not parameters.get_create_mode_enabled():
		return
	update_preview_position()
	_get_rendering().virtual_anchor_preview_show()
	var can_bind: bool = (
		Input.is_key_pressed(KEY_SHIFT) and
		(not Input.is_key_pressed(KEY_ALT)) and
		(not Input.is_key_pressed(KEY_CTRL)) and
		(not Input.is_key_pressed(KEY_META))
	)
	if can_bind:
		_get_rendering().virtual_anchor_preview_set_spring_ends(_candidate_spring_ends)
	else:
		const HIDEN_SPRINGS: PackedVector3Array = []
		_get_rendering().virtual_anchor_preview_set_spring_ends(HIDEN_SPRINGS)
		


func handle_input_omission() -> void:
	_hide_preview()


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	in_context.current_structure_context_changed.connect(_on_current_structure_context_changed)
	in_context.create_object_parameters.create_distance_method_changed.connect(_on_create_distance_method_changed)
	in_context.create_object_parameters.creation_distance_from_camera_factor_changed.connect(_on_creation_distance_from_camera_factor_changed)
	in_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
	in_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
	in_context.structure_contents_changed.connect(_on_context_structure_contents_changed)
	in_context.structure_added.connect(_on_context_structure_added)
	var editor_viewport: WorkspaceEditorViewport = get_workspace_context().get_editor_viewport()
	editor_viewport.get_ring_menu().closed.connect(_on_ring_menu_closed)
	in_context.register_snapshotable(self)


func _on_current_structure_context_changed(in_context: StructureContext) -> void:
	if in_context == null or in_context.nano_structure == null:
		_hide_preview()


## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, out_context: StructureContext) -> bool:
	var rendering: Rendering = _get_rendering()
	var create_mode_enabled: bool = out_context.workspace_context.create_object_parameters.get_create_mode_enabled()
	
	if not create_mode_enabled:
		rendering.virtual_anchor_preview_hide()
		return false
	
	if in_input_event is InputEventWithModifiers:
		var anchor_pos: Vector3 = rendering.virtual_anchor_preview_get_position()
		if anchor_pos == null:
			# Ray normal is parallel to the PLANE_XY, just do an early return.
			update_preview_position()
			return false
		if _check_input_event_can_bind(in_input_event) and _check_context_can_bind(anchor_pos):
			_render_candidates = true
			_update_springs_end_candidates()
			update_preview_position()
			rendering.virtual_anchor_preview_show()
		else:
			_render_candidates = false
			_update_springs_end_candidates()
			update_preview_position()
			rendering.virtual_anchor_preview_show()
	if in_input_event is InputEventMouseButton:
		# do not add anchor/spring on mouse button down, it's to early to determine if user really
		# wants to add them or for example do a drag gesture
		var mouse_up: bool = not in_input_event.pressed
		if in_input_event.button_index == MOUSE_BUTTON_LEFT and mouse_up:
			if _press_down_position.distance_squared_to(in_input_event.global_position) > MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED:
				return false
			# Create an anchor and _candidate_spring_ends springs
			var has_modifiers: bool = input_has_modifiers(in_input_event)
			var anchor_pos: Vector3 = rendering.virtual_anchor_preview_get_position()
			if !has_modifiers || (_check_input_event_can_bind(in_input_event) and !_check_context_can_bind(anchor_pos)):
				for context in get_workspace_context().get_structure_contexts_with_selection():
					context.clear_selection()
				
				var workspace: Workspace = out_context.workspace_context.workspace
				var new_anchor := NanoVirtualAnchor.new()
				new_anchor.set_structure_name("AnchorPoint")
				new_anchor.set_position(anchor_pos)
				workspace.add_structure(new_anchor, out_context.nano_structure)
				var new_anchor_context: StructureContext = out_context.workspace_context.get_nano_structure_context(new_anchor)
				new_anchor_context.select_all(true)
				_workspace_context.snapshot_moment("Create Anchor")
				return true
			elif _check_input_event_can_bind(in_input_event) and _check_context_can_bind(anchor_pos):
				# Create anchor, and spring candidates
				var workspace: Workspace = out_context.workspace_context.workspace
				# New Anchor
				var new_anchor := NanoVirtualAnchor.new()
				new_anchor.set_structure_name("AnchorPoint")
				new_anchor.set_position(anchor_pos)
				workspace.add_structure(new_anchor, out_context.nano_structure)
				var new_anchor_context: StructureContext = out_context.workspace_context.get_nano_structure_context(new_anchor)
				# Create Springs
				for context: StructureContext in get_workspace_context().get_structure_contexts_with_selection():
					if not context.nano_structure is AtomicStructure:
						continue
					var struct: AtomicStructure = context.nano_structure as AtomicStructure
					var parameters: CreateObjectParameters = get_workspace_context().create_object_parameters
					var created_springs_ids: PackedInt32Array = PackedInt32Array()
					_create_springs_for_atoms(struct, context.get_selected_atoms(), new_anchor.int_guid, parameters,
							created_springs_ids)
					_select_springs(context, created_springs_ids)
				new_anchor_context.select_all(true)
				_hide_preview()
				_workspace_context.snapshot_moment("Create Anchor and Spring(s)")
				return true
		elif in_input_event.button_index == MOUSE_BUTTON_LEFT and not mouse_up:
			_press_down_position = in_input_event.global_position
	return false


func _update_springs_end_candidates() -> void:
	if not _springs_end_candidates_outdated:
		return
	_candidate_spring_ends = PackedVector3Array()
	for context: StructureContext in get_workspace_context().get_structure_contexts_with_selection():
		for atom_id: int in context.get_selected_atoms():
			_candidate_spring_ends.push_back(context.nano_structure.atom_get_position(atom_id))
	_springs_end_candidates_outdated = false


func _create_springs_for_atoms(in_nano_struct: AtomicStructure, in_atoms: PackedInt32Array,
			in_anchor_id: int, in_params: CreateObjectParameters,
			out_created_springs: PackedInt32Array) -> void:
	out_created_springs.clear()
	in_nano_struct.start_edit()
	for atom_id: int in in_atoms:
		var spring_id: int = in_nano_struct.spring_create(in_anchor_id, atom_id,
				in_params.get_spring_constant_force(),
				in_params.get_spring_equilibrium_length_is_auto(),
				in_params.get_spring_equilibrium_manual_length())
		out_created_springs.append(spring_id)
	in_nano_struct.end_edit()


func _select_springs(in_structure_context: StructureContext, in_springs_to_select: PackedInt32Array) -> void:
	in_structure_context.select_springs(in_springs_to_select)


func set_preview_position(in_position: Vector3) -> void:
	var rendering: Rendering = _get_rendering()
	# No dragging, render anchor and spring candidates if SHIFT is pressed
	rendering.virtual_anchor_preview_set_position(in_position)
	
	if _render_candidates:
		rendering.virtual_anchor_preview_set_spring_ends(_candidate_spring_ends)
	else:
		const HIDEN_SPRINGS: PackedVector3Array = []
		rendering.virtual_anchor_preview_set_spring_ends(HIDEN_SPRINGS)


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.ADD_SPRINGS_INPUT_HANDLER_PRIORITY


#region internal
func _on_create_distance_method_changed(_in_new_method: int) -> void:
	update_preview_position()


func _on_creation_distance_from_camera_factor_changed(_in_distance_factor: float) -> void:
	update_preview_position()


func _on_workspace_context_selection_in_structures_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	_springs_end_candidates_outdated = true


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	_springs_end_candidates_outdated = true


func _on_context_structure_contents_changed(_in_structure_context: StructureContext) -> void:
	_springs_end_candidates_outdated = true


func _on_context_structure_added(_in_structure: NanoStructure) -> void:
	_springs_end_candidates_outdated = true


func _on_ring_menu_closed() -> void:
	if get_workspace_context().create_object_parameters.get_create_mode_type() == \
			CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS \
			and get_workspace_context().create_object_parameters.get_create_mode_enabled():
		update_preview_position()
		get_workspace_context().get_rendering().virtual_anchor_preview_show()


func _check_context_can_bind(in_anchor_pos: Vector3) -> bool:
	for spring_end: Vector3 in _candidate_spring_ends:
		if (spring_end-in_anchor_pos).length_squared() > 0.00001:
			# At least 1 atom can be connected to anchor
			return true
	return false


func _check_input_event_can_bind(in_event: InputEvent) -> bool:
	if not in_event is InputEventWithModifiers:
		return false
	var alt_pressed: bool = in_event.alt_pressed
	var ctrl_pressed: bool = in_event.ctrl_pressed
	var shift_pressed: bool = in_event.shift_pressed
	# Meta key does not work like the rest of the modifiers, so we fallback to Input API
	var meta_pressed: bool = Input.is_key_pressed(KEY_META)
	if in_event is InputEventKey:
		# Key inputs for an XXX button (in example shift) will have the ev.XXX_pressed property
		# set to false instead of whatever `ev.pressed` is, because of that we need aditional checks
		# for InputEventKey
		if in_event.keycode == KEY_ALT:
			alt_pressed = in_event.pressed
		if in_event.keycode == KEY_CTRL:
			ctrl_pressed = in_event.pressed
		if in_event.keycode == KEY_SHIFT:
			shift_pressed = in_event.pressed
		if in_event.keycode == KEY_META:
			meta_pressed = in_event.pressed
	# NOTE: Uncomment the following two lines to have some descriptive print of input events
	# You may want to modify the printing condition to match your needs
#	if shift_pressed:
#		print_event_with_modifiers(in_event, "Event can bind atoms: ")
	return shift_pressed and not (alt_pressed || ctrl_pressed || meta_pressed)


func _hide_preview() -> void:
	_get_rendering().virtual_anchor_preview_hide()


func _get_rendering() -> Rendering:
	return get_workspace_context().get_rendering()


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = {
		"_render_candidates" : _render_candidates,
		"_springs_end_candidates_outdated" : _springs_end_candidates_outdated,
		"_candidate_spring_ends" : _candidate_spring_ends.duplicate()
	}
	return state_snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_render_candidates = in_snapshot["_render_candidates"]
	_springs_end_candidates_outdated = in_snapshot["_springs_end_candidates_outdated"]
	_candidate_spring_ends = in_snapshot["_candidate_spring_ends"].duplicate()
