extends DynamicContextControl

var _atom_to_anchor_button: Button
var _atom_to_atom_button: Button
var _max_spring_length_slider: SpinBoxSlider
var _ignore_hydrogens_check_button: CheckButton
var _no_springs_within_same_molecule_check_button: CheckButton
var _no_selection_label: InfoLabel
var _auto_create_springs_button: Button


var _workspace_context: WorkspaceContext

var _has_atom_selection: bool
var _has_atom_selection_ignoring_hydrogens: bool
var _has_anchor_selection: bool


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_atom_to_anchor_button = %AtomToAnchorButton as Button
		_atom_to_atom_button = %AtomToAtomButton as Button
		_max_spring_length_slider = %MaxSpringLengthSlider as SpinBoxSlider
		_ignore_hydrogens_check_button = %IgnoreHydrogensCheckButton as CheckButton
		_no_springs_within_same_molecule_check_button = %NoSpringsWithinSameMoleculeCheckButton as CheckButton
		_no_selection_label = %NoSelectionLabel as InfoLabel
		_auto_create_springs_button = %AutoCreateSpringsButton as Button


func _ready() -> void:
	_atom_to_anchor_button.button_group.pressed.connect(_on_spring_type_button_group_pressed.unbind(1))
	_ignore_hydrogens_check_button.toggled.connect(_on_ignore_hydrogens_check_button_toggled)
	_auto_create_springs_button.pressed.connect(_on_auto_create_springs_button_pressed)


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_ensure_workspace_initialized(in_workspace_context)
	_ignore_hydrogens_check_button.set_pressed_no_signal(_workspace_context.create_object_parameters.get_spring_ignore_hydrogen())
	
	if not in_workspace_context.get_current_structure_context().nano_structure.can_contain_child_structure():
		return false
	
	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS:
		return false
	return true


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == in_workspace_context:
		return
	_workspace_context = in_workspace_context
	_workspace_context.history_changed.connect(_on_workspace_context_history_changed)
	_update_selection_info_label()


func _on_workspace_context_history_changed() -> void:
	_has_atom_selection = false
	_has_atom_selection_ignoring_hydrogens = false
	_has_anchor_selection = false
	for ctx: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		var selected_atoms: PackedInt32Array = ctx.get_selected_atoms()
		if ctx.nano_structure is NanoVirtualAnchor:
			_has_anchor_selection = true
		elif selected_atoms.size() > 0:
			_has_atom_selection = true
			_remove_hydrogens(ctx.nano_structure, selected_atoms)
			if selected_atoms.size() > 0:
				_has_atom_selection_ignoring_hydrogens = true
		if _has_anchor_selection and _has_atom_selection_ignoring_hydrogens:
			break
	_update_selection_info_label()


func _on_spring_type_button_group_pressed() -> void:
	_update_selection_info_label()


func _on_ignore_hydrogens_check_button_toggled(in_pressed: bool) -> void:
	_workspace_context.create_object_parameters.set_spring_ignore_hydrogens(in_pressed)
	_update_selection_info_label()


func _update_selection_info_label() -> void:
	var has_selection: bool = _has_atom_selection
	if _ignore_hydrogens_check_button.button_pressed == true:
		has_selection = _has_atom_selection_ignoring_hydrogens
	if _atom_to_anchor_button.button_pressed:
		match [has_selection, _has_anchor_selection]:
			[true, true]:
				_no_selection_label.hide()
			[true, false]:
				_no_selection_label.show()
				_no_selection_label.message = tr(&"No anchors selected.")
			[false, true]:
				_no_selection_label.show()
				_no_selection_label.message = tr(&"No atoms selected.")
			[false, false]:
				_no_selection_label.show()
				_no_selection_label.message = tr(&"No atoms or anchors selected.")
	else:
		if _has_atom_selection:
			_no_selection_label.hide()
		else:
			_no_selection_label.show()
			_no_selection_label.message = tr(&"No atoms selected.")
	
	_auto_create_springs_button.disabled = _no_selection_label.visible


func _on_auto_create_springs_button_pressed() -> void:
	if _atom_to_anchor_button.button_pressed:
		_create_atom_to_anchor_springs()
		return
	elif _atom_to_atom_button.button_pressed:
		var out_new_springs: Dictionary[int, PackedInt32Array] = {}
		var out_stopped: Dictionary[StringName, bool] = {value = false}
		var promise: Promise = _create_atom_to_atom_springs(out_new_springs, out_stopped)
		var _on_stop: Callable = func() -> void:
			out_stopped.value = true
		_workspace_context.start_async_work(
			tr("Creating Springs"), Callable(), _on_stop
		)
		await promise.wait_for_fulfill()
		if BusyIndicator.is_active():
			_workspace_context.end_async_work()
		if out_new_springs.size() > 0:
			var count: int = 0
			for structure_id: int in out_new_springs:
				var structure_context: StructureContext = _workspace_context.get_structure_context(structure_id)
				structure_context.select_springs(out_new_springs[structure_id])
				count += out_new_springs[structure_id].size()
			_workspace_context.snapshot_moment("Create %d Springs" % count)
		return

func _create_atom_to_anchor_springs() -> void:
	var anchors: Array[StructureContext]
	var atoms: Dictionary[StructureContext, PackedInt32Array]
	
	for ctx: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		if ctx.nano_structure is NanoVirtualAnchor:
			anchors.append(ctx)
		var selected_atoms: PackedInt32Array = ctx.get_selected_atoms()
		if _ignore_hydrogens_check_button.button_pressed and ctx.nano_structure is AtomicStructure:
			_remove_hydrogens(ctx.nano_structure, selected_atoms)
		if selected_atoms.size() > 0:
			atoms[ctx] = selected_atoms
	
	var max_distance_sqrd: float = _max_spring_length_slider.value * _max_spring_length_slider.value
	var constant_force: float = _workspace_context.create_object_parameters.get_spring_constant_force()
	var EQUILIBRIUM_LENGTH_IS_AUTO: bool = true
	var MANUAL_EQUILIBRIUM_LENGTH: float = 0.1
	var new_spring_count: int = 0
	for anchor: StructureContext in anchors:
		var anchor_id: int = anchor.get_int_guid()
		var anchor_pos: Vector3 = (anchor.nano_structure as NanoVirtualAnchor).get_position()
		for ctx: StructureContext in atoms.keys():
			var structure: AtomicStructure = ctx.nano_structure as AtomicStructure
			var springs_added: PackedInt32Array = []
			assert(structure)
			for atom_id: int in atoms[ctx]:
				var atom_pos: Vector3 = structure.atom_get_position(atom_id)
				if atom_pos.distance_squared_to(anchor_pos) > max_distance_sqrd:
					continue
				if structure.spring_to_anchor_exists(atom_id, anchor.get_int_guid()):
					continue
				if not structure.is_being_edited():
					structure.start_edit()
				var new_spring: int = structure.spring_create(
					anchor_id, atom_id, constant_force,
					EQUILIBRIUM_LENGTH_IS_AUTO, MANUAL_EQUILIBRIUM_LENGTH
				)
				springs_added.append(new_spring)
			if springs_added.size() > 0:
				structure.end_edit()
				ctx.select_springs(springs_added)
				new_spring_count += springs_added.size()
	if new_spring_count > 0:
		_workspace_context.snapshot_moment("Create %d Springs" % new_spring_count)

func _create_atom_to_atom_springs(out_new_springs: Dictionary[int, PackedInt32Array], out_stopped: Dictionary[StringName,bool]) -> Promise:
	var promise := Promise.new()
	var selected_atoms: Dictionary[AtomicStructure, PackedInt32Array] = {}
	for structure_context: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		var atom_selection: PackedInt32Array = structure_context.get_selected_atoms()
		if atom_selection.size() > 0:
			selected_atoms[structure_context.nano_structure as AtomicStructure] = atom_selection
	if selected_atoms.is_empty():
		promise.fulfill(true)
	else:
		var thread := Thread.new()
		thread.start(_create_atom_to_atom_springs_in_thread.bind(
			thread, promise, selected_atoms, out_new_springs, out_stopped))
	return promise


func _create_atom_to_atom_springs_in_thread(
		out_thread: Thread,
		out_promise: Promise,
		out_selected_atoms: Dictionary[AtomicStructure, PackedInt32Array],
		out_new_springs: Dictionary[int, PackedInt32Array],
		out_stopped: Dictionary[StringName,bool]) -> void:
	var max_distance_sqrd: float = _max_spring_length_slider.value * _max_spring_length_slider.value
	var constant_force: float = _workspace_context.create_object_parameters.get_spring_constant_force()
	var EQUILIBRIUM_LENGTH_IS_AUTO: bool = true
	var MANUAL_EQUILIBRIUM_LENGTH: float = 0.1
	var flush_semaphore := Semaphore.new()
	for structure: AtomicStructure in out_selected_atoms.keys():
		var first_created: bool = false
		var last_flush: float = Time.get_unix_time_from_system()
		var atom_selection: PackedInt32Array = out_selected_atoms[structure]
		if _ignore_hydrogens_check_button.button_pressed:
			_remove_hydrogens(structure, atom_selection)
		if atom_selection.size() <= 1:
			continue
		var atom_pos: Dictionary[int, Vector3]
		for atom_id: int in atom_selection:
			atom_pos[atom_id] = structure.atom_get_position(atom_id)
		var out_molecule_map: Dictionary[int, PackedInt32Array] = {
			# atom_id : atoms_in_molecule(array shared among all atom keys)
		}
		structure.start_edit()
		for i in atom_selection.size() - 1:
			for j in range(i + 1, atom_selection.size()):
				var atom1: int = atom_selection[i]
				var atom2: int = atom_selection[j]
				if atom_pos[atom1].distance_squared_to(atom_pos[atom2]) > max_distance_sqrd:
					continue
				if structure.spring_between_atoms_exists(atom1, atom2):
					continue
				if _no_springs_within_same_molecule_check_button.button_pressed \
					and _are_atoms_within_same_molecule(atom1, atom2, structure, out_molecule_map):
						continue
				else:
					var bond_between_atoms_exists: bool = structure.atom_find_bond_between(atom1, atom2) != AtomicStructure.INVALID_BOND_ID
					if bond_between_atoms_exists:
						continue
				var spring_id: int = structure.spring_create_between_atoms(
					atom1, atom2, constant_force,
					EQUILIBRIUM_LENGTH_IS_AUTO, MANUAL_EQUILIBRIUM_LENGTH
				)
				if not first_created:
					first_created = true
					out_new_springs[structure.get_int_guid()] = PackedInt32Array()
				out_new_springs[structure.get_int_guid()].append(spring_id)
				var time: float = Time.get_unix_time_from_system()
				if time - last_flush >= 1.0:
					# Update main every 1 second
					_flush_new_atom_to_atom_springs.call_deferred(structure, flush_semaphore)
					flush_semaphore.wait()
					if out_stopped.value:
						# User aborted
						out_promise.fulfill.call_deferred(true)
						out_thread.wait_to_finish.call_deferred()
						return
					structure.start_edit()
					# time may have passed after the lock
					last_flush = Time.get_unix_time_from_system()
		# Flush remainder since last flush
		_flush_new_atom_to_atom_springs.call_deferred(structure, flush_semaphore)
		flush_semaphore.wait()
		if out_stopped.value:
			# User aborted
			out_promise.fulfill.call_deferred(true)
			out_thread.wait_to_finish.call_deferred()
			return
	out_promise.fulfill.call_deferred(true)
	out_thread.wait_to_finish.call_deferred()



func _flush_new_atom_to_atom_springs(
		out_structure: AtomicStructure,
		out_semaphore: Semaphore) -> void:
	out_structure.end_edit()
	# wait for the renderer to update
	await get_tree().process_frame
	out_semaphore.post()


func _remove_hydrogens(
		in_structure: AtomicStructure,
		out_selected_atoms: PackedInt32Array) -> void:
	if out_selected_atoms.is_empty():
		return
	for i in range(out_selected_atoms.size() - 1, -1, -1):
		if in_structure.atom_is_hydrogen(out_selected_atoms[i]):
			out_selected_atoms.remove_at(i)


func _are_atoms_within_same_molecule(
		atom1: int, atom2: int,
		in_structure: AtomicStructure,
		out_molecule_map: Dictionary[int, PackedInt32Array]) -> bool:
	_scan_molecule(atom1, in_structure, out_molecule_map)
	_scan_molecule(atom2, in_structure, out_molecule_map)
	if atom2 in out_molecule_map[atom1]:
		assert(out_molecule_map[atom1] == out_molecule_map[atom2])
		return true
	return false

func _scan_molecule(in_atom_id: int,
		in_structure: AtomicStructure,
		out_molecule_map: Dictionary[int, PackedInt32Array]) -> void:
	if in_atom_id in out_molecule_map:
		# already scanned
		return
	var molecule: PackedInt32Array = []
	var atoms_to_visit: PackedInt32Array = [in_atom_id]
	var visited_atoms: Dictionary[int, bool] = {}
	var next_loop: Dictionary[int, bool] = {}
	while atoms_to_visit.size() > 0:
		next_loop = {}
		for atom_id in atoms_to_visit:
			molecule.append(atom_id)
			out_molecule_map[atom_id] = molecule
			visited_atoms[atom_id] = true
			for bond_id in in_structure.atom_get_bonds(atom_id):
				var other_atom: int = in_structure.atom_get_bond_target(atom_id, bond_id)
				if visited_atoms.get(other_atom, false) == false:
					next_loop[other_atom] = true
		atoms_to_visit = PackedInt32Array(next_loop.keys())
