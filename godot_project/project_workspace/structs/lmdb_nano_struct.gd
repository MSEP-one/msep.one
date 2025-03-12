class_name LMDBNanoStruct extends AtomicStructure
## NanoStructure implementation, what sets it apart from other implementations is its storage 
## mechanism for atomic data. Instead of conventional data storage methods, this class utilizes LMDB
## (Lightning Memory-Mapped Database), implemented in C++, to store its atomic data efficiently in a
## way that can be shared with other processes. 

var _lmdb: LightningMemoryMappedDatabase
@export var _molecule_id: int = -1


func initialize(in_lmdb: LightningMemoryMappedDatabase) -> void:
	_lmdb = in_lmdb
	if _molecule_id == -1:
		# Create new id only when this resource is used for the first time (not loaded from disk)
		_molecule_id = _lmdb.create_molecule()


func get_type() -> StringName:
	return &"LMDBMolecularStructure"


func get_icon() -> Texture2D:
	return preload("res://editor/icons/MolecularStructure_x28.svg")


func get_valid_atoms_count() -> int:
	return _lmdb.get_atom_count(_molecule_id)


func add_atom(in_args: Variant = null) -> int:
	assert(_is_being_edited, "To perform any changes to NanoStructure you need to put it in edit mode by calling start_edit()")
	var args: AddAtomParameters = in_args as AddAtomParameters
	var atom_id: int = _lmdb.create_atom(_molecule_id, args.atomic_number, args.position)
	_signal_queue_atoms_added.append(atom_id)
	return atom_id


func remove_atom(in_atom_id: int) -> bool:
	assert(_is_being_edited, "To perform any changes to NanoStructure you need to put it in edit mode by calling start_edit()")
	_lmdb.mark_atom_as_removed(_molecule_id, in_atom_id)
	_signal_queue_atoms_removed.append(in_atom_id)
	return true


func is_atom_valid(in_atom_id: int) -> bool:
	return not _lmdb.is_atom_marked_to_remove(_molecule_id, in_atom_id)


func get_valid_atoms() -> PackedInt32Array:
	return _lmdb.get_atoms(_molecule_id)


func atom_get_atomic_number(in_atom_id: int) -> int:
	var atom: AtomSnapshot = _lmdb.get_atom(_molecule_id, in_atom_id)
	return atom.type


func atom_set_atomic_number(in_atom_id: int, in_atomic_number: int) -> void:
	assert(_is_being_edited, "To perform any changes to NanoStructure you need to put it in edit mode by calling start_edit()")
	var atom: AtomSnapshot = _lmdb.get_atom(_molecule_id, in_atom_id)
	atom.type = in_atomic_number
	_lmdb.set_atom_data(_molecule_id, in_atom_id, atom)


## Calculate the [url=https://en.wikipedia.org/wiki/Formal_charge]formal charge[/url] of a given atom
func atom_get_formal_charge(in_atom_id: int) -> int:
	if not is_atom_valid(in_atom_id):
		push_error("Invalid atom id %d" % [in_atom_id])
		return 0
	var atom_data: AtomSnapshot = _lmdb.get_atom(_molecule_id, in_atom_id)
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(atom_data.type)
	var valence_shell_electrons: int = element_data.valence
	var bonding_electrons: int = 0
	for bond_id: int in atom_data.get_bonds():
		var order: int = get_bond(bond_id).z
		assert(order > 0, "In valid bond order %d" % order)
		bonding_electrons += order
	var non_bonding_electrons: int = valence_shell_electrons - bonding_electrons
	var formal_charge: int = valence_shell_electrons - non_bonding_electrons - bonding_electrons
	return formal_charge


func atom_get_position(in_atom_id: int) -> Vector3:
	var atom: AtomSnapshot = _lmdb.get_atom(_molecule_id, in_atom_id)
	return atom.position


func atom_set_position(in_atom_id: int, in_pos: Vector3) -> bool:
	assert(_is_being_edited, "To perform any changes to NanoStructure you need to put it in edit mode by calling start_edit()")
	if _lmdb.has_atom(_molecule_id, in_atom_id):
		var atom: AtomSnapshot = _lmdb.get_atom(_molecule_id, in_atom_id)
		atom.position = in_pos
		_lmdb.set_atom_data(_molecule_id, in_atom_id, atom)
		_signal_queue_atoms_moved.append(in_atom_id)
		return true
	return false


func atoms_set_positions(in_atoms: PackedInt32Array, in_positions: PackedVector3Array) -> void:
	# TODO: implement nativelly in the c++ side in the next step
	assert(_is_being_edited, "To perform any changes to NanoStructure you need to put it in edit mode by calling start_edit()")
	assert(in_atoms.size() == in_positions.size())
	_signal_queue_atoms_moved.append_array(in_atoms)
	for idx: int in in_atoms.size():
		var atom_id: int = in_atoms[idx] 
		var position: Vector3 = in_positions[idx]
		var atom: AtomSnapshot = _lmdb.get_atom(_molecule_id, atom_id)
		atom.position = position
		_lmdb.set_atom_data(_molecule_id, atom_id, atom)


func atom_get_bonds(_in_atom_id: int) -> PackedInt32Array:
	var atom_data: AtomSnapshot = _lmdb.get_atom(_molecule_id, _in_atom_id)
	var bonds: PackedInt32Array = atom_data.get_bonds()
	return bonds;


func atom_get_bond_target(in_atom_id: int, in_bond_id: int) -> int:
	var bond: BondSnapshot = _lmdb.get_bond(_molecule_id, in_bond_id)
	if bond.first_atom == in_atom_id:
		return bond.second_atom
	if bond.second_atom == in_atom_id:
		return bond.first_atom
	return INVALID_ATOM_ID


func atom_find_bond_between(in_atom_id_a: int, in_atom_id_b: int) -> int:
	var a_atom: AtomSnapshot = _lmdb.get_atom(_molecule_id, in_atom_id_a)
	var b_atom: AtomSnapshot = _lmdb.get_atom(_molecule_id, in_atom_id_b)
	for bond_id: int in a_atom.get_bonds():
		if b_atom.get_bonds().has(bond_id):
			return bond_id
	return INVALID_BOND_ID


func atoms_count_by_type(_types_to_count: PackedInt32Array) -> int:
	assert(false, "FIXME: Unimplemented")
	return 0


func add_bond(in_atom_id_a: int, in_atom_id_b: int, in_bond_order: int) -> int:
	assert(_is_being_edited, "To perform any changes to NanoStructure you need to put it in edit mode by calling start_edit()")
	assert(atom_find_bond_between(in_atom_id_a, in_atom_id_b) == INVALID_BOND_ID)
	var bond_id: int = _lmdb.create_bond(_molecule_id, in_atom_id_a, in_atom_id_b, in_bond_order)
	_signal_queue_bonds_created.append(bond_id)
	return bond_id


func remove_bond(in_bond_id: int) -> void:
	assert(_is_being_edited, "To perform any changes to NanoStructure you need to put it in edit mode by calling start_edit()")
	_lmdb.mark_bond_as_removed(_molecule_id, in_bond_id)
	_signal_queue_bonds_removed.append(in_bond_id)


func revalidate_bond(in_bond_id: int) -> bool:
	assert(_is_being_edited, "To perform any changes to NanoStructure you need to put it in edit mode by calling start_edit()")
	var success: bool = _lmdb.unmark_bond_removal(_molecule_id, in_bond_id)
	_signal_queue_bonds_created.append(in_bond_id)
	return success


func is_bond_valid(in_bond_id: int) -> bool:
	return not _lmdb.is_bond_marked_to_remove(_molecule_id, in_bond_id)


func get_valid_bonds() -> PackedInt32Array:
	return _lmdb.get_all_bonds(_molecule_id)


func get_valid_bonds_count() -> int:
	return _lmdb.get_bond_count(_molecule_id)


func get_bonds_ids() -> PackedInt32Array:
	return _lmdb.get_all_bonds(_molecule_id)


func get_bond(in_bond_id: int) -> Vector3i:
	var bond: BondSnapshot = _lmdb.get_bond(_molecule_id, in_bond_id)
	return Vector3i(bond.first_atom, bond.second_atom, bond.order)


func bond_set_order(in_bond_id: int, in_bond_order: int) -> void:
	assert(_is_being_edited, "To perform any changes to NanoStructure you need to put it in edit mode by calling start_edit()")
	var bond: BondSnapshot = _lmdb.get_bond(_molecule_id, in_bond_id)
	if bond.order != in_bond_order:
		bond.order = in_bond_order
		_lmdb.set_bond_data(_molecule_id, in_bond_id, bond)
		_signal_queue_bonds_changed.append(in_bond_id)


func spring_create(_in_anchor_id: int, _in_atom_id: int, _in_spring_constant_force: float,
			_is_equilibrium_length_automatic: bool, _in_equilibrium_manual_length: float) -> int:
	return INVALID_SPRING_ID


func spring_has(_in_spring_id: int) -> bool:
	return false


func spring_invalidate(_in_spring_id: int) -> void:
	return


func spring_revalidate(_in_spring_id: int) -> void:
	return


func spring_get_atom_id(_in_spring_id: int) -> int:
	return INVALID_ATOM_ID


func spring_get_atom_position(_in_spring_id: int) -> Vector3:
	return Vector3()


func spring_get_anchor_id(_in_spring_id: int) -> int:
	return -1


func spring_get_anchor_position(_in_spring_id: int, _in_parent_context: StructureContext) -> Vector3:
	return Vector3()


func spring_get_equilibrium_length_is_auto(_in_spring_id: int) -> bool:
	return false


func spring_set_equilibrium_lenght_is_auto(_in_spring_id: int, _in_is_auto: bool) -> void:
	return


func spring_set_equilibrium_manual_length(_in_spring_id: int, _new_equilibrium_manual_length: float) -> void:
	return


func spring_get_equilibrium_manual_length(_in_spring_id: int) -> float:
	return -1.0


func spring_calculate_equilibrium_auto_length(_in_spring_id: int, _in_parent_context: StructureContext) -> float:
	return -1.0


func spring_get_constant_force(_in_spring_id: int) -> float:
	return -1.0


func spring_set_constant_force(_in_spring_id: int, _new_force: float) -> void:
	return


func springs_get_valid() -> PackedInt32Array:
	return PackedInt32Array()


func springs_get_all() -> PackedInt32Array:
	return PackedInt32Array()


func springs_count() -> int:
	return -1


func atom_get_springs(_in_atom_id: int) -> PackedInt32Array:
	return PackedInt32Array()


## Create one link from this structure to [code]out_target_motor[/code]
func atom_set_motor_link(_in_atom_id: int, _out_motor_context: StructureContext) -> void:
	assert(false, "UNIMPLEMENTED")
	pass


## Remove the existing link between [code]in_atom_id[/code] and it's target motor
func atom_clear_motor_link(_in_atom_id: int) -> void:
	assert(false, "UNIMPLEMENTED")
	pass


## Returns true if [code]in_atom_id[/code] has a motor linked to it
func atom_has_motor_link(_in_atom_id: int) -> bool:
	assert(false, "UNIMPLEMENTED")
	return false


## Returns the int_guid of the NanoVirtualMotor connected to [code]in_atom_id[/code] or 0 if not linked
func motor_link_get_motor_id(_in_atom_id: int) -> int:
	assert(false, "UNIMPLEMENTED")
	return 0


## Returns the position of the NanoVirtualMotor connected to [code]in_atom_id[/code] or asserts if not linked
func motor_link_get_motor_position(_in_atom_id: int, _in_parent_context: StructureContext) -> Vector3:
	assert(false, "UNIMPLEMENTED")
	return Vector3()


## Returns the counts of atoms that are linked to a motor
func motor_links_count() -> int:
	assert(false, "UNIMPLEMENTED")
	return 0

## Returns a list of all atoms linked to a motor
func motor_links_get_all() -> Dictionary: # { atom_id<int> = motor_id<int> }
	assert(false, "UNIMPLEMENTED")
	return {}


func _set_connected_motor(_in_motor_id: int) -> void:
	assert(false, "UNIMPLEMENTED")
	pass


func clear() -> void:
	assert(_is_being_edited, "To perform any changes to NanoStructure you need to put it in edit mode by calling start_edit()")
	var success: bool = _lmdb.remove_molecule(_molecule_id)
	assert(success)
	_molecule_id = _lmdb.create_molecule()


func get_aabb() -> AABB:
	var aabb: AABB = AABB()
	var atoms: PackedInt32Array = _lmdb.get_atoms(_molecule_id)
	if atoms.is_empty():
		return aabb
	var is_first: bool = true
	for atom_id: int in atoms:
		var atom: AtomSnapshot = _lmdb.get_atom(_molecule_id, atom_id)
		if is_first:
			aabb.position = atom.position
			is_first = false
		else:
			aabb = aabb.expand(atom.position)
	return aabb.abs()
