extends InputHandlerCreateObjectBase


const MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED = 20 * 20


var _press_down_position: Vector2 = Vector2(-100, -100)


# region virtual

## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return false


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(in_structure_context: StructureContext) -> bool:
	if in_structure_context.workspace_context.create_object_parameters.get_create_mode_type() \
				!= CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS:
		return false
	if in_structure_context.workspace_context.is_creating_object():
		# Make sure we abort creating shapes, motors, small molecules, etc
		in_structure_context.workspace_context.abort_creating_object()
	return in_structure_context.nano_structure is AtomicStructure


func handle_inputs_end() -> void:
	_hide_preview()


func handle_input_omission() -> void:
	_hide_preview()


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	in_context.current_structure_context_changed.connect(_on_current_structure_context_changed)
	in_context.create_object_parameters.new_atom_element_changed.connect(_on_new_atom_element_changed)
	in_context.create_object_parameters.new_bond_order_changed.connect(_on_new_bond_order_changed)
	in_context.create_object_parameters.create_distance_method_changed.connect(_on_create_distance_method_changed)
	in_context.create_object_parameters.creation_distance_from_camera_factor_changed.connect(_on_creation_distance_from_camera_factor_changed)
	var editor_viewport: WorkspaceEditorViewport = get_workspace_context().get_editor_viewport()
	editor_viewport.get_ring_menu().closed.connect(_on_ring_menu_closed)

func _on_current_structure_context_changed(in_context: StructureContext) -> void:
	if in_context == null or in_context.nano_structure == null:
		_hide_preview()


## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, out_context: StructureContext) -> bool:
	var rendering: Rendering = out_context.workspace_context.get_rendering()
	var create_mode_enabled: bool = out_context.workspace_context.create_object_parameters.get_create_mode_enabled()
	
	if in_input_event is InputEventWithModifiers:
		update_preview_position()
		var atom_pos: Vector3 = rendering.atom_preview_get_position()
		if atom_pos == null:
			# Ray normal is parallel to the PLANE_XY, just do an early return.
			return false
		var has_modifiers: bool = input_has_modifiers(in_input_event)
		if _check_input_event_can_bind(in_input_event) and _check_context_can_bind(out_context, atom_pos):
			var bind_to_idx: int = _get_bind_target(out_context)
			var bind_target_position: Vector3 = out_context.nano_structure.atom_get_position(bind_to_idx)
			var bind_target_element: int = out_context.nano_structure.atom_get_atomic_number(bind_to_idx)
			var second_atom_atomic_number: int = get_workspace_context().create_object_parameters.get_new_atom_element()
			var bond_order: int = get_workspace_context().create_object_parameters.get_new_bond_order()
			rendering.bond_preview_update_all(bind_target_position, atom_pos, bind_target_element,
					second_atom_atomic_number, bond_order)
			rendering.bond_preview_show()
			rendering.atom_preview_set_position(atom_pos)
			rendering.atom_preview_show()
		elif has_modifiers or not create_mode_enabled:
			rendering.atom_preview_hide()
			rendering.bond_preview_hide()
		else:
			var preview_atomic_number: int = get_workspace_context().create_object_parameters.get_new_atom_element()
			rendering.atom_preview_set_atomic_number(preview_atomic_number)
			rendering.atom_preview_set_position(atom_pos)
			rendering.atom_preview_show()
			rendering.bond_preview_hide()
	if in_input_event is InputEventMouseMotion:
		return false
	if in_input_event is InputEventMouseButton:
		# do not add atom on mouse button down, it's to early to determine if user really wants to add atom or for example do a pan gesture
		var mouse_up: bool = not in_input_event.pressed
		if in_input_event.button_index == MOUSE_BUTTON_LEFT and mouse_up:
			
			var preview_atomic_number: int = get_workspace_context().create_object_parameters.get_new_atom_element()
			var cannot_create_because_hydrogen: bool = not out_context.nano_structure.are_hydrogens_visible() \
					and preview_atomic_number == PeriodicTable.ATOMIC_NUMBER_HYDROGEN
			if cannot_create_because_hydrogen:
				return true
			
			var has_modifiers: bool = input_has_modifiers(in_input_event)
			if _press_down_position.distance_squared_to(in_input_event.global_position) > MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED:
				return false
			var atom_pos: Vector3 = rendering.atom_preview_get_position()
			if !has_modifiers || (_check_input_event_can_bind(in_input_event) and !_check_context_can_bind(out_context, atom_pos)):
				if not create_mode_enabled:
					return false
				if out_context.workspace_context.is_creating_object():
					# This is the first atom of a new NanoStructure
					# let's add the atom and "flush" it to the project
					var new_structure_context: StructureContext = out_context.workspace_context.finish_creating_object()
					var params := AtomicStructure.AddAtomParameters.new(get_workspace_context().create_object_parameters.get_new_atom_element(), atom_pos)
					_do_create_atom(new_structure_context, params)
					# UndoRedo should only take care of adding and removing the object from the workspace
					_ensure_create_mode()
					_workspace_context.snapshot_moment("Create Molecular Structure")
				else:
					var params := AtomicStructure.AddAtomParameters.new(get_workspace_context().create_object_parameters.get_new_atom_element(), atom_pos)
					var _atom_id: int = _do_create_atom(out_context, params)
					_ensure_create_mode()
					_workspace_context.snapshot_moment("Add Atom")
				return true
			elif _check_input_event_can_bind(in_input_event) and _check_context_can_bind(out_context, atom_pos):
				var bind_to_idx: int = _get_bind_target(out_context)
				var params := AtomicStructure.AddAtomParameters.new(get_workspace_context().create_object_parameters.get_new_atom_element(), atom_pos)
				
				var _atom_and_bond_id: Vector2i = _do_create_atom_and_bond(out_context, params, bind_to_idx,
						get_workspace_context().create_object_parameters.get_new_bond_order())
				
				get_workspace_context().create_object_parameters.set_create_mode_enabled(true)
				_hide_preview()
				_workspace_context.snapshot_moment("Add Bonded Atom")
				return true
		elif in_input_event.button_index == MOUSE_BUTTON_LEFT and not mouse_up:
			_press_down_position = in_input_event.global_position
	return false


func set_preview_position(in_position: Vector3) -> void:
	_get_rendering().atom_preview_set_position(in_position)


func _check_modifier_just_pressed(in_event: InputEventWithModifiers, modifier_keycode: Key) -> bool:
	if in_event is InputEventKey and in_event.keycode == modifier_keycode:
		return in_event.pressed
	return false


func _do_create_atom(out_context: StructureContext, in_atom_params: AtomicStructure.AddAtomParameters) -> int:
	out_context.nano_structure.start_edit()
	var new_atom_id: int = out_context.nano_structure.add_atom(in_atom_params)
	var new_selection: PackedInt32Array = [new_atom_id]
	out_context.nano_structure.end_edit()
	out_context.set_atom_selection(new_selection)
	out_context.clear_bond_selection()
	_clear_selection_on_other_structures(out_context)
	EditorSfx.create_object()
	return new_atom_id


func _do_create_atom_and_bond(out_context: StructureContext, in_atom_params: AtomicStructure.AddAtomParameters,
			in_bind_to_idx: int, in_new_bond_order: int) -> Vector2i:
	out_context.nano_structure.start_edit()
	var new_atom_id: int = out_context.nano_structure.add_atom(in_atom_params)
	var new_bond_id: int = out_context.nano_structure.add_bond(in_bind_to_idx, new_atom_id, in_new_bond_order)
	out_context.nano_structure.end_edit()
	out_context.set_atom_selection([new_atom_id])
	_clear_selection_on_other_structures(out_context)
	EditorSfx.create_object()
	return Vector2i(new_atom_id, new_bond_id)


func _clear_selection_on_other_structures(out_context: StructureContext) -> void:
	for context in get_workspace_context().get_structure_contexts_with_selection():
		if context != out_context:
			context.clear_selection()


func _ensure_create_mode() -> void:
	var workspace_context: WorkspaceContext = get_workspace_context()
	workspace_context.create_object_parameters.set_create_mode_enabled(true)
	if workspace_context.create_object_parameters.get_create_mode_type() in [
				CreateObjectParameters.CreateModeType.CREATE_SHAPES,
				CreateObjectParameters.CreateModeType.CREATE_FRAGMENT
			]:
		workspace_context.create_object_parameters.set_create_mode_type(
			CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS)
		MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.ADD_ATOM_INPUT_HANDLER_PRIORITY


#region internal

func _on_new_atom_element_changed(in_element: int) -> void:
	_get_rendering().atom_preview_set_atomic_number(in_element)


func _on_new_bond_order_changed(in_order: int) -> void:
	_get_rendering().bond_preview_set_order(in_order)


func _on_create_distance_method_changed(_in_new_method: int) -> void:
	update_preview_position()


func _on_creation_distance_from_camera_factor_changed(_in_distance_factor: float) -> void:
	update_preview_position()


func _on_ring_menu_closed() -> void:
	if get_workspace_context().create_object_parameters.get_create_mode_type() == \
			CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS \
			and get_workspace_context().create_object_parameters.get_create_mode_enabled():
		update_preview_position()
		get_workspace_context().get_rendering().atom_preview_show()


func _check_context_can_bind(in_context: StructureContext, in_atom_pos: Vector3) -> bool:
	if in_context.get_selected_atoms().size() == 1:
		var bind_target: int = _get_bind_target(in_context)
		var bind_target_pos: Vector3 = in_context.nano_structure.atom_get_position(bind_target)
		# ensure atoms are not overlaped
		return (bind_target_pos-in_atom_pos).length_squared() > 0.00001
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
	_get_rendering().atom_preview_hide()
	_get_rendering().bond_preview_hide()


func _get_rendering() -> Rendering:
	return get_workspace_context().get_rendering()


## Returns the index of the NanoStructure to bond a newly added atom.[br]
## IMPORTANT: This method will crash if selection is empty.
## Make sure to check conditions before calling it
func _get_bind_target(in_context: StructureContext) -> int:
	assert(in_context.get_selected_atoms().size() == 1)
	return in_context.get_newest_selected_atom_id()
