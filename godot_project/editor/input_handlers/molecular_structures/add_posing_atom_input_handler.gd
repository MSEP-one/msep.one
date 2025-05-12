extends InputHandlerCreateObjectBase


const MAX_MERGE_DISTANCE: float = 0.06
const MAX_ATOMS_FOR_AUTO_POSING: int = 50
const MIN_DISTANCE_TO_ATOMS: float = 0.14
const AtomCandidate = AtomAutoposePreview.AtomCandidate


var _candidates_dirty: bool = true
var _element_selected: int = -1
var _candidates: Array[AtomCandidate] = []
var _hovered_candidate: AtomCandidate
var _atom_grid: SpatialHashGrid

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
	_show_preview()


func handle_inputs_resume() -> void:
	_show_preview()


func handle_input_omission() -> void:
	return


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	in_context.current_structure_context_changed.connect(_on_current_structure_context_changed)
	in_context.history_changed.connect(_on_workspace_context_history_changed)
	in_context.create_object_parameters.new_atom_element_changed.connect(_on_new_atom_element_changed)
	in_context.create_object_parameters.new_bond_order_changed.connect(_on_new_bond_order_changed)
	in_context.create_object_parameters.create_distance_method_changed.connect(_on_create_distance_method_changed)
	in_context.create_object_parameters.creation_distance_from_camera_factor_changed.connect(_on_creation_distance_from_camera_factor_changed)
	in_context.structure_contents_changed.connect(_on_structure_contents_changed)
	in_context.create_object_parameters.create_mode_enabled_changed.connect(_on_create_mode_enabled_changed)
	in_context.atoms_relaxation_started.connect(_on_workspace_context_atom_relaxation_started)
	in_context.atoms_relaxation_finished.connect(_on_workspace_context_atoms_relaxation_finished)
	_element_selected = in_context.create_object_parameters.get_new_atom_element()
	_get_rendering().atom_autopose_preview_set_atomic_number(_element_selected)
	var bond_order: int = in_context.create_object_parameters.get_new_bond_order()
	_get_rendering().atom_autopose_preview_set_bond_order(bond_order)
	_workspace_context.create_object_parameters.create_mode_type_changed.connect(_on_create_object_parameters_create_mode_type_changed)
	_workspace_context.simulation_started.connect(_on_workspace_context_simulation_started_or_finished)
	_workspace_context.simulation_finished.connect(_on_workspace_context_simulation_started_or_finished)
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	representation_settings.changed.connect(_on_representation_settings_changed)


func _on_current_structure_context_changed(in_context: StructureContext) -> void:
	if in_context == null or in_context.nano_structure == null:
		_hide_preview()


## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, out_context: StructureContext) -> bool:
	var rendering: Rendering = out_context.workspace_context.get_rendering()
	var is_shortcut_pressed: bool = _check_input_event_can_bind(in_input_event)
	
	if is_shortcut_pressed and _should_show(true):
		# Auto enable create mode if we're in selection mode but all the other conditions are met
		_ensure_create_mode()
	elif not _should_show():
		rendering.atom_autopose_preview_hide()
		return false
	
	update_preview_position()
	_update_candidates_if_needed()
	rendering.atom_autopose_preview_show()
	
	if in_input_event is InputEventMouse:
		_hovered_candidate = null
		var hovered_distance_sqrd: float = INF
		const MIN_DISTANCE_SQRD: float = 15*15
		for candidate: AtomCandidate in _candidates:
			var distance_sqrd: float = in_input_event.position.distance_squared_to(candidate.pos_2d_cache)
			if distance_sqrd < MIN_DISTANCE_SQRD:
				if distance_sqrd < hovered_distance_sqrd:
					hovered_distance_sqrd = distance_sqrd
					_hovered_candidate = candidate
		rendering.atom_autopose_preview_set_hovered_candidate(_hovered_candidate)
	
	# Discard atoms hovering if a candidate is hovered.
	if _hovered_candidate != null:
		out_context.workspace_context.set_hovered_structure_context(null, -1, -1, -1)
	
	if not (in_input_event is InputEventMouseButton and 
			in_input_event.pressed and
			in_input_event.button_index == MOUSE_BUTTON_LEFT):
		return is_shortcut_pressed
	
	var preview_atomic_number: int = get_workspace_context().create_object_parameters.get_new_atom_element()
	var cannot_create_because_hydrogen: bool = not out_context.nano_structure.are_hydrogens_visible() \
			and preview_atomic_number == PeriodicTable.ATOMIC_NUMBER_HYDROGEN
	if cannot_create_because_hydrogen:
		return true
	
	if _hovered_candidate == null:
		return is_shortcut_pressed
	
	var atom_pos: Vector3 = _hovered_candidate.atom_position
	var element_to_create: int = _element_selected
	var params := AtomicStructure.AddAtomParameters.new(element_to_create, atom_pos)
	
	# Ensure the new bonds don't exceed the free valence on the existing atoms.
	# Ex: If a carbon (valence 4) already have 3 bonds but a bond order 2 is
	# selected, the new bond order must go down to 1.
	# Repeat for all atoms connected to the candidate.
	var new_bond_order: int = out_context.workspace_context.create_object_parameters.get_new_bond_order()
	var bonds_order_array: PackedInt32Array = []
	var total_valence: int = 0
	for i: int in _hovered_candidate.atom_ids.size():
		var free_valences: int = _hovered_candidate.atom_free_valence[i]
		var final_bond_order: int = min(new_bond_order, free_valences)
		bonds_order_array.push_back(final_bond_order)
		total_valence += final_bond_order
	
	# In case of a merged candidate, the new atom might result with more connections than
	# allowed. In that case the new bonds order are decreased until the configuration is valid.
	var i: int = 0
	while total_valence > _hovered_candidate.total_free_valence:
		bonds_order_array[i] -= 1
		total_valence -= 1
		i += 1
		if i >= bonds_order_array.size():
			i = 0
	
	var _result: Dictionary = _do_create_atom_and_bonds(out_context, params, _hovered_candidate.atom_ids, bonds_order_array)
	_ensure_create_mode()
	_workspace_context.snapshot_moment("Add Atom")
	return true


func is_exclusive_input_consumer() -> bool:
	if _is_shortcut_pressed() and _should_show(true):
		return true
	return _hovered_candidate != null


func set_preview_position(_in_position: Vector3) -> void:
	_update_candidates_if_needed()


func _update_candidates_if_needed() -> void:
	if not _candidates_dirty or not _should_show():
		return
	_candidates.clear()
	
	var context: StructureContext = _workspace_context.get_current_structure_context()
	var total_atoms_selected: int = context.get_selected_atoms().size()
	if total_atoms_selected > MAX_ATOMS_FOR_AUTO_POSING:
		_get_rendering().atom_autopose_preview_set_candidates(_candidates)
		_workspace_context.get_editor_viewport_container().show_warning_in_message_bar(\
			"Selecting over 50 atoms hides Potential Atom Position. Select fewer to enable this feature.")
		return
	
	var candidate_data: ElementData = PeriodicTable.get_by_atomic_number(_element_selected)
	var candidate_free_valence: int = -_get_stable_charge(candidate_data)
	var selected_atoms: PackedInt32Array = context.get_selected_atoms()
	var structure_candidates: Array[AtomCandidate] = []
	var hash_grid := SpatialHashGrid.new(MAX_MERGE_DISTANCE)
	for atom_id in selected_atoms:
		var candidates_positions: PackedVector3Array = _generate_candidates_for_atom(context, atom_id)
		var free_valences: int = context.nano_structure.atom_get_remaining_valence(atom_id)
		for pos: Vector3 in candidates_positions:
			var candidate := AtomCandidate.new()
			candidate.structrure_id = context.nano_structure.int_guid
			candidate.atom_ids = [atom_id]
			candidate.atom_free_valence = [free_valences]
			candidate.atom_position = pos
			candidate.total_free_valence = candidate_free_valence
			structure_candidates.push_back(candidate)
			hash_grid.add_item(pos, candidate)
	
	# Merge close candidates
	# Close candidates up to `candidate_free_valence` will be merged into one,
	# the rest will be discarded. This avoid suggesting to connect an hydrogen atom
	# (which can only have one bond) to two atoms at once.
	for candidates_to_merge in hash_grid.get_user_data_closer_than(MAX_MERGE_DISTANCE):
		var merged_candidate: AtomCandidate = AtomCandidate.new()
		merged_candidate.total_free_valence = candidate_free_valence
		var merge_count: int = 0
		for candidate: AtomCandidate in candidates_to_merge:
			if merge_count < candidate_free_valence:
				merged_candidate.atom_ids.push_back(candidate.atom_ids[0])
				merged_candidate.atom_free_valence.push_back(candidate.atom_free_valence[0])
				merged_candidate.atom_position += candidate.atom_position
				merged_candidate.structrure_id = candidate.structrure_id
				merge_count += 1
			structure_candidates.erase(candidate)
		merged_candidate.atom_position /= merge_count
		structure_candidates.push_back(merged_candidate)
	
	_candidates.append_array(structure_candidates)
	
	# Filter candidates colliding with existing atoms
	if not _atom_grid:
		_atom_grid = SpatialHashGrid.new(MIN_DISTANCE_TO_ATOMS)
		for other_context: StructureContext in _workspace_context.get_all_structure_contexts():
			if not other_context.nano_structure is AtomicStructure:
				continue
			var atomic_structure: AtomicStructure = other_context.nano_structure
			for atom_id: int in atomic_structure.get_valid_atoms():
				var atom_position: Vector3 = atomic_structure.atom_get_position(atom_id)
				_atom_grid.add_item(atom_position, atom_id)
	var index: int = 0
	while index < _candidates.size():
		var candidate: AtomCandidate = _candidates[index]
		if _atom_grid.has_any_closer_than(candidate.atom_position, MIN_DISTANCE_TO_ATOMS):
			_candidates.remove_at(index)
		else:
			index += 1
	
	_get_rendering().atom_autopose_preview_set_candidates(_candidates)
	_candidates_dirty = false


func _generate_candidates_for_atom(in_context: StructureContext, in_atom_id: int) -> PackedVector3Array:
	assert(in_context, "Invalid structure context")
	var nano_structure: NanoStructure = in_context.nano_structure
	assert(nano_structure, "Invalid structure")
	
	var candidate_positions: PackedVector3Array = []
	var atomic_number: int = nano_structure.atom_get_atomic_number(in_atom_id)
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
	var charge: int = _get_charge(nano_structure, in_atom_id)
	var stable_charge: int = _get_stable_charge(element_data)
	var delta_electrons: int = charge - stable_charge
	if delta_electrons > 0 and element_data.symbol in HAtomsEmptyValenceDirections.TABLE_OF_VALENCES.keys():
		# Add candidates
		var atom_position: Vector3 = nano_structure.atom_get_position(in_atom_id)
		var current_atom := HAtomsEmptyValenceDirections.Atom.new(atom_position, element_data.symbol)
		var known_bonds: PackedInt32Array = nano_structure.atom_get_bonds(in_atom_id)
		current_atom.valence = delta_electrons + known_bonds.size()
		var directions: PackedVector3Array = []
		match current_atom.valence:
			4:
				current_atom.geometry = HAtomsEmptyValenceDirections.Geometries.TETRA
			3:
				current_atom.geometry = HAtomsEmptyValenceDirections.Geometries.SP2
			_:
				current_atom.geometry = HAtomsEmptyValenceDirections.Geometries.SP1
		match known_bonds.size():
			0:
				directions = HAtomsEmptyValenceDirections.fill_valence_from_0(current_atom)
			1:
				var other_atom_id_1: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[0])
				var other_atom_pos_1: Vector3 = nano_structure.atom_get_position(other_atom_id_1)
				var known_1 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_1, "dummy")
				var torsion_candidate: HAtomsEmptyValenceDirections.Atom = _find_torsion_candidate(nano_structure,in_atom_id, [other_atom_id_1])
				directions = HAtomsEmptyValenceDirections.fill_valence_from_1(current_atom, known_1, torsion_candidate)
			2:
				var other_atom_id_1: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[0])
				var other_atom_pos_1: Vector3 = nano_structure.atom_get_position(other_atom_id_1)
				var known_1 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_1, "dummy")
				var other_atom_id_2: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[1])
				var other_atom_pos_2: Vector3 = nano_structure.atom_get_position(other_atom_id_2)
				var known_2 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_2, "dummy")
				var torsion_candidate: HAtomsEmptyValenceDirections.Atom = _find_torsion_candidate(nano_structure,in_atom_id, [other_atom_id_1, other_atom_id_2])
				directions = HAtomsEmptyValenceDirections.fill_valence_from_2(current_atom, known_1, known_2, torsion_candidate)
			3:
				var other_atom_id_1: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[0])
				var other_atom_pos_1: Vector3 = nano_structure.atom_get_position(other_atom_id_1)
				var known_1 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_1, "dummy")
				var other_atom_id_2: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[1])
				var other_atom_pos_2: Vector3 = nano_structure.atom_get_position(other_atom_id_2)
				var known_2 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_2, "dummy")
				var other_atom_id_3: int = nano_structure.atom_get_bond_target(in_atom_id, known_bonds[2])
				var other_atom_pos_3: Vector3 = nano_structure.atom_get_position(other_atom_id_3)
				var known_3 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_3, "dummy")
				directions = HAtomsEmptyValenceDirections.fill_valence_from_3(current_atom, known_1, known_2, known_3)
		for dir in directions:
			var equilibrium_distance: float = _get_equilibrium_distance(atomic_number, _element_selected)
			var candidate_pos: Vector3 = atom_position + dir * equilibrium_distance
			candidate_positions.push_back(candidate_pos)
	return candidate_positions


func _get_charge(in_nano_structure: NanoStructure, in_atom_id: int) -> int:
	var charge: int = 0
	var bonds: PackedInt32Array = in_nano_structure.atom_get_bonds(in_atom_id)
	for bond_id in bonds:
		var order: int = in_nano_structure.get_bond(bond_id).z
		assert(order > 0, "In valid bond order")
		charge -= order
	return charge


func _get_stable_charge(in_element_data: ElementData) -> int:
	var valence: int = in_element_data.valence
	if in_element_data.number <= 5:
		# Special case for elements close to Helium
		return -(2 - valence)
	if valence <= 0:
		# FIXME: missing valence value
		return 0
	if valence < 4:
		return valence
	return valence - 8


func _find_torsion_candidate(nano_structure: NanoStructure, in_atom_id: int, other_atom_ids: PackedInt32Array) -> HAtomsEmptyValenceDirections.Atom:
	for other_atom_id in other_atom_ids:
		var bond_ids_of_other: PackedInt32Array = nano_structure.atom_get_bonds(other_atom_id)
		for bond in bond_ids_of_other:
			var candidate_id: int = nano_structure.atom_get_bond_target(other_atom_id, bond)
			if candidate_id != in_atom_id:
				var candidate_position: Vector3 = nano_structure.atom_get_position(candidate_id)
				var torsion_candidate := HAtomsEmptyValenceDirections.Atom.new(candidate_position, "dummy")
				return torsion_candidate
	return null


func _get_equilibrium_distance(in_atomic_number_a: int, in_atomic_number_b: int) -> float:
	var data_a: ElementData = PeriodicTable.get_by_atomic_number(in_atomic_number_a)
	var data_b: ElementData = data_a if in_atomic_number_a == in_atomic_number_b else \
								PeriodicTable.get_by_atomic_number(in_atomic_number_b)
	var equilibrium_distance: float = (data_a.contact_radius + data_b.contact_radius) * 0.5
	return equilibrium_distance


func _do_create_atom_and_bonds(out_context: StructureContext, in_atom_params: AtomicStructure.AddAtomParameters,
			in_bind_to_ids: PackedInt32Array, in_bonds_order: PackedInt32Array) -> Dictionary:
	assert(in_bind_to_ids.size() == in_bonds_order.size(), "The provided bonds order don't match the atoms list")
	out_context.nano_structure.start_edit()
	var new_atom_id: int = out_context.nano_structure.add_atom(in_atom_params)
	var new_bond_ids: PackedInt32Array = []
	for i: int in in_bind_to_ids.size():
		var atom_to_bind: int = in_bind_to_ids[i]
		var bond_order: int = in_bonds_order[i]
		var new_bond_id: int = out_context.nano_structure.add_bond(atom_to_bind, new_atom_id, bond_order)
		new_bond_ids.push_back(new_bond_id)
	out_context.nano_structure.end_edit()
	out_context.select_atoms([new_atom_id])
	out_context.select_bonds(new_bond_ids)
	EditorSfx.create_object()
	return {"new_atom_id": new_atom_id, "new_bond_ids": new_bond_ids}


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


## Returns true if create mode is ON and the auto posing visualization is enabled.
## This setting is controlled from the visibility panel in the workspace docker.
func _should_show(ignore_create_mode: bool = false) -> bool:
	var parameters: CreateObjectParameters = _workspace_context.create_object_parameters
	if _workspace_context.is_simulating():
		return false
	if not ignore_create_mode and not parameters.get_create_mode_enabled():
		return false
	if parameters.get_create_mode_type() != CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS:
		return false
	if not _is_valid_representation():
		return false
	if _is_shortcut_pressed():
		return true
	return _workspace_context.workspace.representation_settings.get_display_auto_posing()


func _is_shortcut_pressed() -> bool:
	return (
		Input.is_key_pressed(KEY_ALT) and
		not Input.is_key_pressed(KEY_SHIFT) and
		not Input.is_key_pressed(KEY_CTRL) and
		not Input.is_key_pressed(KEY_META)
	)


func _is_valid_representation() -> bool:
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	const VALID_REPRESENTATIONS := [
		Rendering.Representation.BALLS_AND_STICKS,
		Rendering.Representation.ENHANCED_STICKS_AND_BALLS,
	]
	return VALID_REPRESENTATIONS.has(representation_settings.get_rendering_representation())


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.ADD_POSING_ATOM_INPUT_HANDLER_PRIORITY


#region internal

func _on_new_atom_element_changed(in_element: int) -> void:
	_element_selected = in_element
	_get_rendering().atom_autopose_preview_set_atomic_number(in_element)
	_candidates_dirty = true
	_update_candidates_if_needed()


func _on_new_bond_order_changed(in_order: int) -> void:
	_get_rendering().atom_autopose_preview_set_bond_order(in_order)


func _on_create_distance_method_changed(_in_new_method: int) -> void:
	pass


func _on_creation_distance_from_camera_factor_changed(_in_distance_factor: float) -> void:
	pass


func _on_create_mode_enabled_changed(enabled: bool) -> void:
	if enabled:
		_show_preview()
	else:
		_hide_preview()


func _on_create_object_parameters_create_mode_type_changed(
		_in_new_create_mode: CreateObjectParameters.CreateModeType) -> void:
	if _should_show():
		_show_preview()
	else:
		_hide_preview()


func _on_workspace_context_simulation_started_or_finished() -> void:
	if _should_show():
		_show_preview()
	else:
		_hide_preview()


func _on_representation_settings_changed() -> void:
	if _should_show():
		_show_preview()
	else:
		_hide_preview()


func _on_workspace_context_history_changed() -> void:
	_atom_grid = null
	_candidates_dirty = true
	_update_candidates_if_needed()


func _on_structure_contents_changed(structure_context: StructureContext) -> void:
	if structure_context.nano_structure is AtomicStructure:
		_atom_grid = null


func _on_workspace_context_atom_relaxation_started() -> void:
	_hide_preview()


func _on_workspace_context_atoms_relaxation_finished(_error: String) -> void:
	if _should_show():
		_show_preview()


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
	return alt_pressed and not (shift_pressed || ctrl_pressed || meta_pressed)


func _hide_preview() -> void:
	_get_rendering().atom_autopose_preview_hide()


func _show_preview() -> void:
	if not _should_show():
		return
	_update_candidates_if_needed()
	_get_rendering().atom_autopose_preview_show()


func _get_rendering() -> Rendering:
	return get_workspace_context().get_rendering()
