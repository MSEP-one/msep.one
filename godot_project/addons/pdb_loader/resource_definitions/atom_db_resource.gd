class_name ProteinDB extends Resource

var _atoms: Dictionary = {} # [int, PdbAtom]

func add_atom(new_atom: PdbAtom) -> void:
	_atoms[new_atom.pdb_id] = new_atom


func get_atoms_ids() -> PackedInt32Array:
	return PackedInt32Array(_atoms.keys())


func get_atoms_count() -> int:
	return _atoms.size()

func get_atom(in_pdb_id) -> PdbAtom:
	return _atoms[in_pdb_id]


func get_atom_from_pdb_id(in_pdb_id: int) -> PdbAtom:
	return _atoms[in_pdb_id]


func clear() -> void:
	_atoms.clear()


func get_aabb() -> AABB:
	var aabb := AABB()
	
	if get_atoms_count() > 0:
		aabb.position = _atoms.values()[0].position
	
	for i in get_atoms_ids():
		aabb = aabb.expand(_atoms[i].position)
	
	return aabb.abs()
