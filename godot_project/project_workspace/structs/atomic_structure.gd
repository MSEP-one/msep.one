"@abstract_class"
class_name AtomicStructure extends NanoStructure
## Common class representing structure that directy consists of bonds and atoms


signal atoms_visibility_changed(atoms: PackedInt32Array)
signal bonds_visibility_changed(bonds: PackedInt32Array)
signal springs_visibility_changed(springs: PackedInt32Array)
signal atoms_added(atoms_added: PackedInt32Array)
signal atoms_removed(atoms_removed: PackedInt32Array)
signal atoms_moved(atoms_moved: PackedInt32Array)
signal atoms_atomic_number_changed(changed_atoms: Array[Vector2i])
signal atoms_color_override_changed(changed_atoms: PackedInt32Array)
signal atoms_locking_changed(atoms_changed: PackedInt32Array)
signal atoms_cleared()
signal bonds_created(new_bonds: PackedInt32Array)
signal bonds_removed(removed_bonds: PackedInt32Array)
signal bonds_changed(changed_bonds: PackedInt32Array)
signal motor_links_visibility_changed(atoms: PackedInt32Array)
signal motor_links_changed(modified_links: PackedInt32Array)
signal springs_added(springs_added: PackedInt32Array)
signal springs_removed(springs_removed: PackedInt32Array)
signal springs_moved(springs_moved: PackedInt32Array)


const INVALID_ATOM_ID = -1
const INVALID_ATOMIC_NUMBER = -1
const INVALID_BOND_ID = -1
const INVALID_SPRING_ID = -1





@export var connected_motor: int = 0: set = _set_connected_motor
@export var color_overrides: Dictionary = {
	# atom_id<int> : color<Color>
}
@export var hidden_bonds: Dictionary = {
	# bond_id<int>: true<bool>
}
@export var hidden_atoms: Dictionary = {
	# atom_id<int>: true<bool>
}
@export var hidden_springs: Dictionary = {
	# spring_id<int>: true<bool>
}
@export var hidden_motor_links: Dictionary = {
	# atom_id<int>: true<bool>
}
@export var locked_atoms: Dictionary = {
	# atom_id<int>: true<bool>
}
@export var _atoms_to_related_springs: Dictionary = {
	# atom_id <int> : connected_springs<Dictionary = {spring_id<int> : true<bool>} >
}

var _signal_queue_atoms_added: PackedInt32Array = PackedInt32Array()
var _signal_queue_atoms_moved: PackedInt32Array = PackedInt32Array()
var _signal_queue_atoms_removed: PackedInt32Array = PackedInt32Array()
var _signal_queue_motor_links_changed: PackedInt32Array = PackedInt32Array()
var _signal_queue_atoms_color_changed: PackedInt32Array = PackedInt32Array()
var _signal_queue_atomic_number_changed: Array[Vector2i] = [] #(ATOM_ID, ATOMIC_NUMBER)
var _signal_queue_bonds_created: PackedInt32Array = PackedInt32Array()
var _signal_queue_bonds_removed: PackedInt32Array = PackedInt32Array()
var _signal_queue_bonds_changed: PackedInt32Array = PackedInt32Array()
var _signal_queue_atoms_locking_changed: PackedInt32Array = PackedInt32Array()
var _signal_queue_springs_added: PackedInt32Array = PackedInt32Array()
var _signal_queue_springs_removed: PackedInt32Array = PackedInt32Array()
var _signal_queue_springs_moved: Dictionary = {
	#spring_id<int> : true<bool>
}

var _is_being_edited: bool = false
var _initialized: bool = false


static func create() -> AtomicStructure:
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_LMDB_STRUCTURE):
		return LMDBNanoStruct.new()
	else:
		return NanoMolecularStructure.new()


func _init() -> void:
	_post_init.call_deferred()


func _post_init() -> void:
	# ensure visibility state recreated if project is loaded from msep one file
	for spring_id: int in hidden_springs.keys():
		if not spring_has(spring_id):
			# A workspace file may be referencing old _invalid_springs that no longer exists
			# after saving and reloading the file. We purge them now
			hidden_springs.erase(spring_id)
	apply_visibility_snapshot(VisibilitySnapshot.new(hidden_atoms, hidden_bonds, hidden_springs))
	_initialized = true


#region: Edit tracking
func start_edit() -> void:
	assert(not _is_being_edited, "I'm already being edited, make sure to call end_edit() when you are done with edits")
	_is_being_edited = true
	return

func is_being_edited() -> bool:
	return _is_being_edited


func end_edit() -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	_is_being_edited = false
	
	var has_changed: bool = (not _signal_queue_atoms_added.is_empty()) \
			or (not _signal_queue_atoms_moved.is_empty()) \
			or (not _signal_queue_atoms_removed.is_empty()) \
			or (not _signal_queue_motor_links_changed.is_empty()) \
			or (not _signal_queue_atoms_color_changed.is_empty()) \
			or (not _signal_queue_atomic_number_changed.is_empty())\
			or (not _signal_queue_bonds_created.is_empty()) \
			or (not _signal_queue_bonds_removed.is_empty()) \
			or (not _signal_queue_bonds_changed.is_empty()) \
			or (not _signal_queue_atoms_locking_changed.is_empty()) \
			or (not _signal_queue_springs_added.is_empty()) \
			or (not _signal_queue_springs_removed.is_empty()) \
			or (not _signal_queue_springs_moved.is_empty())
	if has_changed:
		_update_springs_moved_queue()
		_flush_signal_queue(atoms_removed, _signal_queue_atoms_removed)
		_flush_signal_queue(atoms_added, _signal_queue_atoms_added)
		_flush_signal_queue(bonds_removed, _signal_queue_bonds_removed)
		_flush_signal_queue(bonds_created, _signal_queue_bonds_created)
		_flush_signal_queue(motor_links_changed, _signal_queue_motor_links_changed)
		_flush_signal_queue(atoms_color_override_changed, _signal_queue_atoms_color_changed)
		_flush_signal_queue(atoms_moved, _signal_queue_atoms_moved)
		_flush_signal_queue(atoms_atomic_number_changed, _signal_queue_atomic_number_changed)
		_flush_signal_queue(bonds_changed, _signal_queue_bonds_changed)
		_flush_signal_queue(atoms_locking_changed, _signal_queue_atoms_locking_changed)
		_flush_signal_queue(springs_added, _signal_queue_springs_added)
		_flush_signal_queue(springs_removed, _signal_queue_springs_removed)
		_flush_signal_queue(springs_moved, PackedInt32Array(_signal_queue_springs_moved.keys()))
		_signal_queue_springs_moved.clear()
		emit_changed()


## Removes every atom, bond, and spring from this structure
func clear() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func _flush_signal_queue(in_signal: Signal, out_signal_queue: Variant) -> void:
	if out_signal_queue.is_empty():
		return
	in_signal.emit(out_signal_queue)
	out_signal_queue.clear()


func _update_springs_moved_queue() -> void:
	for atom_id: int in _signal_queue_atoms_moved:
		if not _atoms_to_related_springs.has(atom_id):
			continue
		var related_moved_springs: PackedInt32Array = _atoms_to_related_springs[atom_id].keys()
		for spring_id: int in related_moved_springs:
			if spring_is_visible(spring_id):
				_signal_queue_springs_moved[spring_id] = true
#endregion: Edit tracking


## Returns number of atoms that has been created in this NanoStructure
## and have not been removed.
func get_valid_atoms_count() -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return 0


## Request to add an atom to the structure, the type and members of the in_args
## argument will depend on the subclass of NanoStructure.
## Returns the id of the newly added atom or -1 (INVALID_ATOM_ID)
## if no atom was added at all
func add_atom(_in_args: Variant = null) -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return INVALID_ATOM_ID


## Adds multiple atoms to the structure, recieves an array of parameters.
## Each element in the array is a collection of parameters to create an atom
## Returns an array with the ids of the newly created atoms
func add_atoms(atoms_parameters: Array[AddAtomParameters]) -> PackedInt32Array:
	var atom_ids: PackedInt32Array = []
	for parameters: AddAtomParameters in atoms_parameters:
		atom_ids.push_back(add_atom(parameters))
	return atom_ids


## Request to remove an atom from the structure. Returns true on success and
## false if anything prevented from removing the atom
func remove_atom(_in_atom_id: int) -> bool:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return false


## Removes multiple atoms from the structure
## Recieves an array with the ids of the atoms that should be removed
func remove_atoms(in_atom_idxs: PackedInt32Array) -> void:
	for atom_idx: int in in_atom_idxs:
		remove_atom(atom_idx)


## Returns wether or not an atom has been removed from the structure
func is_atom_valid(_in_atom_id: int) -> bool:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return false


## Returns wether the atom should be rendered and/or mouse picked
func is_atom_visible(in_atom_id: int) -> bool:
	if is_atom_hidden_by_user(in_atom_id):
		return false
	if not are_hydrogens_visible() and atom_get_atomic_number(in_atom_id) == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
		return false
	return true


## Returns true if the atom is explicitely hidden with the "Hide Selected" action.
## Unlike is_atom_visible(), this method does not consider the hydrogen rendering state.
func is_atom_hidden_by_user(in_atom_id: int) -> bool:
	return hidden_atoms.get(in_atom_id, false)


## Returns the list of atom_ids that have not been removed from the structure
func get_valid_atoms() -> PackedInt32Array:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return PackedInt32Array()


## Returns the list of valid atom_ids that are not hidden
func get_visible_atoms() -> PackedInt32Array:
	var visible_atoms: PackedInt32Array = PackedInt32Array()
	var atoms: PackedInt32Array = get_valid_atoms()
	for atom_id in atoms:
		if is_atom_visible(atom_id):
			visible_atoms.append(atom_id)
	return visible_atoms


## Returns the numbers of protons in atom's nucleous. This reffers to the id of an
## element in the Periodic Table
func atom_get_atomic_number(_in_atom_id: int) -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return PeriodicTable.ATOMIC_NUMBER_HYDROGEN


## Sets atomic number of a given atom. This reffers to the id of an
## element in the Periodic Table
func atom_set_atomic_number(_in_atom_id: int, _in_atomic_number: int) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


## Calculate the [url=https://en.wikipedia.org/wiki/Formal_charge]formal charge[/url] of a given atom
func atom_get_formal_charge(_in_atom_id: int) -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return 0


## Returns the position of the atom, relative to structure's transform
func atom_get_position(_in_atom_id: int) -> Vector3:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return Vector3()


## Sets the position of a given atom, relative to structure's transform
## Returs true if succeeds or false if something prevents the change
func atom_set_position(_in_atom_id: int, _in_pos: Vector3) -> bool:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return false


## Should be used instead of [code]atom_set_position()[/code] in cases where there is many atoms to move,
## for performance reasons - this way [code]changed[/code] signal is emitted only once
func atoms_set_positions(_in_atoms: PackedInt32Array, _in_positions: PackedVector3Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


## Setting an atom as locked creates a force during simulation (and relaxation if enabled)
## that attempts to maintain it in it's initial position
func atoms_set_locked(in_atoms: PackedInt32Array, in_is_locked: bool) -> void:
	assert(_is_being_edited, "Color override can only be changed while structure is being edited")
	for atom_id: int in in_atoms:
		if locked_atoms.get(atom_id, false) == in_is_locked:
			continue
		_signal_queue_atoms_locking_changed.push_back(atom_id)
		if in_is_locked:
			locked_atoms[atom_id] = true
		else:
			locked_atoms.erase(atom_id)
	return


## Returns true if the atom is locked
func atom_is_locked(in_atom_id: int) -> bool:
	return locked_atoms.get(in_atom_id, false)


func atom_is_hydrogen(in_atom_id: int) -> bool:
	var atomic_number: int = atom_get_atomic_number(in_atom_id)
	return atomic_number == PeriodicTable.ATOMIC_NUMBER_HYDROGEN


func atom_is_any_hydrogen(in_atom_ids: PackedInt32Array) -> bool:
	for atom_id in in_atom_ids:
		if atom_is_hydrogen(atom_id):
			return true
	return false


## Returns an array with the IDs of all locked atoms
func get_locked_atoms() -> PackedInt32Array:
	return PackedInt32Array(locked_atoms.keys())


## returns IDs of the bonds that given atom is participating in
func atom_get_bonds(_in_atom_id: int) -> PackedInt32Array:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return PackedInt32Array()


## Returns the ID of the another atom that's participating in in_bond_id
func atom_get_bond_target(_in_atom_id: int, _in_bond_id: int) -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return INVALID_ATOM_ID


## Returns bond id between first atom and second atom or -1 if bond do not exists
func atom_find_bond_between(_in_atom_id_a: int, _in_atom_id_b: int) -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return -1


## Returns remaining valence which is still free to use
func atom_get_remaininig_valence(in_atom_id: int) -> int:
	var data: ElementData = PeriodicTable.get_by_atomic_number(atom_get_atomic_number(in_atom_id))
	var atom_bonds: PackedInt32Array = atom_get_bonds(in_atom_id)
	var used_valence: int = 0
	for bond_id in atom_bonds:
		var bond_order: int = get_bond(bond_id).z
		used_valence += bond_order
	var valence_left: int = data.valence
	if data.number > 5:
		valence_left = 8 - valence_left
	valence_left -= used_valence
	return valence_left


func has_color_override(in_atom_id: int) -> bool:
	return color_overrides.has(in_atom_id)


func get_color_override(in_atom_id: int) -> Color:
	return color_overrides.get(in_atom_id, null)


func set_color_override(in_atoms: PackedInt32Array, color: Color) -> void:
	assert(_is_being_edited, "Color override can only be changed while structure is being edited")
	for atom_id: int in in_atoms:
		color_overrides[atom_id] = color
	_signal_queue_atoms_color_changed.append_array(in_atoms)


#TODO: This is probably not needed (THIS COMMENT SHOULD NOT BE PART OF PR)
func get_color_override_snapshot() -> Dictionary:
	return color_overrides.duplicate()


#TODO: This is probably not needed (THIS COMMENT SHOULD NOT BE PART OF PR)
func apply_color_override_snapshot(in_color_snapshot: Dictionary) -> void:
	assert(_is_being_edited, "Color override can only be changed while structure is being edited")
	var all_colors: Dictionary = {
		# atom_id<int> : color<Color>
	}
	all_colors.merge(color_overrides)
	all_colors.merge(in_color_snapshot)
	
	for atom_id: int in all_colors.keys():
		if color_overrides.get(atom_id, null) == in_color_snapshot.get(atom_id, null):
			# did not change
			continue
		_signal_queue_atoms_color_changed.append(atom_id)
		if not in_color_snapshot.has(atom_id):
			# override was removed
			color_overrides.erase(atom_id)
		else:
			# color was set or changed
			color_overrides[atom_id] = in_color_snapshot[atom_id]


func remove_color_override(in_atoms: PackedInt32Array) -> void:
	assert(_is_being_edited, "Color override can only be changed while structure is being edited")
	for atom_id: int in in_atoms:
		color_overrides.erase(atom_id)
	_signal_queue_atoms_color_changed.append_array(in_atoms)


## Create a bond between first atom and second atom, returns bond ID
func add_bond(_in_atom_id_a: int, _in_atom_id_b: int, _in_bond_order: int) -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return INVALID_BOND_ID


## Removes bond with a given ID
func remove_bond(_in_bond_id: int) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


## Request to set a previously removed bond as valid again in the structure.
## Returns true on success and false if anything prevented from revalidating the bond
func revalidate_bond(_in_bond_id: int) -> bool:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return false


## Returns wether or not a bond has been removed from the structure
func is_bond_valid(_in_bond_id: int) -> bool:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return false


## Returns the list of bond_ids that have not been removed from the structure
func get_valid_bonds() -> PackedInt32Array:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return PackedInt32Array()


## Returns wether the bond should be rendered and/or mouse picked
func is_bond_visible(in_bond_id: int) -> bool:
	if is_bond_hidden_by_user(in_bond_id):
		return false
	if not are_hydrogens_visible():
		var bond: Vector3i = get_bond(in_bond_id)
		return atom_get_atomic_number(bond.x) != PeriodicTable.ATOMIC_NUMBER_HYDROGEN and \
				atom_get_atomic_number(bond.y) != PeriodicTable.ATOMIC_NUMBER_HYDROGEN
	return true


## Returns true if the bond is explicitely hidden with the "Hide Selected" action.
## Unlike is_bond_visible(), this method does not consider the hydrogen rendering state.
func is_bond_hidden_by_user(in_bond_id: int) -> bool:
	return hidden_bonds.get(in_bond_id, false)


## Returns the list of bond_ids that are not hidden in the structure
func get_visible_bonds() -> PackedInt32Array:
	var visible_bonds: PackedInt32Array = PackedInt32Array()
	var valid_bonds: PackedInt32Array = get_valid_bonds()
	for bond_id in valid_bonds:
		if is_bond_visible(bond_id):
			visible_bonds.append(bond_id)
	return visible_bonds


## Returns number of bonds that has been created in this NanoStructure
## and have not been removed.
func get_valid_bonds_count() -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return 0


## Returns the list with all existing bonds ids
func get_bonds_ids() -> PackedInt32Array:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return PackedInt32Array()


## Returns bond information in form of Vector3i
## x component: ID of the first atom participating in bond
## y component: ID of the second atom participating in bond
## z component: bond order
func get_bond(_in_bond_id: int) -> Vector3i:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return Vector3i()


## Sets the bond order
func bond_set_order(_in_bond_id: int, _in_bond_order: int) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func spring_create(_in_anchor_id: int, _in_atom_id: int, _in_spring_constant_force: float,
			_is_equilibrium_length_automatic: bool, _in_equilibrium_manual_length: float) -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return INVALID_SPRING_ID


func spring_has(_in_spring_id: int) -> bool:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return false


func spring_invalidate(_in_spring_id: int) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func spring_revalidate(_in_spring_id: int) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func spring_get_atom_id(_in_spring_id: int) -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return INVALID_ATOM_ID


func spring_get_atom_position(_in_spring_id: int) -> Vector3:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return Vector3()


func spring_get_anchor_id(_in_spring_id: int) -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return -1


func spring_get_anchor_position(_in_spring_id: int, _in_parent_context: StructureContext) -> Vector3:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return Vector3()


func spring_get_equilibrium_length_is_auto(_in_spring_id: int) -> bool:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return false


func spring_set_equilibrium_lenght_is_auto(_in_spring_id: int, _in_is_auto: bool) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func spring_set_equilibrium_manual_length(_in_spring_id: int, _new_equilibrium_manual_length: float) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func spring_get_equilibrium_manual_length(_in_spring_id: int) -> float:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return -1.0


func spring_calculate_equilibrium_auto_length(_in_spring_id: int, _in_parent_context: StructureContext) -> float:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return -1.0


func spring_get_current_equilibrium_length(in_spring_id: int, in_parent_context: StructureContext) -> float:
	if spring_get_equilibrium_length_is_auto(in_spring_id):
		return spring_calculate_equilibrium_auto_length(in_spring_id, in_parent_context)
	return spring_get_equilibrium_manual_length(in_spring_id)


func spring_get_constant_force(_in_spring_id: int) -> float:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return -1.0


func spring_set_constant_force(_in_spring_id: int, _new_force: float) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func springs_get_all() -> PackedInt32Array:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return PackedInt32Array()


func springs_get_valid() -> PackedInt32Array:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return PackedInt32Array()


func springs_count() -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return -1


## Returns true if the spring is explicitely hidden with the "Hide Selected" action.
## Unlike spring_is_visible(), this method does not consider the hydrogen rendering state.
func spring_is_hidden_by_user(in_spring_id: int) -> bool:
	return hidden_springs.get(in_spring_id, false)


func spring_is_visible(in_spring_id: int) -> bool:
	if spring_is_hidden_by_user(in_spring_id):
		return false
	if not are_hydrogens_visible():
		var related_atom: int = spring_get_atom_id(in_spring_id)
		var atomic_nmb: int = atom_get_atomic_number(related_atom)
		return atomic_nmb != PeriodicTable.ATOMIC_NUMBER_HYDROGEN
	return true


func springs_get_visible() -> PackedInt32Array:
	var visible_springs: PackedInt32Array = PackedInt32Array()
	var springs: PackedInt32Array = springs_get_valid()
	for spring_id: int in springs:
		if spring_is_visible(spring_id):
			visible_springs.append(spring_id)
	return visible_springs


func atom_get_springs(_in_atom_id: int) -> PackedInt32Array:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return PackedInt32Array()


func _set_connected_motor(_in_motor_id: int) -> void:
	# Handle this on each implementation subclass, when connecting the entire structure
	# to a motor you should clear all the specific particle connections as well
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)


## Create one or many links from this structure to [code]out_target_motor[/code]
func atoms_set_motor_link(in_atom_ids: PackedInt32Array, out_motor_context: StructureContext) -> void:
	for atom: int in in_atom_ids:
		atom_set_motor_link(atom, out_motor_context)


## Create one link from this structure to [code]out_target_motor[/code]
func atom_set_motor_link(_in_atom_id: int, _out_motor_context: StructureContext) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)


## Remove one or many existing link between [code]in_atom_ids[/code] and their's target motor
func atoms_clear_motor_link(in_atom_ids: PackedInt32Array) -> void:
	for atom: int in in_atom_ids:
		atom_clear_motor_link(atom)


## Remove the existing link between [code]in_atom_id[/code] and it's target motor
func atom_clear_motor_link(_in_atom_id: int) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)


## Returns true if [code]in_atom_id[/code] has a motor linked to it
func atom_has_motor_link(_in_atom_id: int) -> bool:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return false


## Returns the int_guid of the NanoVirtualMotor connected to [code]in_atom_id[/code] or 0 if not linked
func motor_link_get_motor_id(_in_atom_id: int) -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return 0


## Returns the position of the NanoVirtualMotor connected to [code]in_atom_id[/code] or asserts if not linked
func motor_link_get_motor_position(_in_atom_id: int, _in_parent_context: StructureContext) -> Vector3:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return Vector3()


## Returns the counts of atoms that are linked to a motor
func motor_links_count() -> int:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return 0


func merge_structure(in_structure: AtomicStructure, in_placement_xform: Transform3D,
			in_workspace: Workspace) -> MergeStructureResult:
	start_edit()
	var original_to_structure_atom_map: Dictionary = {}
	var new_atoms := PackedInt32Array()
	var new_bonds := PackedInt32Array()
	var new_springs := PackedInt32Array()
	var old_color_overrides: Dictionary = in_structure.get_color_override_snapshot()
	var new_color_overrides: Dictionary = {
	#	color<Color> = atoms_to_apply<PackedInt32Array>
	}
	# Add atoms
	for atom_id: int in in_structure.get_valid_atoms():
		var atomic_number: int = in_structure.atom_get_atomic_number(atom_id)
		assert(atomic_number > 0 and atomic_number <= 118, "Invalid atomic number: %d" % atomic_number)
		var pos: Vector3 = in_placement_xform * in_structure.atom_get_position(atom_id)
		var add_params := AtomicStructure.AddAtomParameters.new(atomic_number, pos)
		var new_atom_id: int = add_atom(add_params)
		if old_color_overrides.has(atom_id):
			var color: Color = old_color_overrides[atom_id]
			if not new_color_overrides.has(color):
				new_color_overrides[color] = PackedInt32Array()
			new_color_overrides[color].append(new_atom_id)
		original_to_structure_atom_map[atom_id] = new_atom_id
		new_atoms.push_back(new_atom_id)
	# Apply collected color overrides
	for color: Color in new_color_overrides.keys():
		var atoms_for_color: PackedInt32Array = new_color_overrides[color]
		set_color_override(atoms_for_color, color)
	# Add bonds
	for bond_id: int in in_structure.get_valid_bonds():
		if not in_structure.is_bond_valid(bond_id):
			continue
		var bond: Vector3i = in_structure.get_bond(bond_id)
		var atom1: int = bond[0]
		var atom2: int = bond[1]
		var new_atom_a: int = original_to_structure_atom_map[atom1]
		var new_atom_b: int = original_to_structure_atom_map[atom2]
		var order: int = bond[2]
		var existing_bond_id: int = atom_find_bond_between(new_atom_a, new_atom_b)
		if existing_bond_id < 0:
			bond_id = add_bond(new_atom_a, new_atom_b, order)
			new_bonds.push_back(bond_id)
	
	# Add Springs
	for spring_id: int in in_structure.springs_get_valid():
		if not in_structure.spring_has(spring_id):
			continue
		var related_anchor_id: int = in_structure.spring_get_anchor_id(spring_id)
		var related_atom: int = in_structure.spring_get_atom_id(spring_id)
		var new_atom: int = original_to_structure_atom_map[related_atom]
		var constant_force: float = in_structure.spring_get_constant_force(spring_id)
		var equilibrium_length_is_auto: float = in_structure.spring_get_equilibrium_length_is_auto(spring_id)
		var equilibrium_manual_length: float = in_structure.spring_get_equilibrium_manual_length(spring_id)
		var anchor: NanoVirtualAnchor = in_workspace.get_structure_by_int_guid(related_anchor_id)
		if _check_if_anchor_connected_to_atom(anchor, new_atom):
			continue
		var new_spring_id: int = spring_create(related_anchor_id, new_atom, constant_force,
				equilibrium_length_is_auto, equilibrium_manual_length)
		new_springs.append(new_spring_id)
	end_edit()
	return MergeStructureResult.new(original_to_structure_atom_map, new_atoms, new_bonds, new_springs)


func _check_if_anchor_connected_to_atom(in_anchor: NanoVirtualAnchor, in_atom: int) -> bool:
	if not in_anchor.is_structure_related(int_guid):
		return false
	var anchor_springs: PackedInt32Array = in_anchor.get_related_springs(int_guid)
	var atom_springs: PackedInt32Array = atom_get_springs(in_atom)
	for spring_id: int in atom_springs:
		if anchor_springs.find(spring_id) != -1:
			return true
	return false


## Can be used to show or hide atoms. Hidden atoms are still part of the structure but
## are not rendered and can't be interacted with until they become visible again.
func set_atoms_visibility(in_atoms: PackedInt32Array, in_visible: bool, in_auto_hide_bonds: bool = true) -> void:
	if in_atoms.is_empty():
		return

	for atom_id: int in in_atoms:
		if in_visible:
			hidden_atoms.erase(atom_id)
		else:
			hidden_atoms[atom_id] = true
	atoms_visibility_changed.emit(in_atoms)
	
	if not in_auto_hide_bonds:
		return
	
	# Auto update the connected bonds visibility.
	var bonds_to_update: Dictionary = {
		# bond_id<int>: true<bool>
	}
	var springs_to_update: Dictionary = {
		# spring_id<int>: true<bool>
	}
	for atom_id: int in in_atoms:
		var bonds: PackedInt32Array = atom_get_bonds(atom_id)
		for bond_id in bonds:
			# When hiding an atom, hide all connected bonds
			if not in_visible and is_bond_visible(bond_id):
				bonds_to_update[bond_id] = true
				continue
			# When showing an atom, show all connected bonds connected to two visible atoms
			if in_visible and not is_bond_visible(bond_id):
				var bond: Vector3i = get_bond(bond_id)
				if is_atom_visible(bond.x) and is_atom_visible(bond.y):
					bonds_to_update[bond_id] = true
		
		var springs: PackedInt32Array = atom_get_springs(atom_id)
		for spring_id: int in springs:
			# When hiding an atom, hide all connected springs
			if not in_visible and spring_is_visible(spring_id):
				springs_to_update[spring_id] = true
				continue
			
			# When showing an atom, show all connected springs
			if in_visible and not spring_is_visible(spring_id):
				springs_to_update[spring_id] = true
				continue
	
	if not bonds_to_update.is_empty():
		var bonds_id: PackedInt32Array = PackedInt32Array(bonds_to_update.keys())
		set_bonds_visibility(bonds_id, in_visible)
	
	if not springs_to_update.is_empty():
		var springs_ids: PackedInt32Array = PackedInt32Array(springs_to_update.keys())
		set_springs_visibility(springs_ids, in_visible)


## Can be used to show or hide bonds. If a bond is connected to a hidden atom, this bond
## will also automatically be hidden.
func set_bonds_visibility(in_bonds: PackedInt32Array, in_visible: bool) -> void:
	if in_bonds.is_empty():
		return
	
	for bond_id: int in in_bonds:
		if in_visible:
			hidden_bonds.erase(bond_id)
		else:
			hidden_bonds[bond_id] = true
	bonds_visibility_changed.emit(in_bonds)


func set_springs_visibility(in_springs: PackedInt32Array, in_visible: bool) -> void:
	if in_springs.is_empty():
		return
	var changed_visibilities: PackedInt32Array = []
	for spring_id: int in in_springs:
		var have_changed: bool = hidden_springs.get(spring_id, false) == in_visible
		if in_visible:
			hidden_springs.erase(spring_id)
		else:
			hidden_springs[spring_id] = true
		if have_changed:
			changed_visibilities.push_back(spring_id)
	if not changed_visibilities.is_empty():
		springs_visibility_changed.emit(changed_visibilities)


func set_motor_link_visibility(in_atoms: PackedInt32Array, in_visible: bool) -> void:
	if in_atoms.is_empty():
		return
	for atom_id: int in in_atoms:
		if in_visible:
			hidden_motor_links.erase(atom_id)
		else:
			hidden_motor_links[atom_id] = true
	motor_links_visibility_changed.emit(in_atoms)


## Returns a list of every hidden atoms in this structure.
func get_hidden_atoms() -> PackedInt32Array:
	return PackedInt32Array(hidden_atoms.keys())


## Returns a list of every hidden bonds in this structure.
func get_hidden_bonds() -> PackedInt32Array:
	return PackedInt32Array(hidden_bonds.keys())


## Returns a list of every hidden spring in this structure.
func springs_get_hidden() -> PackedInt32Array:
	return PackedInt32Array(hidden_springs.keys())


func motor_links_get_hidden() -> PackedInt32Array:
	return PackedInt32Array(hidden_motor_links.keys())


func are_hydrogens_visible() -> bool:
	return _representation_settings.get_ref().get_hydrogens_visible()


func disable_hydrogens_visibility() -> void:
	_representation_settings.get_ref().set_hydrogen_visibility_and_notify(false)


func enable_hydrogens_visibility() -> void:
	_representation_settings.get_ref().set_hydrogen_visibility_and_notify(true)


func motor_link_is_hidden_by_user(in_atom_id: int) -> bool:
	return hidden_motor_links.get(in_atom_id, false)


func motor_link_is_visible(in_atom_id: int) -> bool:
	if motor_link_is_hidden_by_user(in_atom_id):
		return false
	if not are_hydrogens_visible():
		var atomic_nmb: int = atom_get_atomic_number(in_atom_id)
		return atomic_nmb != PeriodicTable.ATOMIC_NUMBER_HYDROGEN
	return true


func motor_links_get_visible() -> PackedInt32Array:
	if connected_motor != 0:
		return get_valid_atoms()
	var visible_motor_links: PackedInt32Array = []
	for atom_id: int in motor_links_get_all().keys():
		if motor_link_is_visible(atom_id):
			visible_motor_links.append(atom_id)
	return visible_motor_links
	


## Returns a list of all atoms linked to a motor
func motor_links_get_all() -> Dictionary: # { atom_id<int> = motor_id<int> }
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return {}


func has_hidden_atoms_bonds_springs_or_motor_links() -> bool:
	return ( not hidden_atoms.is_empty() or not hidden_bonds.is_empty() or
			not hidden_springs.is_empty() or not hidden_motor_links.is_empty() )


func get_readable_type() -> String:
	return get_structure_name()


func create_state_snapshot() -> Dictionary:
	assert(not _is_being_edited, "Snapshot taken during AtomicStructure edit, nothing prevents us \
			from doing this under condition we have a good use case")
	var state_snapshot: Dictionary = super.create_state_snapshot()
	state_snapshot["connected_motor"] = connected_motor
	state_snapshot["color_overrides"] = color_overrides.duplicate()
	state_snapshot["hidden_bonds"] = hidden_bonds.duplicate()
	state_snapshot["hidden_atoms"] = hidden_atoms.duplicate()
	state_snapshot["hidden_springs"] = hidden_springs.duplicate()
	state_snapshot["hidden_motor_links"] = hidden_motor_links.duplicate()
	state_snapshot["locked_atoms"] = locked_atoms.duplicate()
	state_snapshot["_atoms_to_related_springs"] = _atoms_to_related_springs.duplicate(true)
	state_snapshot["_signal_queue_atoms_added"] = _signal_queue_atoms_added.duplicate()
	state_snapshot["_signal_queue_atoms_moved"] = _signal_queue_atoms_moved.duplicate()
	state_snapshot["_signal_queue_atoms_removed"] = _signal_queue_atoms_removed.duplicate()
	state_snapshot["_signal_queue_motor_links_changed"] = _signal_queue_motor_links_changed.duplicate()
	state_snapshot["_signal_queue_atoms_color_changed"] = _signal_queue_atoms_color_changed.duplicate()
	state_snapshot["_signal_queue_atomic_number_changed"] = _signal_queue_atomic_number_changed.duplicate()
	state_snapshot["_signal_queue_bonds_created"] = _signal_queue_bonds_created.duplicate()
	state_snapshot["_signal_queue_bonds_removed"] = _signal_queue_bonds_removed.duplicate()
	state_snapshot["_signal_queue_bonds_changed"] = _signal_queue_bonds_changed.duplicate()
	state_snapshot["_signal_queue_atoms_locking_changed"] = _signal_queue_atoms_locking_changed.duplicate()
	state_snapshot["_signal_queue_springs_added"] = _signal_queue_springs_added.duplicate()
	state_snapshot["_signal_queue_springs_removed"] = _signal_queue_springs_removed.duplicate()
	state_snapshot["_signal_queue_springs_moved"] = _signal_queue_springs_moved.duplicate()
	state_snapshot["_is_being_edited"] = _is_being_edited
	state_snapshot["_initialized"] = _initialized
	state_snapshot["signals"] = History.create_signal_snapshot_for_object(self)
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_state_snapshot)
	connected_motor = in_state_snapshot["connected_motor"]
	color_overrides = in_state_snapshot["color_overrides"].duplicate()
	hidden_bonds = in_state_snapshot["hidden_bonds"].duplicate()
	hidden_atoms = in_state_snapshot["hidden_atoms"].duplicate()
	hidden_springs = in_state_snapshot["hidden_springs"].duplicate()
	hidden_motor_links = in_state_snapshot["hidden_motor_links"].duplicate()
	locked_atoms = in_state_snapshot["locked_atoms"].duplicate()
	_atoms_to_related_springs = in_state_snapshot["_atoms_to_related_springs"].duplicate(true)
	_signal_queue_atoms_added = in_state_snapshot["_signal_queue_atoms_added"].duplicate()
	_signal_queue_atoms_moved = in_state_snapshot["_signal_queue_atoms_moved"].duplicate()
	_signal_queue_atoms_removed = in_state_snapshot["_signal_queue_atoms_removed"].duplicate()
	_signal_queue_motor_links_changed = in_state_snapshot["_signal_queue_motor_links_changed"].duplicate()
	_signal_queue_atoms_color_changed = in_state_snapshot["_signal_queue_atoms_color_changed"].duplicate()
	_signal_queue_atomic_number_changed = in_state_snapshot["_signal_queue_atomic_number_changed"].duplicate()
	_signal_queue_bonds_created = in_state_snapshot["_signal_queue_bonds_created"].duplicate()
	_signal_queue_bonds_removed = in_state_snapshot["_signal_queue_bonds_removed"].duplicate()
	_signal_queue_bonds_changed = in_state_snapshot["_signal_queue_bonds_changed"].duplicate()
	_signal_queue_atoms_locking_changed = in_state_snapshot["_signal_queue_atoms_locking_changed"].duplicate()
	_signal_queue_springs_added = in_state_snapshot["_signal_queue_springs_added"].duplicate()
	_signal_queue_springs_removed = in_state_snapshot["_signal_queue_springs_removed"].duplicate()
	_signal_queue_springs_moved = in_state_snapshot["_signal_queue_springs_moved"].duplicate()
	_is_being_edited = in_state_snapshot["_is_being_edited"]
	_initialized = in_state_snapshot["_initialized"]
	History.apply_signal_snapshot_to_object(self, in_state_snapshot["signals"])


## For undo/redo purposes. Returns the current state of hidden atoms and bonds.
func get_visibility_snapshot() -> VisibilitySnapshot:
	return VisibilitySnapshot.new(hidden_atoms, hidden_bonds, hidden_springs)


## Restore the visibility snapshot.
func apply_visibility_snapshot(in_snapshot: VisibilitySnapshot) -> void:
	var atoms_to_update: Dictionary = hidden_atoms.duplicate()
	atoms_to_update.merge(in_snapshot.hidden_atoms)
	var bonds_to_update: Dictionary = hidden_bonds.duplicate()
	bonds_to_update.merge(in_snapshot.hidden_bonds)
	var springs_to_update: Dictionary = hidden_springs.duplicate()
	springs_to_update.merge(in_snapshot.hidden_springs)
	hidden_atoms = in_snapshot.hidden_atoms.duplicate()
	hidden_bonds = in_snapshot.hidden_bonds.duplicate()
	hidden_springs = in_snapshot.hidden_springs.duplicate()
	atoms_visibility_changed.emit(PackedInt32Array(atoms_to_update.keys()))
	bonds_visibility_changed.emit(PackedInt32Array(bonds_to_update.keys()))
	springs_visibility_changed.emit(PackedInt32Array(springs_to_update.keys()))


class AddAtomParameters:
	var atomic_number: int
	var position: Vector3
	func _init(in_atomic_number: int, in_position: Vector3) -> void:
		atomic_number = in_atomic_number
		position = in_position


class MergeStructureResult:
	var original_to_structure_atom_map: Dictionary = {
	#	src_atom_id<int> = dst_atom_id<int>
	}
	var new_atoms: PackedInt32Array
	var new_bonds: PackedInt32Array
	var new_springs: PackedInt32Array
	func _init(in_original_to_structure_atom_map: Dictionary, in_new_atoms: PackedInt32Array,
				in_new_bonds: PackedInt32Array, in_new_springs: PackedInt32Array) -> void:
		original_to_structure_atom_map = in_original_to_structure_atom_map
		new_atoms = in_new_atoms
		new_bonds = in_new_bonds
		new_springs = in_new_springs


class VisibilitySnapshot:
	var hidden_atoms: Dictionary
	var hidden_bonds: Dictionary
	var hidden_springs: Dictionary
	func _init(in_atoms: Dictionary, in_bonds: Dictionary, in_springs: Dictionary) -> void:
		hidden_atoms = in_atoms.duplicate()
		hidden_bonds = in_bonds.duplicate()
		hidden_springs = in_springs.duplicate()

