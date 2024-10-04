extends Node
## LightningMemoryMappedDatabasePlayground
## This class has been used during the development of LMDB integration to quickly check for regressions
## and while testing new apis in a very simplistic manner


const HYDROGEN = 1
const CARBON = 6

var _lmdb: LightningMemoryMappedDatabase


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_lmdb = $LightningMemoryMappedDatabase
	if what == NOTIFICATION_READY:
		_simple_test()


func _simple_test() -> void:
	var path: String = OS.get_user_data_dir() + "/lmdb_test"
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)
	
	var initialized: bool = _lmdb.initialize(path)
	assert(initialized)
	
	# molecule integrity test
	var molecule_id: int = _lmdb.create_molecule()
	assert(_lmdb.get_molecules().find(molecule_id) > -1)
	assert(_lmdb.has_molecule(molecule_id))
	
	# atom integrity test
	var first_atom_id: int = _lmdb.create_atom(molecule_id, CARBON, Vector3(7,8.1,9.2))
	var data: AtomSnapshot = _lmdb.get_atom(molecule_id, first_atom_id)
	assert(data.type == CARBON)
	data.position = data.position + Vector3(0.1,0.1,0.1)
	data.type = HYDROGEN
	_lmdb.set_atom_data(molecule_id, first_atom_id, data)
	_lmdb.commit()
	var first_atom_data: AtomSnapshot = _lmdb.get_atom(molecule_id, first_atom_id)
	assert(first_atom_data.position.is_equal_approx(Vector3(7,8.1,9.2) + Vector3(0.1,0.1,0.1)))
	assert(first_atom_data.type == HYDROGEN)
	assert(_lmdb.has_atom(molecule_id, first_atom_id))

	# bond integrity test
	var atom2_id: int  = _lmdb.create_atom(molecule_id, CARBON, Vector3(6,7.1,8.2))
	var bond_id: int = _lmdb.create_bond(molecule_id, first_atom_id, atom2_id, 1)
	var bond_data: BondSnapshot = _lmdb.get_bond(molecule_id, bond_id)
	assert(bond_data.first_atom == first_atom_id)
	assert(bond_data.second_atom == atom2_id)
	assert(bond_data.order == 1)
	assert(_lmdb.has_bond(molecule_id, bond_id))
	bond_data.first_atom = atom2_id
	bond_data.second_atom = first_atom_id
	bond_data.order = 2
	_lmdb.set_bond_data(molecule_id, bond_id, bond_data)
	bond_data = _lmdb.get_bond(molecule_id, bond_id)
	assert(bond_data.first_atom == atom2_id)
	assert(bond_data.second_atom == first_atom_id)
	assert(bond_data.order == 2)
	assert(_lmdb.get_atom(molecule_id, first_atom_id).get_bonds()[0] == bond_id)
	_lmdb.mark_bond_as_removed(molecule_id, bond_id)
	assert(_lmdb.get_atom(molecule_id, first_atom_id).get_bonds().size() == 0)
	assert(not _lmdb.has_bond(molecule_id, bond_id))
	
	# atom removal test
	assert(_lmdb.get_atom_count(molecule_id) == 2)
	_lmdb.mark_atom_as_removed(molecule_id, first_atom_id)
	assert(not _lmdb.has_atom(molecule_id, first_atom_id))
	assert(_lmdb.get_atom_count(molecule_id) == 1)
	
	# molecule removal test
	_lmdb.remove_molecule(molecule_id)
	assert(not _lmdb.has_atom(molecule_id, atom2_id))
	assert(not _lmdb.has_molecule(molecule_id))
	_lmdb.commit()
