extends InputHandlerCreateObjectBase


var _drag_started_at := -Vector3.INF
var _press_down_position := -Vector2.INF
var _dragging: bool = false


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	var create_object_parameters: CreateObjectParameters = get_workspace_context().create_object_parameters
	create_object_parameters.create_mode_enabled_changed.connect(_on_create_object_parameters_create_mode_enabled_changed)


## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return false


func is_exclusive_input_consumer() -> bool:
	return _dragging


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.DRAG_DROP_CREATE_NANOTUBE


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(in_structure_context: StructureContext) -> bool:
	var workspace_context: WorkspaceContext = in_structure_context.workspace_context
	if (workspace_context.create_object_parameters.get_create_mode_type()
		!= CreateObjectParameters.CreateModeType.CREATE_CARBON_NANOTUBE):
			return false
	if workspace_context.is_creating_object():
		workspace_context.abort_creating_object()
	return true


func handle_inputs_end() -> void:
	_gesture_reset()


func handle_input_omission() -> void:
	_gesture_reset()



## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, _out_context: StructureContext) -> bool:
	if in_input_event.is_action_pressed(&"cancel"):
		var was_capturing_inputs: bool = is_exclusive_input_consumer()
		_gesture_reset()
		return was_capturing_inputs
	
	if in_input_event is InputEventMouseMotion:
		var is_drag_not_started_yet: bool = _dragging == false and _press_down_position != -Vector2.INF
		if is_drag_not_started_yet:
			if _press_down_position.distance_squared_to(in_input_event.global_position) > MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED:
				_dragging = true
				_drag_started_at = InputHandlerCreateObjectBase.calculate_preview_position_at_pos(
					get_workspace_context(), _press_down_position
				)
				var rendering: Rendering = get_workspace_context().get_rendering()
				rendering.carbon_nanotube_preview_show()
				rendering.carbon_nanotube_preview_set_start_pos(_drag_started_at)
				return true
			return false
		if _dragging:
			update_preview_position()
			return true
		return false
	if in_input_event is InputEventMouseButton:
		var mouse_up: bool = not in_input_event.pressed
		var mouse_down: bool = not mouse_up
		if in_input_event.button_index == MOUSE_BUTTON_LEFT and mouse_up and _dragging == false:
			# reset drag state
			_gesture_reset()
			return false
		elif  in_input_event.button_index == MOUSE_BUTTON_RIGHT and mouse_down and _dragging:
			# Cancelled with right mouse button
			_gesture_reset()
			return true
		elif in_input_event.button_index == MOUSE_BUTTON_LEFT and mouse_up and _dragging:
			# This is a drag and drop result
			var drop_pos: Vector3 = InputHandlerCreateObjectBase.calculate_preview_position_at_pos(
					get_workspace_context(), in_input_event.global_position
				)
			_create_tube(_drag_started_at, drop_pos)
			_gesture_reset()
			return true
		elif in_input_event.button_index == MOUSE_BUTTON_LEFT and mouse_down:
			assert(_dragging == false)
			_press_down_position = in_input_event.global_position
	return false


func _gesture_reset() -> void:
	_drag_started_at = -Vector3.INF
	_press_down_position = -Vector2.INF
	_dragging = false
	_hide_preview()


func set_preview_position(in_position: Vector3) -> void:
	var rendering: Rendering = get_workspace_context().get_rendering()
	rendering.carbon_nanotube_preview_set_end_pos(in_position)


func _hide_preview() -> void:
	var rendering: Rendering = get_workspace_context().get_rendering()
	rendering.carbon_nanotube_preview_hide()


func _create_tube(from_pos: Vector3, to_pos: Vector3) -> void:
	var rendering: Rendering = get_workspace_context().get_rendering()
	if not rendering.is_carbon_nanotube_preview_visible_and_valid():
		return
	
	_workspace_context.start_async_work(tr("Creating Carbon Nanotube"))
	var n: int = _workspace_context.create_object_parameters.get_nanotube_n_index()
	var m: int = _workspace_context.create_object_parameters.get_nanotube_m_index()
	var structure_context: StructureContext = _workspace_context.get_current_structure_context()
	var structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
	structure.start_edit()
	
	var thread := Thread.new()
	var promise := Promise.new()
	thread.start(_create_tube_in_thread.bind(thread, from_pos, to_pos, n, m, structure, promise))
	await promise.wait_for_fulfill()
	structure.end_edit()
	
	var new_atom_ids: PackedInt32Array = promise.get_result()
	structure_context.clear_selection()
	structure_context.select_atoms_and_get_auto_selected_bonds(new_atom_ids)
	_workspace_context.end_async_work()
	
	_workspace_context.snapshot_moment("Create Single Wall Carbom Nanotube")
	
func _create_tube_in_thread(
		out_thread: Thread,
		from_pos: Vector3,
		to_pos: Vector3,
		n: int,
		m: int,
		structure: AtomicStructure,
		out_promise: Promise,
	) -> void:
	var tubule_basis := CarbonTubuleBasis.new(n, m)
	var cell: CarbonTubuleBasis.CrystalCell = tubule_basis.generate()

	# --- Axis transform ---
	# The cell places atoms with the tube axis along +Z.
	# We need to rotate and translate so that Z maps onto from_pos -> to_pos.
	var tube_axis: Vector3 = to_pos - from_pos
	var tube_length: float = tube_axis.length()
	var tube_direction: Vector3 = tube_axis / tube_length

	# The cell generates atoms with the tube axis along +Z = Vector3.BACK.
	var cell_z_axis := Vector3.BACK  # (0, 0, 1)

	var axis_rotation := Basis()
	if tube_direction.is_equal_approx(cell_z_axis):
		pass  # already aligned, identity rotation
	elif tube_direction.is_equal_approx(-cell_z_axis):
		axis_rotation = Basis(Vector3.RIGHT, PI)  # 180 degrees flip
	else:
		var rotation_axis: Vector3 = cell_z_axis.cross(tube_direction).normalized()
		var rotation_angle: float = cell_z_axis.angle_to(tube_direction)
		axis_rotation = Basis(rotation_axis, rotation_angle)

	# --- Repetition along tube axis ---
	# The translational vector T defines the unit cell length along Z.
	# We tile enough copies to fill tube_length.
	var cell_length: float = tubule_basis.get_translational_vector_length()
	var repeat_count: int = ceili(tube_length / cell_length)

	# --- Collect atom positions ---
	# Each atom in the basis has a fractional position in [0,1).
	# The real-space Z coordinate is simply p.z * cell_length (since the cell
	# is orthogonal along Z — av[2] points along Z with magnitude cell_length).
	# X and Y are already Cartesian (the tube cross-section is circular in XY).
	var atom_positions: Array[Vector3] = []
	
	# The cell centers the tube at (a/2, b/2) in XY by design.
	# Extract that offset from the cell basis vectors so we can remove it.
	var cell_xy_center := Vector3(
		(cell.av[0].x + cell.av[1].x) * 0.5,
		(cell.av[0].y + cell.av[1].y) * 0.5,
		0.0
	)
	
	for atom: CarbonTubuleBasis.AtomCoordinate in cell.basis:
		# atom.position is in fractional coordinates.
		# Convert to Cartesian: XY are via the cell's av[0]/av[1],
		# Z is via av[2] (which is purely along Z).
		var cartesian: Vector3 = (
			cell.av[0] * atom.position.x +
			cell.av[1] * atom.position.y +
			cell.av[2] * atom.position.z
		)
		cartesian -= cell_xy_center
		for repeat in repeat_count:
			var z_offset: float = repeat * cell_length
			# Stop adding atoms once they exceed the requested tube length
			if z_offset >= tube_length:
				break
			var z_along_axis: float = cartesian.z + z_offset
			if z_along_axis > tube_length:
				continue
			# Full 3D position in cell space
			var cell_space_position := Vector3(cartesian.x, cartesian.y, z_along_axis)
			# Rotate to align tube axis with from_pos -> to_pos, then translate
			var world_position: Vector3 = axis_rotation * cell_space_position + from_pos
			atom_positions.append(world_position)
	
	var new_atom_ids: PackedInt32Array = []
	var atom_pos: Dictionary[int, Vector3] = {}
	for pos in atom_positions:
		var args := AtomicStructure.AddAtomParameters.new(PeriodicTable.ATOMIC_NUMBER_CARBON, pos)
		var atom_id: int = structure.add_atom(args)
		new_atom_ids.append(atom_id)
		atom_pos[atom_id] = pos
	var bond_length_squared: float = tubule_basis.bond_length ** 2.0
	for i: int in new_atom_ids.size() - 1:
		for j: int in range(i + 1, new_atom_ids.size()):
			var atom1: int = new_atom_ids[i]
			var atom2: int = new_atom_ids[j]
			var p1: Vector3 = atom_pos[atom1]
			var p2: Vector3 = atom_pos[atom2]
			const BOND_LEN_THRESSHOLD = 0.003
			if abs(p1.distance_squared_to(p2) - bond_length_squared) < BOND_LEN_THRESSHOLD:
				if structure.atom_find_bond_between(atom1, atom2) == AtomicStructure.INVALID_BOND_ID:
					structure.add_bond(new_atom_ids[i], new_atom_ids[j], 1)
	out_thread.wait_to_finish.call_deferred()
	out_promise.fulfill.call_deferred(new_atom_ids)



func _on_create_object_parameters_create_mode_enabled_changed(in_enabled: bool) -> void:
	if not in_enabled:
		_hide_preview()
