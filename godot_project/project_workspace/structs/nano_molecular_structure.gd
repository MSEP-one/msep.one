class_name NanoMolecularStructure extends AtomicStructure


@export var _atoms: Array[NanoAtomLegacy] = [] : set = _set_atoms

#TODO: should not be needed
@export var _invalid_atoms_count: int = 0

@export var _bonds: Array[Vector3i] = [
#	Vector3i(ATOM_IDX_A, ATOM_IDX_B, BOND_ORDER), ...
]

#TODO: should not be needed
@export var _invalid_bonds_count: int = 0

@export var representation: Rendering.Representation = Rendering.Representation.VAN_DER_WAALS_SPHERES

@export var _springs: Dictionary = {
	# id<int> : NanoSpring
}
@export var _motor_links: Dictionary = {
	# atom_id<int> : motor_id<int>
}

#TODO: rename to '_atoms'
var _valid_atoms: Dictionary = {
	# atom_id<int> : true<bool>
}

var _highest_spring_id: int = -1

#TODO: should not be needed
var _invalid_springs: Dictionary = {
	# id<int> : NanoSpring
}


func _init() -> void:
	super._init()


# used to recreate state after loading msep one file
func _post_init() -> void:
	super._post_init()
	if int_guid == 0:
		# new workspace created, we are proceeding only on msep one file load
		return
	_is_being_edited = true
	
	_highest_spring_id = _springs.size() - 1 # First unnexact approach of finding _highest_spring_id
	var related_workspace: Workspace = MolecularEditorContext.find_workspace_possessing_structure(self)
	var invisible_springs := PackedInt32Array()
	if related_workspace == null:
		return
	for spring_id: int in _springs:
		_highest_spring_id = max(_highest_spring_id, spring_id)
		var anchor_id: int = _springs[spring_id].target_anchor
		var anchor: NanoVirtualAnchor = related_workspace.get_structure_by_int_guid(anchor_id)
		anchor.handle_spring_added(self, spring_id)
		if not anchor.position_changed.is_connected(_on_anchor_position_change):
			anchor.position_changed.connect(_on_anchor_position_change.bind(anchor))
		if not anchor.visibility_changed.is_connected(_on_anchor_visibility_changed.bind(anchor)):
			anchor.visibility_changed.connect(_on_anchor_visibility_changed.bind(anchor))
		_springs[spring_id].anchor_is_visible = anchor.get_visible()
		if not spring_is_visible(spring_id):
			invisible_springs.push_back(spring_id)
	if not invisible_springs.is_empty():
		springs_visibility_changed.emit(invisible_springs)
	_is_being_edited = false


func get_type() -> StringName:
	return &"MolecularStructure"


## Returns a texture to represent the structure in the UI, it can be a predefined
## icon or a thumbnail of the actual structure
func get_icon() -> Texture2D:
	return preload("res://editor/icons/MolecularStructure_x28.svg")


## Unlike Resource.duplicate(subresources=true) this method will make sure internal Dictionaries
## and Arrays are also duplicated and unique, so they are not shared to the original NanoStructure
func safe_duplicate() -> NanoStructure:
	var copy: NanoMolecularStructure = self.duplicate(true) as NanoMolecularStructure
	for i: int in _atoms.size():
		copy._atoms[i] = _atoms[i].duplicate(true)
	return copy


# called on NanoMolecularStructure resource load
func _set_atoms(in_atoms: Array[NanoAtomLegacy]) -> void:
	_atoms = in_atoms
	_init_internal_atom_data()


func _init_internal_atom_data() -> void:
	for atom_idx in range(_atoms.size()):
		var atom: NanoAtomLegacy = _atoms[atom_idx]
		if atom.valid:
			_valid_atoms[atom_idx] = true


## Request to add an atom to the structure, the type and members of the in_args
## argument will depend on the subclass of NanoStructure.
## Returns the index of the (first) newly added atom or -1 (INVALID_ATOM_ID)
## if no atom was added at all
func add_atom(in_args: Variant = null) -> int:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(in_args is AddAtomParameters, "p_args must be in AddAtomParameters type")
	var position: Vector3 = Vector3() if !"position" in in_args else in_args.position
	var atom := NanoAtomLegacy.create(in_args.atomic_number, position)
	_atoms.push_back(atom)
	var atom_id: int = _atoms.size() - 1
	_valid_atoms[atom_id] = true
	_signal_queue_atoms_added.append(atom_id)
	return atom_id


## Request to remove an atom from the structure. Returns true on success and
## false if anything prevented from removing the atom
func remove_atom(in_atom_idx: int) -> bool:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	if in_atom_idx < 0 || in_atom_idx >= _atoms.size():
		push_error("Invalid atom index %d in structure of size %d" % [in_atom_idx, _atoms.size()])
		return false
	var bonds_ids: PackedInt32Array = _atoms[in_atom_idx].bonds_ids
	for bond_id in bonds_ids:
		remove_bond(bond_id)
	_valid_atoms.erase(in_atom_idx)
	_signal_queue_atoms_removed.append(in_atom_idx)
	_atoms[in_atom_idx].valid = false
	_invalid_atoms_count += 1
	return true


#TODO: rename to 'has_atom'
## Returns wether or not an atom has been removed from the structure
func is_atom_valid(in_atom_idx: int) -> bool:
	if in_atom_idx < 0 || in_atom_idx >= _atoms.size():
		push_error("Invalid atom index %d in structure of size %d" % [in_atom_idx, _atoms.size()])
		return false
	return _atoms[in_atom_idx].valid


#TODO: rename to get_atoms()
## Returns the list of atom_ids that have not been removed from the structure
func get_valid_atoms() -> PackedInt32Array:
	if _atoms.is_empty():
		return PackedInt32Array()
	var valid_atoms_ids: PackedInt32Array = PackedInt32Array(_valid_atoms.keys())
	return valid_atoms_ids


## Returns number of atoms that has been created in this NanoStructure
## and have not been removed.
func get_valid_atoms_count() -> int:
	return _atoms.size() - _invalid_atoms_count


## Returns the numbers of protons in atom's nucleous. This reffers to the id of an
## element in the Periodic Table
func atom_get_atomic_number(in_atom_idx: int) -> int:
	if in_atom_idx < 0 || in_atom_idx >= _atoms.size():
		push_error("Invalid atom index %d in structure of size %d" % [in_atom_idx, _atoms.size()])
		return INVALID_ATOMIC_NUMBER
	return _atoms[in_atom_idx].atomic_number


## Sets atomic number of a given atom. This reffers to the id of an
## element in the Periodic Table
func atom_set_atomic_number(in_atom_idx: int, in_atomic_number: int) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	if in_atom_idx < 0 || in_atom_idx >= _atoms.size():
		push_error("Invalid atom index %d in structure of size %d" % [in_atom_idx, _atoms.size()])
		return
	if in_atomic_number < 0 || in_atomic_number > 118:
		push_error("Invalid atom index %d in structure of size %d" % [in_atom_idx, _atoms.size()])
		return
	if _atoms[in_atom_idx].atomic_number != in_atomic_number:
		_atoms[in_atom_idx].atomic_number = in_atomic_number
		_signal_queue_atomic_number_changed.append(Vector2i(in_atom_idx, in_atomic_number))


## Calculate the [url=https://en.wikipedia.org/wiki/Formal_charge]formal charge[/url] of a given atom
func atom_get_formal_charge(in_atom_id: int) -> int:
	if in_atom_id < 0 || in_atom_id >= _atoms.size():
		push_error("Invalid atom index %d in structure of size %d" % [in_atom_id, _atoms.size()])
		return 0
	var atom: NanoAtomLegacy = _atoms[in_atom_id]
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(atom.atomic_number)
	var valence_shell_electrons: int = element_data.valence
	var bonding_electrons: int = 0
	for bond_id: int in atom.bonds_ids:
		var order: int = get_bond(bond_id).z
		assert(order > 0, "In valid bond order %d" % order)
		bonding_electrons += order
	var non_bonding_electrons: int = valence_shell_electrons - bonding_electrons
	var formal_charge: int = valence_shell_electrons - non_bonding_electrons - bonding_electrons
	return formal_charge


## Returns the position of the atom, relative to structure's transform
func atom_get_position(in_atom_idx: int) -> Vector3:
	assert(in_atom_idx > -1 and in_atom_idx < _atoms.size(), "Invalid atom index %d in structure of size %d" % [in_atom_idx, _atoms.size()])
	return _atoms[in_atom_idx].position


## Sets the position of a given atom, relative to structure's transform
## Returs true if succeeds or false if something prevents the change
func atom_set_position(in_atom_idx: int, in_pos: Vector3) -> bool:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(in_atom_idx > -1 and in_atom_idx < _atoms.size(), "Invalid atom index %d in structure of size %d" % [in_atom_idx, _atoms.size()])
	if _atoms[in_atom_idx].position != in_pos:
		_atoms[in_atom_idx].position = in_pos
		_signal_queue_atoms_moved.append(in_atom_idx)
	return true


## Should be used instead of [code]atom_set_position()[/code] in cases where there is many _atoms to move,
## for performance reasons - this way [code]changed[/code] signal is emitted only once
func atoms_set_positions(in_atoms: PackedInt32Array, in_positions: PackedVector3Array) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(in_atoms.size() == in_positions.size(), "Every position needs to correspond to one atom")
	var nmb_of_atoms: int = in_atoms.size()
	_signal_queue_atoms_moved.append_array(in_atoms)
	for idx_atom in range(nmb_of_atoms):
		var atom_id: int = in_atoms[idx_atom]
		_atoms[atom_id].position = in_positions[idx_atom]


func atom_get_bonds(in_atom_idx: int) -> PackedInt32Array:
	var output: PackedInt32Array = PackedInt32Array()
	if in_atom_idx < 0 || in_atom_idx >= _atoms.size():
		push_error("Invalid atom index %d in structure of size %d" % [in_atom_idx, _atoms.size()])
		return output

	var atom: NanoAtomLegacy = _atoms[in_atom_idx]
	output = atom.bonds_ids.duplicate()
	return output


func atom_get_bond_target(in_atom_idx: int, in_bond_id: int) -> int:
	assert(in_atom_idx > -1 and in_atom_idx < _atoms.size(), "Invalid atom index %d in structure of size %d" % [in_atom_idx, _atoms.size()])
	var atom: NanoAtomLegacy = _atoms[in_atom_idx]
	assert(in_bond_id in atom.bonds_ids, "atom don't knows about this bond (possible out of sync error)")

	var bond: Vector3i = _bonds[in_bond_id]
	if bond.x == in_atom_idx:
		return bond.y
	elif bond.y == in_atom_idx:
		return bond.x
	else:
		assert(in_atom_idx in [bond.x, bond.y], "Bonds and _atoms data has run out of sync! this should never happen")
		return INVALID_ATOM_ID


## Returns bond id between a and b, or -1 if doesn't exists
func atom_find_bond_between(in_atom_idx_a: int, in_atom_idx_b: int) -> int:
	assert(in_atom_idx_a != in_atom_idx_b, "One atom cannot maintain a bond")

	var atom_a_exists: bool = in_atom_idx_a >= 0 and in_atom_idx_a < _atoms.size()
	var atom_b_exists: bool = in_atom_idx_b >= 0 and in_atom_idx_b < _atoms.size()
	if not atom_a_exists or not atom_b_exists:
		return INVALID_BOND_ID

	var atom_a_data: NanoAtomLegacy = _atoms[in_atom_idx_a]
	var available_bonds: PackedInt32Array = atom_a_data.bonds_ids
	for bond_id in available_bonds:
		var bond: Vector3i = _bonds[bond_id]
		var is_bond_connecting_atoms: bool = (bond.x == in_atom_idx_a and bond.y == in_atom_idx_b) or \
				(bond.x == in_atom_idx_b and bond.y == in_atom_idx_a)
		if is_bond_connecting_atoms:
			return bond_id

	# there is no need to check anything else, we are assuming NanoMolecularStructure is not corrupted
	return INVALID_BOND_ID


## Create a bond between A and B, returns Bond ID
func add_bond(in_atom_idx_a: int, in_atom_idx_b: int, in_bond_order: int) -> int:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	if in_atom_idx_a < 0 || in_atom_idx_a >= _atoms.size():
		assert(false, "Invalid atom_a index %d in structure of size %d" % [in_atom_idx_a, _atoms.size()])
		return INVALID_BOND_ID
	if in_atom_idx_b < 0 || in_atom_idx_b >= _atoms.size():
		assert(false, "Invalid atom_b index %d in structure of size %d" % [in_atom_idx_b, _atoms.size()])
		return INVALID_BOND_ID
	if (in_atom_idx_a == in_atom_idx_b):
		assert(false, "Cannot bond an atom to itself")
		return INVALID_BOND_ID
	if in_bond_order < 1 || in_bond_order > 3:
		assert(false, "Invalid bond order %d" % in_bond_order)
		return INVALID_BOND_ID
	if atom_find_bond_between(in_atom_idx_a, in_atom_idx_b) > -1:
		return INVALID_BOND_ID
	var old_bond: int = _atom_find_invalid_bond_between(in_atom_idx_a, in_atom_idx_b)
	if old_bond > -1:
		# Bond existed in the past let's revalidate it
		revalidate_bond(old_bond)
		bond_set_order(old_bond, in_bond_order)
		return old_bond
	
	var a: int = min(in_atom_idx_a, in_atom_idx_b)
	var b: int = max(in_atom_idx_a, in_atom_idx_b)
	var o: int = in_bond_order
	var bond: Vector3i = Vector3i(a, b, o)
	var bond_id: int = _bonds.size()
	_atoms[a].bonds_ids.push_back(bond_id)
	_atoms[b].bonds_ids.push_back(bond_id)
	_bonds.push_back(bond)
	_signal_queue_bonds_created.append(bond_id)
	return bond_id


func _atom_find_invalid_bond_between(in_atom_idx_a: int, in_atom_idx_b: int) -> int:
	assert(in_atom_idx_a != in_atom_idx_b, "One atom cannot maintain a bond")

	var atom_a_exists: bool = in_atom_idx_a >= 0 and in_atom_idx_a < _atoms.size()
	var atom_b_exists: bool = in_atom_idx_b >= 0 and in_atom_idx_b < _atoms.size()
	if not atom_a_exists or not atom_b_exists:
		return INVALID_BOND_ID

	var atom_a_data: NanoAtomLegacy = _atoms[in_atom_idx_a]
	var invalid_bonds: PackedInt32Array = atom_a_data.invalid_bonds_ids
	for bond_id in invalid_bonds:
		var bond: Vector3i = _bonds[bond_id]
		var is_bond_connecting_atoms: bool = (bond.x == in_atom_idx_a and bond.y == in_atom_idx_b) or \
				(bond.x == in_atom_idx_b and bond.y == in_atom_idx_a)
		if is_bond_connecting_atoms:
			return bond_id

	# there is no need to check anything else, we are assuming NanoMolecularStructure is not corrupted
	return INVALID_BOND_ID


func remove_bond(in_bond_id: int) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(in_bond_id >= 0 and in_bond_id < _bonds.size(), "Invalid bond id %d in structure of size %d" % [in_bond_id, _bonds.size()])

	if _bonds[in_bond_id].z < 0:
		# Bonds are considered invalid when order is negative
		# Nothing to do here
		return

	var atom_a: NanoAtomLegacy = _atoms[_bonds[in_bond_id].x]
	var atom_b: NanoAtomLegacy = _atoms[_bonds[in_bond_id].y]
	atom_a.bonds_ids.remove_at(atom_a.bonds_ids.find(in_bond_id))
	atom_b.bonds_ids.remove_at(atom_b.bonds_ids.find(in_bond_id))
	atom_a.invalid_bonds_ids.push_back(in_bond_id)
	atom_b.invalid_bonds_ids.push_back(in_bond_id)
	_bonds[in_bond_id].z *= -1
	_invalid_bonds_count += 1
	_signal_queue_bonds_removed.append(in_bond_id)


## Request to set a previously removed bond as valid again in the structure.
## Returns true on success and false if anything prevented from revalidating the bond
func revalidate_bond(in_bond_id: int) -> bool:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(in_bond_id >= 0 and in_bond_id < _bonds.size(), "Invalid bond id %din structure of size %d" % [in_bond_id, _bonds.size()])

	var atom_a: NanoAtomLegacy = _atoms[_bonds[in_bond_id].x]
	var atom_b: NanoAtomLegacy = _atoms[_bonds[in_bond_id].y]
	if !atom_a.valid || !atom_b.valid:
		push_error("Cannot revalidate bond. One or both atoms involved are invalid")
		return false

	if _bonds[in_bond_id].z > 0:
		# Bonds are considered invalid when order is negative
		# Nothing to do here
		return true
	
	_bonds[in_bond_id].z = abs(_bonds[in_bond_id].z)
	atom_a.bonds_ids.push_back(in_bond_id)
	atom_b.bonds_ids.push_back(in_bond_id)
	atom_a.invalid_bonds_ids.remove_at(atom_a.invalid_bonds_ids.find(in_bond_id))
	atom_b.invalid_bonds_ids.remove_at(atom_b.invalid_bonds_ids.find(in_bond_id))
	_invalid_bonds_count -= 1
	_signal_queue_bonds_created.append(in_bond_id)
	return true


## Returns wether or not a bond has been removed from the structure
func is_bond_valid(in_bond_id: int) -> bool:
	if in_bond_id < 0 || in_bond_id >= _bonds.size():
		push_error("Invalid bond id %d in structure of size %d" % [in_bond_id, _bonds.size()])
		return false
	return _bonds[in_bond_id].z > 0


## Returns the list of bond_ids that have not been removed from the structure
func get_valid_bonds() -> PackedInt32Array:
	return range(_bonds.size()).filter(is_bond_valid)


## Returns number of bonds that has been created in this NanoStructure
## and have not been removed.
func get_valid_bonds_count() -> int:
	return _bonds.size() - _invalid_bonds_count


func get_bonds_ids() -> PackedInt32Array:
	var size: int = _bonds.size()
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize(_bonds.size())
	for idx in range(size):
		ids[idx] = idx
	return ids


func get_bond(in_bond_id: int) -> Vector3i:
	return _bonds[in_bond_id]


func bond_set_order(in_bond_id: int, in_bond_order: int) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(in_bond_id > -1 and in_bond_id < _bonds.size(), "Incorrect bond id")
	assert(in_bond_order > 0 and in_bond_order <= 3, "Invalid bond order %d" % in_bond_order)
	
	var bond_data: Vector3i = _bonds[in_bond_id]
	var old_bond_order: int = bond_data.z
	if (abs(old_bond_order) != in_bond_order):
		# This changes the order an invalidated bound while keeping the invalid state
		_bonds[in_bond_id].z = sign(old_bond_order) * in_bond_order
		_signal_queue_bonds_changed.append(in_bond_id)


func spring_create(in_anchor_id: int, in_atom_id: int, in_spring_constant_force: float,
			is_equilibrium_length_automatic: bool, in_equilibrium_manual_length: float) -> int:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	_highest_spring_id += 1
	_springs[_highest_spring_id] = NanoSpring.create(in_anchor_id, in_atom_id, in_spring_constant_force,
			is_equilibrium_length_automatic, in_equilibrium_manual_length)
	_signal_queue_springs_added.append(_highest_spring_id)
	var anchor: NanoVirtualAnchor = MolecularEditorContext.get_current_workspace().get_structure_by_int_guid(in_anchor_id)
	_springs[_highest_spring_id].anchor_is_visible = anchor.get_visible()
	anchor.handle_spring_added(self, _highest_spring_id)
	if not anchor.position_changed.is_connected(_on_anchor_position_change):
		anchor.position_changed.connect(_on_anchor_position_change.bind(anchor))
	if not anchor.visibility_changed.is_connected(_on_anchor_visibility_changed.bind(anchor)):
		anchor.visibility_changed.connect(_on_anchor_visibility_changed.bind(anchor))
	if not _atoms_to_related_springs.has(in_atom_id):
		_atoms_to_related_springs[in_atom_id] = Dictionary()
	_atoms_to_related_springs[in_atom_id][_highest_spring_id] = true
	return _highest_spring_id


func _on_anchor_position_change(_in_position: Vector3, in_anchor: NanoVirtualAnchor) -> void:
	var moved_springs: PackedInt32Array = in_anchor.get_related_springs(int_guid)
	for related_spring_id: int in moved_springs:
		if spring_is_visible(related_spring_id):
			_signal_queue_springs_moved[related_spring_id] = true
	ScriptUtils.call_deferred_once(_ensure_edit_queue_flushed)


func _on_anchor_visibility_changed(in_is_visible: bool, in_anchor: NanoVirtualAnchor) -> void:
	var changed_springs: PackedInt32Array = in_anchor.get_related_springs(int_guid)
	for related_spring_id: int in changed_springs:
		_springs[related_spring_id].anchor_is_visible = in_is_visible
	springs_visibility_changed.emit(changed_springs)


func _ensure_edit_queue_flushed() -> void:
	# Workaround, there are two scenarios:
	# 1. User drags only anchors, in this scenario springs_moved signal will be emitted  once 
	# (nothing unusuall, similar effect like having springs_moved.emit() inside _on_anchor_position_change
	# 2. User drags both atoms and anchors, in this scenario thanks to this workaround springs_moved
	# signal will be emitted only once, instead of twice (once because of atom movement, and other time 
	# in a result of anchor movement). Thanks to this _springs will be processed only once per movement
	start_edit()
	end_edit()


func spring_has(in_spring_id: int) -> bool:
	return _springs.has(in_spring_id)


func springs_get_valid() -> PackedInt32Array:
	return PackedInt32Array(_springs.keys())


func spring_invalidate(in_spring_id: int) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	var atom_id: int = spring_get_atom_id(in_spring_id)
	var anchor_id: int = spring_get_anchor_id(in_spring_id)
	_atoms_to_related_springs[atom_id].erase(in_spring_id)
	_invalid_springs[in_spring_id] = _springs[in_spring_id]
	_springs.erase(in_spring_id)
	_signal_queue_springs_moved.erase(in_spring_id)
	var anchor: NanoVirtualAnchor = MolecularEditorContext.get_current_workspace().get_structure_by_int_guid(anchor_id)
	anchor.handle_spring_removed(self, in_spring_id)
	
	var is_still_linked_to_anchor: bool = anchor.is_structure_related(int_guid)
	if not is_still_linked_to_anchor:
		if anchor.position_changed.is_connected(_on_anchor_position_change):
			anchor.position_changed.disconnect(_on_anchor_position_change)
		if anchor.visibility_changed.is_connected(_on_anchor_visibility_changed):
			anchor.visibility_changed.disconnect(_on_anchor_visibility_changed)
	_signal_queue_springs_removed.append(in_spring_id)


func spring_revalidate(in_spring_id: int) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	_springs[in_spring_id] = _invalid_springs[in_spring_id]
	_invalid_springs.erase(in_spring_id)
	_signal_queue_springs_added.append(in_spring_id)
	
	var revalidated_spring: NanoSpring = _springs[in_spring_id]
	var related_anchor_id: int = revalidated_spring.target_anchor
	var anchor: NanoVirtualAnchor = MolecularEditorContext.get_current_workspace().get_structure_by_int_guid(related_anchor_id)
	anchor.handle_spring_added(self, in_spring_id)
	if not anchor.position_changed.is_connected(_on_anchor_position_change):
		anchor.position_changed.connect(_on_anchor_position_change.bind(anchor))
	
	var related_atom_id: int = revalidated_spring.target_atom
	if not _atoms_to_related_springs.has(related_atom_id):
		_atoms_to_related_springs[related_atom_id] = Dictionary()
	_atoms_to_related_springs[related_atom_id][in_spring_id] = true


func spring_is_visible(in_spring_id: int) -> bool:
	var spring: NanoSpring = _springs[in_spring_id]
	if not spring.anchor_is_visible:
		return false
	return super.spring_is_visible(in_spring_id)


func spring_get_atom_id(in_spring_id: int) -> int:
	return _springs[in_spring_id].target_atom


func spring_get_atom_position(in_spring_id: int) -> Vector3:
	var spring: NanoSpring = _springs[in_spring_id]
	return atom_get_position(spring.target_atom)


func spring_get_anchor_id(in_spring_id: int) -> int:
	var spring: NanoSpring = _springs[in_spring_id]
	return spring.target_anchor


func spring_get_anchor_position(in_spring_id: int, in_parent_context: StructureContext) -> Vector3:
	assert(in_parent_context.nano_structure == self, "This method expects parent StructureContext")
	var anchor_id: int = in_parent_context.nano_structure.spring_get_anchor_id(in_spring_id)
	var workspace: Workspace = in_parent_context.workspace_context.workspace
	var anchor: NanoVirtualAnchor = workspace.get_structure_by_int_guid(anchor_id) as NanoVirtualAnchor
	return anchor.get_position()


func spring_get_equilibrium_length_is_auto(in_spring_id: int) -> bool:
	var spring: NanoSpring = _springs[in_spring_id]
	return spring.equilibrium_length_is_auto


func spring_set_equilibrium_lenght_is_auto(in_spring_id: int, in_is_auto: bool) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	var spring: NanoSpring = _springs[in_spring_id]
	spring.equilibrium_length_is_auto = in_is_auto


func spring_set_equilibrium_manual_length(in_spring_id: int, new_equilibrium_manual_length: float) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	var spring: NanoSpring = _springs[in_spring_id]
	spring.equilibrium_manual_length = new_equilibrium_manual_length


func spring_get_equilibrium_manual_length(in_spring_id: int) -> float:
	var spring: NanoSpring = _springs[in_spring_id]
	return spring.equilibrium_manual_length


func spring_calculate_equilibrium_auto_length(in_spring_id: int, _in_parent_context: StructureContext) -> float:
	var begin: Vector3 = spring_get_atom_position(in_spring_id)
	var end: Vector3 = spring_get_anchor_position(in_spring_id, _in_parent_context)
	var length: float = begin.distance_to(end)
	return length


func spring_get_constant_force(in_spring_id: int) -> float:
	var spring: NanoSpring = _springs[in_spring_id]
	return spring.constant_force


func spring_set_constant_force(in_spring_id: int, new_force: float) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	var spring: NanoSpring = _springs[in_spring_id]
	spring.constant_force = new_force


func springs_get_all() -> PackedInt32Array:
	return PackedInt32Array(_springs.keys())


func springs_count() -> int:
	return _springs.size()


func atom_get_springs(in_atom_id: int) -> PackedInt32Array:
	if _atoms_to_related_springs.has(in_atom_id):
		return PackedInt32Array(_atoms_to_related_springs[in_atom_id].keys())
	return PackedInt32Array()


func atom_set_motor_link(in_atom_id: int, out_motor_context: StructureContext) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(is_instance_valid(out_motor_context) and out_motor_context.nano_structure is NanoVirtualMotor,
			"Invalid motor target for creating a link")
	assert(connected_motor == 0, "Linking a particual atom when the entire structure is connected is not possible")
	assert(_valid_atoms.has(in_atom_id) and _atoms.size() > in_atom_id, "Invalid atom ID")
	var motor_id: int = out_motor_context.nano_structure.int_guid
	if _motor_links.get(in_atom_id, 0) == motor_id:
		# Nothin to do here
		return
	_signal_queue_motor_links_changed.push_back(in_atom_id)
	_motor_links[in_atom_id] = motor_id


func atom_clear_motor_link(in_atom_id: int) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(connected_motor == 0, "Disconnecting a particular atom when the entire structure is connected is not possible")
	assert(_valid_atoms.has(in_atom_id) and _atoms.size() > in_atom_id, "Invalid atom ID")
	if _motor_links.has(in_atom_id):
		_motor_links.erase(in_atom_id)
		_signal_queue_motor_links_changed.push_back(in_atom_id)


func atom_has_motor_link(in_atom_id: int) -> bool:
	if connected_motor != 0:
		return true
	return _motor_links.has(in_atom_id)


func atoms_count_visible_by_type(types_to_count: PackedInt32Array) -> int:
	var count: int = 0
	for atom_id: int in _atoms.size():
		var atom: NanoAtomLegacy = _atoms[atom_id]
		if atom.valid and atom.atomic_number in types_to_count and is_atom_visible(atom_id):
			count += 1
	return count


func motor_link_get_motor_id(in_atom_id: int) -> int:
	if connected_motor != 0:
		return connected_motor
	else:
		return _motor_links.get(in_atom_id, 0)


func motor_link_get_motor_position(in_atom_id: int, in_parent_context: StructureContext) -> Vector3:
	var motor_id: int = motor_link_get_motor_id(in_atom_id)
	var motor: NanoVirtualMotor = in_parent_context.workspace_context.workspace.get_structure_by_int_guid(motor_id) as NanoVirtualMotor
	assert(is_instance_valid(motor), "Atom is not linked to a motor")
	return motor.get_transform().origin


func motor_links_get_all() -> Dictionary: # { atom_id<int> = motor_id<int> }
	if connected_motor != 0:
		var motor_links: Dictionary = {}
		for atom_id: int in get_valid_atoms():
			motor_links[atom_id] = connected_motor
		return motor_links
	return _motor_links.duplicate()


func motor_links_count() -> int:
	if connected_motor != 0:
		return get_valid_atoms_count()
	return _motor_links.size()


func _set_connected_motor(in_motor_id: int) -> void:
	if !_initialized:
		#during initialization do not emmit signals
		connected_motor = in_motor_id
		return
	# disabled since we are now working on snapshots, this probably should not have any setter anymore
	#assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	connected_motor = in_motor_id
	_motor_links.clear()
	_signal_queue_motor_links_changed = get_valid_atoms() ## all atoms where changed
	pass


func clear() -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	_atoms.clear()
	_bonds.clear()
	_valid_atoms.clear()
	hidden_atoms.clear()
	hidden_bonds.clear()
	_invalid_springs.clear()
	_springs.clear()
	_invalid_atoms_count = 0
	_highest_spring_id = -1
	atoms_cleared.emit()


func get_aabb() -> AABB:
	var aabb: AABB = AABB()
	if _atoms.is_empty():
		return aabb
	var is_first: bool = true
	for atom: NanoAtomLegacy in _atoms:
		if atom.valid:
			if is_first:
				aabb.position = atom.position
				is_first = false
			else:
				aabb = aabb.expand(atom.position)
	return aabb.abs()


func init_remap_structure_ids(in_structures_map: Dictionary) -> void:
	for spring: NanoSpring in _springs.values():
		var old_id: int = spring.target_anchor
		var new_structure: NanoStructure = in_structures_map.get(old_id, null)
		assert(is_instance_valid(new_structure), "Virtual anchor has vanished during import")
		spring.target_anchor = new_structure.int_guid


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary =  super.create_state_snapshot()
	state_snapshot["script.resource_path"] = get_script().resource_path
	
	var atoms_dump: Array[NanoAtomLegacy] = []
	for atom: NanoAtomLegacy in _atoms:
		var atom_copy := atom.create_duplicate()
		atoms_dump.append(atom_copy)
	
	var springs_dump: Dictionary = {}
	for spring_id: int in _springs:
		var spring: NanoSpring = _springs[spring_id]
		springs_dump[spring_id] = spring.duplicate()
	
	state_snapshot["_atoms"] = atoms_dump
	state_snapshot["_bonds"] = _bonds.duplicate(true)
	state_snapshot["_springs"] = springs_dump
	state_snapshot["_invalid_atoms_count"] = _invalid_atoms_count
	state_snapshot["_invalid_bonds_count"] = _invalid_bonds_count
	state_snapshot["representation"] = representation
	state_snapshot["_motor_links"] = _motor_links.duplicate()
	state_snapshot["_valid_atoms"] = _valid_atoms.duplicate()
	state_snapshot["_highest_spring_id"] = _highest_spring_id
	state_snapshot["_invalid_springs"] = _invalid_springs.duplicate()
	state_snapshot["signals"] = History.create_signal_snapshot_for_object(self)
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_state_snapshot)
	_atoms.clear()
	var atoms_to_apply: Array[NanoAtomLegacy] = in_state_snapshot["_atoms"]
	for atom_to_apply: NanoAtomLegacy in atoms_to_apply:
		var atom: NanoAtomLegacy = atom_to_apply.create_duplicate()
		_atoms.append(atom)
	
	_springs.clear()
	var springs_to_apply: Dictionary = in_state_snapshot["_springs"]
	for spring_id: int in springs_to_apply:
		var spring: NanoSpring = springs_to_apply[spring_id].duplicate()
		_springs[spring_id] = spring
	
	_bonds = in_state_snapshot["_bonds"].duplicate(true)
	_invalid_atoms_count = in_state_snapshot["_invalid_atoms_count"]
	_invalid_bonds_count = in_state_snapshot["_invalid_bonds_count"]
	representation = in_state_snapshot["representation"]
	_motor_links = in_state_snapshot["_motor_links"].duplicate()
	_valid_atoms = in_state_snapshot["_valid_atoms"].duplicate()
	_highest_spring_id = in_state_snapshot["_highest_spring_id"]
	_invalid_springs = in_state_snapshot["_invalid_springs"].duplicate()
	
	# This call defferent should not be needed when Renderer will implement snapshoting
	History.apply_signal_snapshot_to_object.call_deferred(self, in_state_snapshot["signals"])
