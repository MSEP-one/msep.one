class_name RingActionAddHydrogens extends RingMenuAction


signal hydrogen_atoms_count_changed(added: int, removed: int)

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

const _HYDROGEN_ATOMIC_NUMBER = 1
const _HYDROGEN_BOND_ORDER = 1

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Correct Hydrogens"),
		_execute_action,
		tr("Add hydrogens to fill incomplete bonds")
	)
	with_validation(_validate)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_AddHydrogens.svg"))


func _validate() -> bool:
	if !is_instance_valid(_workspace_context):
		return false
	var selected_contexts: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
	if selected_contexts.is_empty():
		# No Selection, try with all visible objects
		for context in _workspace_context.get_visible_structure_contexts():
			if context.nano_structure is AtomicStructure and context.nano_structure.get_valid_atoms_count() > 0:
				return true
			# No visible objects, cannot execute
		return false
	for context in selected_contexts:
		if context.get_selected_atoms().size() > 0:
			# Has selection, always can execute
			return true
	# There's selection, but not atoms (assume shapes) can't add hydrogens
	return false


func _execute_action() -> void:
	_ring_menu.close()
	var target_structures: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
	var only_apply_to_selection: bool = !target_structures.is_empty()
	if target_structures.is_empty():
		target_structures = _workspace_context.get_visible_structure_contexts()
	var delta_hydrogens: Dictionary = {
		added = 0,
		removed = 0
	}
	_workspace_context.enable_hydrogens_visualization(false)
	for context in target_structures:
		if not context.nano_structure is AtomicStructure:
			continue
		var new_atoms_selection: PackedInt32Array = context.get_selected_atoms()
		var new_bonds_selection: PackedInt32Array = context.get_selected_bonds()
		var atoms_to_check: PackedInt32Array = []
		if only_apply_to_selection:
			atoms_to_check = context.get_selected_atoms()
		else:
			atoms_to_check = context.nano_structure.get_visible_atoms()
		atoms_to_check = Array(atoms_to_check).filter(_is_not_hydrogen.bind(context.nano_structure))
		if atoms_to_check.is_empty():
			continue
		context.nano_structure.start_edit()
		
		for atom_id in atoms_to_check:
			_complete_atom_valence(context, atom_id, new_atoms_selection, new_bonds_selection, delta_hydrogens)
		context.nano_structure.end_edit()
		
		context.set_atom_selection(new_atoms_selection)
		context.set_bond_selection(new_bonds_selection)
		
	hydrogen_atoms_count_changed.emit(delta_hydrogens.added, delta_hydrogens.removed)
	_workspace_context.snapshot_moment(tr("Correct Hydrogens"))


func _complete_atom_valence(
		out_context: StructureContext, in_atom_id: int,
		out_select_atoms: PackedInt32Array, out_select_bonds: PackedInt32Array,
		out_delta_hydrogens: Dictionary
	) -> void:
	assert(out_context, "Invalid structure context")
	var nano_structure: NanoStructure = out_context.nano_structure
	assert(nano_structure, "Invalid structure")
	
	var hydrogens_added: int = 0
	var hydrogens_removed: int = 0
	var atomic_number: int = nano_structure.atom_get_atomic_number(in_atom_id)
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
	var charge: int = _get_charge(nano_structure, in_atom_id)
	var stable_charge: int = _get_stable_charge(element_data)
	var delta_electrons: int = charge - stable_charge
	if delta_electrons > 0 and element_data.symbol in HAtomsEmptyValenceDirections.TABLE_OF_VALENCES.keys():
		# Add hydrogens
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
			var add_params := AtomicStructure.AddAtomParameters.new(
				_HYDROGEN_ATOMIC_NUMBER, atom_position + dir
			)
			var hydrogen_id: int = nano_structure.add_atom(add_params)
			var bond_id: int = nano_structure.add_bond(in_atom_id, hydrogen_id, _HYDROGEN_BOND_ORDER)
			out_select_atoms.push_back(hydrogen_id)
			out_select_bonds.push_back(bond_id)
			_place_hydrogen(nano_structure, in_atom_id, hydrogen_id, dir)
			hydrogens_added += 1
	elif delta_electrons < 0:
		# Remove hydrogens
		while delta_electrons < 0:
			var bonds_ids: PackedInt32Array = nano_structure.atom_get_bonds(in_atom_id)
			var hydrogen_bonds_ids: PackedInt32Array = Array(bonds_ids).filter(_is_bond_to_hydrogen.bind(nano_structure, in_atom_id))
			if hydrogen_bonds_ids.is_empty():
				# Atom has more bonds than it should have.
				# Needs manual fix by the user
				break
			var bound_id_to_remove: int = hydrogen_bonds_ids[0]
			var hydrogen_id_to_remove: int = nano_structure.atom_get_bond_target(in_atom_id, bound_id_to_remove)
			
			# remove springs connected to hydrogen_id_to_remove
			var related_springs_to_remove: PackedInt32Array = nano_structure.atom_get_springs(hydrogen_id_to_remove)
			_invalidate_springs(nano_structure, related_springs_to_remove)
			nano_structure.remove_bond(bound_id_to_remove)
			nano_structure.remove_atom(hydrogen_id_to_remove)
			var atom_selection_idx: int = out_select_atoms.find(hydrogen_id_to_remove)
			var bond_selection_idx: int = out_select_bonds.find(bound_id_to_remove)
			# Unselect the atom and bond being removed
			if atom_selection_idx != -1:
				out_select_atoms.remove_at(atom_selection_idx)
			if bond_selection_idx != -1:
				out_select_bonds.remove_at(bond_selection_idx)
			delta_electrons += 1
			hydrogens_removed += 1
	out_delta_hydrogens.added += hydrogens_added
	out_delta_hydrogens.removed += hydrogens_removed


func _invalidate_springs(out_nano_structure: NanoStructure, in_springs: PackedInt32Array) -> void:
	for spring_id: int in in_springs:
		out_nano_structure.spring_invalidate(spring_id)


func _is_not_hydrogen(in_atom_id: int, in_nano_structure: AtomicStructure) -> bool:
	return not in_nano_structure.atom_get_atomic_number(in_atom_id) in [1, AtomicStructure.INVALID_ATOMIC_NUMBER]


func _get_charge(in_nano_structure: NanoStructure, in_atom_id: int) -> int:
	var charge: int = 0
	var bonds: PackedInt32Array = in_nano_structure.atom_get_bonds(in_atom_id)
	for bond_id in bonds:
		var order: int = in_nano_structure.get_bond(bond_id).z
		assert(order > 0, "In valid bond order")
		charge -= order
	return charge


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


func _is_bond_to_hydrogen(in_bond_id: int, in_nano_structure: NanoStructure, in_atom_id: int) -> bool:
	var other_atom_id: int = in_nano_structure.atom_get_bond_target(in_atom_id, in_bond_id)
	assert(other_atom_id != AtomicStructure.INVALID_ATOM_ID)
	var other_element: int = in_nano_structure.atom_get_atomic_number(other_atom_id)
	return other_element == _HYDROGEN_ATOMIC_NUMBER


func _is_not_bond_to_hydrogen(in_bond_id: int, in_nano_structure: NanoStructure, in_atom_id: int) -> bool:
	return !_is_bond_to_hydrogen(in_bond_id, in_nano_structure, in_atom_id)


func _place_hydrogen(out_nano_structure: NanoStructure, in_atom_id: int, in_hydrogen_id: int, in_direction: Vector3) -> void:
	var offset: Vector3 = in_direction
	var atom_element: int = out_nano_structure.atom_get_atomic_number(in_atom_id)
	var atom_position: Vector3 = out_nano_structure.atom_get_position(in_atom_id)
	var atom_element_data: ElementData = PeriodicTable.get_by_atomic_number(atom_element)
	var hydrogen_element_data: ElementData = PeriodicTable.get_by_atomic_number(_HYDROGEN_ATOMIC_NUMBER)
	offset *= (
		atom_element_data.covalent_radius[_HYDROGEN_BOND_ORDER] +
		hydrogen_element_data.covalent_radius[_HYDROGEN_BOND_ORDER]
	)
	var debug_multiplier: float = ProjectSettings.get_setting(
		&"msep/h_atoms_empty_valence_directions/hydrogen_bond_lengths_multiplier", 1.0)
	offset *= debug_multiplier
	out_nano_structure.atom_set_position(in_hydrogen_id, atom_position + offset)

