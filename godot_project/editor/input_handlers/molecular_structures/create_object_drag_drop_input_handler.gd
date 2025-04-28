extends InputHandlerCreateObjectBase

const BOND_LENGTH_MSG_TEXT = "Bond length: "
const SPRING_LENGTH_MSG_TEXT = "Spring length: "

enum {
	_NO_DRAG,
	_MOUSE_DOWN_NO_DRAG_YET,
	_DRAG_FROM_NOTHING,
	_DRAG_FROM_ANCHOR,
	_DRAG_FROM_ATOM,
}

enum {
	_CREATING_BOND,
	_CREATING_SPRING,
}

var _drag_state: int = _NO_DRAG
var _drag_start_structure_id: int = 0 # AtomicStructure or NanoVirtualAnchor id
var _drag_start_atom_id: int = AtomicStructure.INVALID_ATOM_ID # Atom ID or AtomicStructure.INVALID_ATOM_ID if started from NanoVirtualAnchor
var _press_down_position: Vector2 = Vector2(-100, -100)
var _press_down_position_3d: Vector3 = Vector3(-100, -100, -100)
var _creating: int = _CREATING_BOND

var _target_atom_id: int = AtomicStructure.INVALID_ATOM_ID # Atom ID or AtomicStructure.INVALID_ATOM_ID if hivering something other than an atom


## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return false


func is_exclusive_input_consumer() -> bool:
	var exclusive: bool = _drag_state in [_DRAG_FROM_ANCHOR, _DRAG_FROM_ATOM]
	return exclusive


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(in_structure_context: StructureContext) -> bool:
	match in_structure_context.workspace_context.create_object_parameters.get_create_mode_type():
		CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS:
			_creating = _CREATING_BOND
		CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS:
			_creating = _CREATING_SPRING
		_:
			return false
	var workspace_context: WorkspaceContext = in_structure_context.workspace_context
	if workspace_context.is_creating_object():
		workspace_context.abort_creating_object()
		return false
	return true


func handle_inputs_end() -> void:
	_gesture_reset()


func handle_input_omission() -> void:
	_gesture_reset()


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	in_context.current_structure_context_changed.connect(_on_current_structure_context_changed)
	in_context.register_snapshotable(self)


func _on_current_structure_context_changed(in_context: StructureContext) -> void:
	if in_context == null or in_context.nano_structure == null:
		_gesture_reset()


## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, in_camera: Camera3D, out_context: StructureContext) -> bool:
	var rendering: Rendering = _get_rendering()
	
	if in_input_event.is_action_pressed(&"cancel"):
		var was_capturing_inputs: bool = is_exclusive_input_consumer()
		_gesture_reset()
		return was_capturing_inputs
	
	if _creating == _CREATING_BOND:
		var preview_atomic_number: int = _workspace_context.create_object_parameters.get_new_atom_element()
		assert(out_context.nano_structure.get_int_guid() != 0)
		var cannot_create_because_hydrogen: bool = not out_context.workspace_context.are_hydrogens_visualized() \
				and preview_atomic_number == PeriodicTable.ATOMIC_NUMBER_HYDROGEN
		if cannot_create_because_hydrogen:
			return false
	
	if in_input_event is InputEventMouseMotion:
		if _drag_state == _MOUSE_DOWN_NO_DRAG_YET:
			if _press_down_position.distance_squared_to(in_input_event.global_position) > MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED:
				if _drag_start_structure_id == 0:
					# Started drag from empty space
					_drag_state = _DRAG_FROM_NOTHING
					return false
				elif _drag_start_atom_id == AtomicStructure.INVALID_ATOM_ID:
					# Started drag from an Anchor
					_ensure_creating_springs()
					_drag_state = _DRAG_FROM_ANCHOR
				else:
					# Started drag from an atom
					_drag_state = _DRAG_FROM_ATOM
		if _drag_state in [_NO_DRAG, _MOUSE_DOWN_NO_DRAG_YET, _DRAG_FROM_NOTHING]:
			return false
		else:
			if not _find_target_candidate(in_camera, in_input_event):
				update_preview_position()
			if _creating == _CREATING_BOND:
				rendering.bond_preview_show()
			else:
				rendering.virtual_anchor_preview_show()
			return true
	if in_input_event is InputEventMouseButton:
		var mouse_up: bool = not in_input_event.pressed
		if in_input_event.button_index == MOUSE_BUTTON_LEFT and mouse_up and _drag_state in [_NO_DRAG, _MOUSE_DOWN_NO_DRAG_YET]:
			# reset drag state
			_drag_state = _NO_DRAG
			return false
		elif in_input_event.button_index == MOUSE_BUTTON_LEFT and mouse_up and not _drag_state in [_NO_DRAG, _MOUSE_DOWN_NO_DRAG_YET]:
			# This is a drag and drop result
			if _drag_state == _DRAG_FROM_NOTHING:
				_drag_state = _NO_DRAG
				return false
			if _creating == _CREATING_SPRING:
				if _process_create_spring_result(in_camera, in_input_event):
					EditorSfx.create_object()
			elif _creating == _CREATING_BOND:
				if _process_create_bond_result(out_context, in_camera):
					EditorSfx.create_object()
			_drag_state = _NO_DRAG
			_gesture_reset()
			return true
		elif in_input_event.button_index == MOUSE_BUTTON_LEFT and not mouse_up:
			assert(_drag_state == _NO_DRAG)
			_drag_state = _MOUSE_DOWN_NO_DRAG_YET
			_update_bind_source(in_camera, in_input_event)
	return false


func set_preview_position(in_position: Vector3) -> void:
	var rendering: Rendering = _get_rendering()
	if _drag_state in [ _NO_DRAG, _MOUSE_DOWN_NO_DRAG_YET, _DRAG_FROM_NOTHING ]:
			# Ingnore
			return
	match _creating:
		_CREATING_BOND:
			assert(_drag_state == _DRAG_FROM_ATOM, "Can only create a bond by dragging from an atom")
			_drag_drop_bond_preview_update(in_position)
		_CREATING_SPRING:
			if _drag_state == _DRAG_FROM_ANCHOR:
				# When dragging from empty space or from existing anchor
				# anchor is located at _press_down_position_3d
				# and Spring end is located at mouse current position
				rendering.virtual_anchor_preview_set_position(_press_down_position_3d)
				rendering.virtual_anchor_preview_set_spring_ends([in_position])
				_update_distance(SPRING_LENGTH_MSG_TEXT, _press_down_position_3d, in_position)
			elif _drag_state == _DRAG_FROM_ATOM:
				# When dragging from atom, anchor is located at current mouse position and
				# and Spring end is located at initial _press_down_position_3d position
				rendering.virtual_anchor_preview_set_position(in_position)
				rendering.virtual_anchor_preview_set_spring_ends([_press_down_position_3d])
				_update_distance(SPRING_LENGTH_MSG_TEXT, _press_down_position_3d, in_position)
			else:
				assert(false, "Unsupported drag state %d" % _drag_state)
				pass


func _drag_drop_bond_preview_update(in_position: Vector3) -> void:
	var rendering: Rendering = _get_rendering()
	var structure_context: StructureContext = _workspace_context.get_nano_structure_context_from_id(_drag_start_structure_id)
	var nano_structure: NanoStructure = structure_context.nano_structure
	var bond_order: int = get_workspace_context().create_object_parameters.get_new_bond_order()
	var first_atomic_number: int = nano_structure.atom_get_atomic_number(_drag_start_atom_id)
	var bond_start_pos: Vector3 = nano_structure.atom_get_position(_drag_start_atom_id)
	var second_atom_atomic_nmb: int = get_workspace_context().create_object_parameters.get_new_atom_element()
	
	if _drag_start_atom_id == _target_atom_id:
		# can't connect atom to itself
		rendering.atom_preview_hide()
		rendering.bond_preview_hide()
		get_workspace_context().set_hovered_structure_context(structure_context, _target_atom_id,
				AtomicStructure.INVALID_BOND_ID, AtomicStructure.INVALID_SPRING_ID)
		return
	
	structure_context.set_atom_selection([_drag_start_atom_id])
	
	assert(_target_atom_id == AtomicStructure.INVALID_ATOM_ID, "This method should only handle dragging into void")
	rendering.atom_preview_show()
	rendering.atom_preview_set_position(in_position).atom_preview_set_atomic_number(second_atom_atomic_nmb)

	rendering.bond_preview_show()
	rendering.bond_preview_update_all(bond_start_pos, in_position, first_atomic_number, second_atom_atomic_nmb, bond_order)
	_update_distance(BOND_LENGTH_MSG_TEXT, bond_start_pos, in_position)


func _update_distance(in_msg: String, in_position_one: Vector3, in_position_two: Vector3) -> void:
	var distance: float = in_position_one.distance_to(in_position_two)
	if is_equal_approx(distance, 0.0):
		MolecularEditorContext.bottom_bar_update_distance(_workspace_context, "", 0)
	else:
		MolecularEditorContext.bottom_bar_update_distance(_workspace_context, in_msg, distance)


func _find_target_candidate(in_camera: Camera3D, in_input_event: InputEvent) -> bool:
	assert(not _drag_state in [_NO_DRAG, _MOUSE_DOWN_NO_DRAG_YET], "Cannot process drag result before it started")
	var anchor: NanoVirtualAnchor
	var anchor_context: StructureContext
	var atomic_structure: AtomicStructure
	var atomic_structure_context: StructureContext
	var atom_id: int = AtomicStructure.INVALID_ATOM_ID
	
	var workspace_context: WorkspaceContext = get_workspace_context()
	var workspace: Workspace = workspace_context.workspace
	var potential_targets: Array[StructureContext] = workspace_context.get_editable_structure_contexts()
	var multi_structure_hit_result := MultiStructureHitResult.new(in_camera, in_input_event.position, potential_targets)
	var hit_context: StructureContext = multi_structure_hit_result.closest_hit_structure_context
	# 1. Resolve drop target
	match multi_structure_hit_result.hit_type:
		MultiStructureHitResult.HitType.HIT_ATOM:
			# Target is atom:
			if _drag_state == _DRAG_FROM_ATOM and multi_structure_hit_result.closest_hit_atom_id != _drag_start_atom_id:
				# Cannot create spring from atom to atom, switch mode to create bonds
				_ensure_creating_bonds()
			workspace_context.set_hovered_structure_context(hit_context, atom_id, AtomicStructure.INVALID_BOND_ID,
					AtomicStructure.INVALID_SPRING_ID)
			atomic_structure = hit_context.nano_structure as AtomicStructure
			atomic_structure_context = hit_context
			if _creating == _CREATING_BOND and atomic_structure.int_guid != _drag_start_structure_id:
				# Not possible to create bonds between 2 different structures
				_target_atom_id = AtomicStructure.INVALID_ATOM_ID
				_hide_atom_and_bond_preview()
				return false
			assert(is_instance_valid(atomic_structure))
			atom_id = multi_structure_hit_result.closest_hit_atom_id
			_target_atom_id = atom_id
		MultiStructureHitResult.HitType.HIT_ANCHOR:
			anchor = hit_context.nano_structure as NanoVirtualAnchor
			assert(is_instance_valid(anchor))
			anchor_context = hit_context
			workspace_context.set_hovered_structure_context(hit_context, AtomicStructure.INVALID_ATOM_ID,
					AtomicStructure.INVALID_BOND_ID, AtomicStructure.INVALID_SPRING_ID)
			if _drag_state != _DRAG_FROM_ATOM:
				# Cannot create spring from anchor to anchor
				return false
			_ensure_creating_springs()
		_:
			_target_atom_id = AtomicStructure.INVALID_ATOM_ID
			_hide_atom_and_bond_preview()
			_hide_anchor_and_spring_preview()
			workspace_context.set_hovered_structure_context(hit_context, AtomicStructure.INVALID_ATOM_ID,
					AtomicStructure.INVALID_BOND_ID, AtomicStructure.INVALID_SPRING_ID)
			return false
	# 2. Resolve Drag Source
	match _drag_state:
		_DRAG_FROM_ANCHOR:
			anchor = workspace.get_structure_by_int_guid(_drag_start_structure_id) as NanoVirtualAnchor
			anchor_context = workspace_context.get_nano_structure_context(anchor)
		_DRAG_FROM_ATOM:
			atomic_structure = workspace.get_structure_by_int_guid(_drag_start_structure_id) as AtomicStructure
			atomic_structure_context = workspace_context.get_nano_structure_context(atomic_structure)
			atom_id = _drag_start_atom_id
		_:
			return false
	var rendering: Rendering = _get_rendering()
	match _creating:
		_CREATING_BOND:
			assert(is_instance_valid(atomic_structure))
			assert(is_instance_valid(atomic_structure_context))
			assert(atom_id != AtomicStructure.INVALID_ATOM_ID)
			assert(atomic_structure.int_guid == _drag_start_structure_id)
			assert(atomic_structure.is_atom_valid(atom_id) and atomic_structure.is_atom_visible(atom_id))
			var bond_order: int = get_workspace_context().create_object_parameters.get_new_bond_order()
			var first_atomic_number: int = atomic_structure.atom_get_atomic_number(_drag_start_atom_id)
			var bond_start_pos: Vector3 = atomic_structure.atom_get_position(_drag_start_atom_id)
			var bond_end_pos: Vector3 = atomic_structure.atom_get_position(_target_atom_id)
			var second_atom_atomic_nmb: int = atomic_structure.atom_get_atomic_number(_target_atom_id)
			rendering.atom_preview_hide()
			rendering.bond_preview_show()
			rendering.bond_preview_update_all(bond_start_pos, bond_end_pos, first_atomic_number, second_atom_atomic_nmb, bond_order)
		_CREATING_SPRING:
			if not is_instance_valid(anchor):
				# Dragging from an atom into void, use the anchor_preview to draw a new anchor
				return false
			assert(is_instance_valid(anchor_context))
			assert(is_instance_valid(atomic_structure))
			assert(is_instance_valid(atomic_structure_context))
			assert(atom_id != AtomicStructure.INVALID_ATOM_ID)
			assert(atomic_structure.is_atom_valid(atom_id) and atomic_structure.is_atom_visible(atom_id))
			rendering.virtual_anchor_preview_set_position(anchor.get_position())
			rendering.virtual_anchor_preview_set_spring_ends([atomic_structure.atom_get_position(atom_id)])
	return true


func _ensure_creating_bonds() -> void:
	if _workspace_context.create_object_parameters.get_create_mode_type() != \
			CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS:
		_workspace_context.create_object_parameters.set_create_mode_type(
			CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS)
	_creating = _CREATING_BOND
	_hide_anchor_and_spring_preview()


func _ensure_creating_springs() -> void:
	if _workspace_context.create_object_parameters.get_create_mode_type() != \
			CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS:
		_workspace_context.create_object_parameters.set_create_mode_type(
			CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS)
	_creating = _CREATING_SPRING
	_hide_atom_and_bond_preview()


# Process drag and drop gesture, returns true if any object was created or false otherwise
func _process_create_spring_result(in_camera: Camera3D, in_input_event: InputEvent) -> bool:
	assert(not _drag_state in [_NO_DRAG, _MOUSE_DOWN_NO_DRAG_YET], "Cannot process drag result before it started")
	var created_anchor: bool = false
	var anchor: NanoVirtualAnchor
	var anchor_context: StructureContext
	var atomic_structure: AtomicStructure
	var atomic_structure_context: StructureContext
	var atom_id: int = AtomicStructure.INVALID_ATOM_ID
	
	var workspace_context: WorkspaceContext = get_workspace_context()
	var workspace: Workspace = workspace_context.workspace
	var potential_targets: Array[StructureContext] = workspace_context.get_editable_structure_contexts()
	var multi_structure_hit_result := MultiStructureHitResult.new(in_camera, in_input_event.position, potential_targets)
	var hit_context: StructureContext = multi_structure_hit_result.closest_hit_structure_context
	# 1. Resolve drop target
	match multi_structure_hit_result.hit_type:
		MultiStructureHitResult.HitType.HIT_ATOM:
			# Target is atom:
			if _drag_state == _DRAG_FROM_ATOM:
				# Cannot create spring from atom to atom
				return false
			atomic_structure = hit_context.nano_structure as AtomicStructure
			atomic_structure_context = hit_context
			assert(is_instance_valid(atomic_structure))
			atom_id = multi_structure_hit_result.closest_hit_atom_id
		MultiStructureHitResult.HitType.HIT_ANCHOR:
			if _drag_state != _DRAG_FROM_ATOM:
				# Cannot create spring from anchor to anchor
				return false
			anchor = hit_context.nano_structure as NanoVirtualAnchor
			anchor_context = hit_context
			assert(is_instance_valid(anchor))
		MultiStructureHitResult.HitType.HIT_NOTHING:
			if _drag_state != _DRAG_FROM_ATOM:
				# Cannot create spring from anchor to anchor
				return false
			# Create an Anchor in empty space to bind source atom
			created_anchor = true
			anchor = NanoVirtualAnchor.new()
			anchor.set_structure_name("AnchorPoint")
			anchor.set_position(_get_rendering().virtual_anchor_preview_get_position())
			workspace.add_structure(anchor, workspace_context.get_current_structure_context().nano_structure)
			anchor_context = workspace_context.get_nano_structure_context(anchor)
			anchor_context.select_all(true)
		_:
			return false
	# 2. Resolve Drag Source
	match _drag_state:
		_DRAG_FROM_ANCHOR:
			anchor = workspace.get_structure_by_int_guid(_drag_start_structure_id) as NanoVirtualAnchor
			anchor_context = workspace_context.get_nano_structure_context(anchor)
		_DRAG_FROM_ATOM:
			atomic_structure = workspace.get_structure_by_int_guid(_drag_start_structure_id) as AtomicStructure
			atomic_structure_context = workspace_context.get_nano_structure_context(atomic_structure)
			atom_id = _drag_start_atom_id
		_:
			return false
	assert(is_instance_valid(anchor))
	assert(is_instance_valid(anchor_context))
	assert(is_instance_valid(atomic_structure))
	assert(is_instance_valid(atomic_structure_context))
	assert(atom_id != AtomicStructure.INVALID_ATOM_ID)
	assert(atomic_structure.is_atom_valid(atom_id) and atomic_structure.is_atom_visible(atom_id))
	if not created_anchor and _spring_exists(atomic_structure, atom_id, anchor):
		return false
	var parameters: CreateObjectParameters = get_workspace_context().create_object_parameters
	var new_spring_id: int = _create_spring(atomic_structure, anchor.int_guid, atom_id, parameters)
	workspace_context.clear_all_selection()
	anchor_context.select_all(false)
	atomic_structure_context.select_springs([new_spring_id])
	var snapshot_name: String = "Create Anchor and Spring(s)" if created_anchor else "Create Spring"
	_workspace_context.snapshot_moment(snapshot_name)
	return true


func _process_create_bond_result(_out_context: StructureContext, in_camera: Camera3D) -> bool:
	if _drag_start_atom_id == AtomicStructure.INVALID_ATOMIC_NUMBER:
		return false
	
	if _drag_state != _DRAG_FROM_ATOM:
		return false
	
	var rendering: Rendering = _workspace_context.get_rendering()
	var structure_context: StructureContext = _workspace_context.get_nano_structure_context_from_id(_drag_start_structure_id)
	var nano_structure: NanoStructure = structure_context.nano_structure
	
	# clean up before _gesture_down
	_press_down_position = Vector2(-100, -100)
	_press_down_position_3d = Vector3(-100, -100, -100)
	rendering.bond_preview_hide()
	_drag_state = _NO_DRAG

	if _drag_start_atom_id == _target_atom_id:
		# can't connect atom to itself, user probably want's to cancel gesture
		return true
	
	var have_atom_to_connect: bool = _target_atom_id != AtomicStructure.INVALID_ATOM_ID
	if have_atom_to_connect:
		var bond_already_exists: bool = nano_structure.atom_find_bond_between(_drag_start_atom_id, _target_atom_id) >\
				AtomicStructure.INVALID_BOND_ID
		if not bond_already_exists:
			_create_bond(structure_context, _drag_start_atom_id, _target_atom_id)
		return true
	
	else:
		_create_atom_and_bond(structure_context, _drag_start_atom_id, in_camera)
		return true


func _create_spring(in_atomic_struct: NanoStructure, in_anchor_id: int, in_atom_id: int,
			in_params: CreateObjectParameters) -> int:
	in_atomic_struct.start_edit()
	var spring_id: int = in_atomic_struct.spring_create(in_anchor_id, in_atom_id, in_params.get_spring_constant_force(),
			in_params.get_spring_equilibrium_length_is_auto(), in_params.get_spring_equilibrium_manual_length())
	in_atomic_struct.end_edit()
	return spring_id


func _revalidate_spring(in_atomic_struct: NanoStructure, in_spring_id_to_revalidate: int) -> void:
	in_atomic_struct.start_edit()
	in_atomic_struct.spring_revalidate(in_spring_id_to_revalidate)
	in_atomic_struct.end_edit()


func _select_spring(structure_context: StructureContext, in_spring_id_to_select: int) -> void:
	structure_context.select_springs([in_spring_id_to_select])


func _remove_spring(in_atomic_struct: NanoStructure, in_spring_id_to_remove: int) -> void:
	in_atomic_struct.start_edit()
	in_atomic_struct.spring_invalidate(in_spring_id_to_remove)
	in_atomic_struct.end_edit()


func _spring_exists(atomic_structure: AtomicStructure, atom_id: int, anchor: NanoVirtualAnchor) -> bool:
	if not atomic_structure.is_atom_valid(atom_id):
		return false
	var springs: PackedInt32Array = atomic_structure.atom_get_springs(atom_id)
	for spring_id: int in springs:
		var anchor_id: int = atomic_structure.spring_get_anchor_id(spring_id)
		if anchor_id == anchor.int_guid:
			return true
	return false


func _create_bond(out_context: StructureContext, in_first_atom: int, in_second_atom: int) -> void:
	var nano_structure: NanoStructure = out_context.nano_structure
	var bond_order: int = get_workspace_context().create_object_parameters.get_new_bond_order()
	get_workspace_context().create_object_parameters.set_create_mode_enabled(true)
	
	for context in get_workspace_context().get_structure_contexts_with_selection():
		if context != out_context:
			context.clear_selection()
	
	# Ensure the edited structure (from where the drag started) is the current active structure or
	# we end up in an invalid state where selected atoms are not part of the current active group.
	if out_context != _workspace_context.get_current_structure_context():
		_workspace_context.set_current_structure_context(out_context)
		
	nano_structure.start_edit()
	var _new_bond_id: int = nano_structure.add_bond(in_first_atom, in_second_atom, bond_order)
	EditorSfx.create_object()
	nano_structure.end_edit()
	out_context.clear_selection()
	out_context.set_atom_selection([in_second_atom])
	_clear_selection_on_other_structures(out_context)
	_workspace_context.snapshot_moment("Create Bond")


func _create_atom_and_bond(out_context: StructureContext, in_first_atom: int, in_camera: Camera3D) -> void:
	var nano_structure: NanoStructure = out_context.nano_structure
	var bond_order: int = get_workspace_context().create_object_parameters.get_new_bond_order()
	var end_atomic_number: int = get_workspace_context().create_object_parameters.get_new_atom_element()
	var distance: float = _calculate_drop_distance(out_context, in_camera)
	var mouse_position: Vector2 = get_workspace_context().get_editor_viewport().get_mouse_position()
	var bond_end_pos: Vector3 = in_camera.project_position(mouse_position, distance)
	var add_params := AtomicStructure.AddAtomParameters.new(end_atomic_number, bond_end_pos)
	get_workspace_context().create_object_parameters.set_create_mode_enabled(true)
	
	for context in get_workspace_context().get_structure_contexts_with_selection():
		if context != out_context:
			context.clear_selection()
	
	# Ensure the edited structure (from where the drag started) is the current active structure or
	# we end up in an invalid state where selected atoms are not part of the current active group.
	if out_context != _workspace_context.get_current_structure_context():
		_workspace_context.set_current_structure_context(out_context)
	
	nano_structure.start_edit()
	var new_atom_id: int = nano_structure.add_atom(add_params)
	var _new_bond_id: int = nano_structure.add_bond(in_first_atom, new_atom_id, bond_order)
	EditorSfx.create_object()
	nano_structure.end_edit()
	out_context.set_atom_selection([new_atom_id])
	out_context.clear_bond_selection()
	_clear_selection_on_other_structures(out_context)
	get_workspace_context().snapshot_moment("Create bond")


func _clear_selection_on_other_structures(out_context: StructureContext) -> void:
	for context in get_workspace_context().get_structure_contexts_with_selection():
		if context != out_context:
			context.clear_selection()


func _calculate_drop_distance(in_context: StructureContext, in_camera: Camera3D) -> float:
	assert(_drag_start_atom_id != AtomicStructure.INVALID_ATOM_ID, "Distance tried to be calculated when a gesture has not been started yet")
	if is_snap_to_shape_surface_enabled():
		var distance_to_shape_surface: float = get_distance_to_shape_surface_under_mouse()
		if not is_nan(distance_to_shape_surface):
			return distance_to_shape_surface
	
	var is_fixed_distance := _workspace_context.create_object_parameters.get_create_distance_method() == \
			CreateObjectParameters.CreateDistanceMethod.FIXED_DISTANCE_TO_CAMERA
	if is_fixed_distance:
		return _workspace_context.create_object_parameters.drop_distance
	
	var drag_drop_plane := Plane(in_camera.basis.z, in_context.nano_structure.atom_get_position(_drag_start_atom_id))
	return drag_drop_plane.distance_to(in_camera.global_position)


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.DRAG_DROP_CREATE_OBJECTS


func _gesture_reset() -> void:
	_drag_state = _NO_DRAG
	_drag_start_structure_id = 0
	_drag_start_atom_id = AtomicStructure.INVALID_ATOMIC_NUMBER
	_hide_anchor_and_spring_preview()
	_hide_atom_and_bond_preview()


func _hide_anchor_and_spring_preview() -> void:
	var rendering: Rendering = _get_rendering()
	rendering.virtual_anchor_preview_hide()


func _hide_atom_and_bond_preview() -> void:
	var rendering: Rendering = _get_rendering()
	rendering.bond_preview_hide()
	rendering.atom_preview_hide()


func _get_rendering() -> Rendering:
	return get_workspace_context().get_rendering()


func _update_bind_source(in_camera: Camera3D, in_input_event: InputEvent) -> void:
	_press_down_position = in_input_event.global_position
	var workspace_context: WorkspaceContext = get_workspace_context()
	var potential_targets: Array[StructureContext] = workspace_context.get_editable_structure_contexts()
	var multi_structure_hit_result := MultiStructureHitResult.new(in_camera, in_input_event.position, potential_targets)
	var hit_context: StructureContext = multi_structure_hit_result.closest_hit_structure_context
	match multi_structure_hit_result.hit_type:
		MultiStructureHitResult.HitType.HIT_ATOM:
			# Target is atom:
			var atomic_structure: AtomicStructure = hit_context.nano_structure as AtomicStructure
			assert(is_instance_valid(atomic_structure))
			_drag_start_structure_id = atomic_structure.int_guid
			_drag_start_atom_id = multi_structure_hit_result.closest_hit_atom_id
			_press_down_position_3d = atomic_structure.atom_get_position(_drag_start_atom_id)
		MultiStructureHitResult.HitType.HIT_ANCHOR:
			var anchor: NanoVirtualAnchor = hit_context.nano_structure as NanoVirtualAnchor
			assert(is_instance_valid(anchor))
			_drag_start_structure_id = anchor.int_guid
			_drag_start_atom_id = AtomicStructure.INVALID_ATOM_ID
			_press_down_position_3d = anchor.get_position()
		MultiStructureHitResult.HitType.HIT_NOTHING, _:
			# Nothing or anything that is not Atom or Anchor
			_drag_start_structure_id = 0
			_drag_start_atom_id = AtomicStructure.INVALID_ATOM_ID


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = {}
	state_snapshot["_drag_state"] = _drag_state
	state_snapshot["_drag_start_structure_id"] = _drag_start_structure_id
	state_snapshot["_drag_start_atom_id"] = _drag_start_atom_id
	state_snapshot["_press_down_position"] = _press_down_position
	state_snapshot["_press_down_position_3d"] = _press_down_position_3d
	state_snapshot["_creating"] = _creating
	state_snapshot["_target_atom_id"] = _target_atom_id
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_drag_state = in_state_snapshot["_drag_state"]
	_drag_start_structure_id = in_state_snapshot["_drag_start_structure_id"]
	_drag_start_atom_id = in_state_snapshot["_drag_start_atom_id"]
	_press_down_position = in_state_snapshot["_press_down_position"]
	_press_down_position_3d = in_state_snapshot["_press_down_position_3d"]
	_creating = in_state_snapshot["_creating"]
	_target_atom_id = in_state_snapshot["_target_atom_id"]
	_gesture_reset()
