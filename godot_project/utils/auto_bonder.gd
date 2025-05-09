class_name AutoBonder
extends RefCounted


const GENERATED_BOND_ORDER: int = 1


static func generate_bonds_for_structure(out_context: StructureContext, in_selected_atoms_only: bool = false) -> PackedInt32Array:
	var atoms: PackedInt32Array
	var selected_atoms: PackedInt32Array = out_context.get_selected_atoms()
	if in_selected_atoms_only:
		atoms = selected_atoms
	else:
		atoms = out_context.nano_structure.get_visible_atoms()
	var autobonder_atoms: Dictionary[HeuristicBondAssignmentUtility.Atom, int] = {}
	var autobonder_bonds: Dictionary[HeuristicBondAssignmentUtility.Bond, int]  = {}
	var in_atoms: Array[HeuristicBondAssignmentUtility.Atom] = []
	var in_bonds: Array[HeuristicBondAssignmentUtility.Bond] = []
	var atom_id_to_heuristic_atom: Dictionary[int, HeuristicBondAssignmentUtility.Atom] = {}
	var nano_structure: NanoStructure = out_context.nano_structure
	
	# 1. Define Atoms
	for atom_id in atoms:
		var atom_type: String = PeriodicTable.get_by_atomic_number(
			nano_structure.atom_get_atomic_number(atom_id)
		).symbol
		var atom := HeuristicBondAssignmentUtility.Atom.new(
			nano_structure.atom_get_position(atom_id),
			atom_type
		)
		autobonder_atoms[atom] = atom_id
		in_atoms.push_back(atom)
		atom_id_to_heuristic_atom[atom_id] = atom
	# 2. Define existing Bonds
	for atom_id in atoms:
		var known_bonds_ids: PackedInt32Array = nano_structure.atom_get_bonds(atom_id)
		for bond_id in known_bonds_ids:
			if autobonder_bonds.find_key(bond_id) != null:
				# Was already added by the other atom_id
				continue
			var other_atom_id: int = nano_structure.atom_get_bond_target(atom_id, bond_id)
			if !atoms.has(other_atom_id):
				atom_id_to_heuristic_atom[atom_id].unspecified_bond_count += 1
				# Target atom is not selected, skip
				continue
			var atom1: HeuristicBondAssignmentUtility.Atom = autobonder_atoms.find_key(atom_id)
			var atom2: HeuristicBondAssignmentUtility.Atom = autobonder_atoms.find_key(other_atom_id)
			var bond := HeuristicBondAssignmentUtility.Bond.new(
				atom1, atom2
			)
			autobonder_bonds[bond] = bond_id
			in_bonds.push_back(bond)
	var promise: Promise = Promise.new()
	var thread := Thread.new()
	thread.start(_create_bonds_in_thread.bind(in_atoms, in_bonds, promise))
	await promise.wait_for_fulfill()
	thread.wait_to_finish()
	thread = null
	assert(not promise.has_error(), "HeuristicBondAssignmentUtility cannot fail!")
	var bond_candidates: Array[HeuristicBondAssignmentUtility.Bond] = promise.get_result()
	var new_bonds_in_this_structure: bool = false
	var new_partially_influenced_bonds: PackedInt32Array = PackedInt32Array()
	var new_highlighted_bonds: PackedInt32Array = PackedInt32Array()
	var new_bonds: PackedInt32Array = PackedInt32Array()
	for bond in bond_candidates:
		var is_new: bool = not autobonder_bonds.has(bond)
		if is_new:
			if !new_bonds_in_this_structure:
				new_bonds_in_this_structure = true
				nano_structure.start_edit()
			var atom_id1: int = autobonder_atoms[bond.atoms[0]]
			var atom_id2: int = autobonder_atoms[bond.atoms[1]]
			
			var new_bond_id: int = nano_structure.add_bond(atom_id1, atom_id2, GENERATED_BOND_ORDER)
			if new_bond_id == AtomicStructure.INVALID_BOND_ID:
				# Bond between atom_id1 and atom_id2 already exists
				continue
			new_bonds.push_back(new_bond_id)
			if atom_id1 in selected_atoms and atom_id2 in selected_atoms:
				new_highlighted_bonds.append(new_bond_id)
			else:
				new_partially_influenced_bonds.append(new_bond_id)
	
	if new_bonds_in_this_structure:
		nano_structure.end_edit()
		# Workaround for bonds not moving together with selected atoms: this highlight_atoms()
		# call notifies renderer that new bonds are connected to selected atoms (and movement
		# of those atoms should should influence them).
		# If we will have more cases where bonds could be created without being selected then 
		# we should introduce new logic/api at the junction of NanoStructure / Renderer to deal
		# with such situation instead of using this workaround
		var rendering: Rendering = out_context.get_rendering()
		rendering.highlight_atoms(selected_atoms, nano_structure, new_partially_influenced_bonds, [])
		out_context.select_bonds(new_highlighted_bonds)
	
	return new_bonds


static func _create_bonds_in_thread(
		in_atoms: Array[HeuristicBondAssignmentUtility.Atom],
		in_bonds: Array[HeuristicBondAssignmentUtility.Bond],
		out_promise: Promise) -> void:
	var bond_candidates: Array[HeuristicBondAssignmentUtility.Bond] = \
			HeuristicBondAssignmentUtility.heuristic_bond_assignment(in_atoms, in_bonds)
	out_promise.fulfill.call_deferred(bond_candidates)
