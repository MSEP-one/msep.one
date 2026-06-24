"@abstract_class"
class_name AtomicVirtualStructure extends AtomicStructure

var _track_atoms: bool = false

func is_tracking_atoms() -> bool:
	return _track_atoms

func set_force_track_atoms(in_force_track: bool) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	_track_atoms = in_force_track


## UNUSED [s]Removes every atom, bond, and spring from this structure[/s]
func clear() -> void:
	assert(false, "Cannot delete atoms and bonds in this structure")
	return


## DNA Structure does not allow creating, removing, or modifying atoms and bonds
## so this function always returns false
func can_create_and_delete_atoms() -> bool:
	return false


## UNUSED
func add_atom(_in_args: Variant = null) -> int:
	assert(false, "Atomic Virtual Structure cannot modify atoms")
	return INVALID_ATOM_ID


## UNUSED
func revalidate_atom(_in_atom_idx: int) -> bool:
	assert(false, "Atomic Virtual Structure cannot modify atoms")
	return false


## UNUSED
func remove_atom(_in_atom_id: int) -> bool:
	assert(false, "Atomic Virtual Structure cannot modify atoms")
	return false


## UNUSED
func atom_set_atomic_number(_in_atom_id: int, _in_atomic_number: int) -> void:
	assert(false, "Atomic Virtual Structure cannot modify atoms")
	return


## UNUSED
func atom_set_position(_in_atom_id: int, _in_pos: Vector3) -> bool:
	assert(false, "Atomic Virtual Structure cannot modify atoms")
	return false


## UNUSED
func atoms_set_positions(_in_atoms: PackedInt32Array, _in_positions: PackedVector3Array) -> void:
	assert(false, "Atomic Virtual Structure cannot modify atoms")
	return


## UNUSED
func add_bond(_in_atom_id_a: int, _in_atom_id_b: int, _in_bond_order: int) -> int:
	assert(false, "Atomic Virtual Structure cannot modify bonds")
	return INVALID_ATOM_ID


## UNUSED
func remove_bond(_in_bond_id: int) -> void:
	assert(false, "Atomic Virtual Structure cannot modify bonds")
	return


## UNUSED
func revalidate_bond(_in_bond_id: int) -> bool:
	assert(false, "Atomic Virtual Structure cannot modify bonds")
	return false

## UNUSED
func bond_set_order(_in_bond_id: int, _in_bond_order: int) -> void:
	assert(false, "Atomic Virtual Structure cannot modify bonds")
	return

func get_type() -> StringName:
	return &"AtomicVirtualStructure"
