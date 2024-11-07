class_name AtomSelection extends Node
# Responsible for providing api around MolecularStructure selection


var _atoms_selection: Dictionary = {
	#atom_id<int> : true<bool>
}

var _bonds_selection: Dictionary = {
	#bond_id<int> : true<bool>
}

# This is a list of bonds connected to one selected atom
# (bond which has two/none seleted atoms will never be on the list)
# This is tracked for atom selection movement performance improvements -> only movement of bonds
# from this list is calculated on cpu
var _bonds_partially_influenced_by_atoms: Dictionary = {
	#bond_id<int> : true<bool>
}


# This is a list of bonds connected to two selected atom, which aren't selected
# This is tracked for atom selection movement performance improvements -> bonds from this list
# do not need to be calculated on cpu, but we need this list to ensure we are able to reset
# mesh particle state for those bonds when selection is cleared
var _non_selected_bonds_fully_influenced_by_atoms: Dictionary = {
	#bond_id<int> : true<bool>
}

# Stores the delta between each calls to grow_selection. This data can then be
# used to shrink back the selection.
var _selection_layers: Array[SelectionSet] = []

var _aabb: AABB = AABB()
var _aabb_rebuild_needed: bool = true
var _structure_context: StructureContext = null


func initialize(in_related_structure_context: StructureContext) -> void:
	if is_instance_valid(_structure_context):
		var old_structure: NanoStructure = _structure_context.nano_structure
		if old_structure and old_structure.atoms_moved.is_connected(_on_atoms_moved):
			old_structure.atoms_moved.disconnect(_on_atoms_moved)
			old_structure.atoms_removed.disconnect(_on_atoms_removed)
			old_structure.bonds_created.disconnect(_on_bonds_created)
			old_structure.bonds_removed.disconnect(_on_bonds_removed)
	
	_structure_context = in_related_structure_context
	if not _structure_context.nano_structure is AtomicStructure:
		return
	_structure_context.nano_structure.atoms_moved.connect(_on_atoms_moved)
	_structure_context.nano_structure.atoms_removed.connect(_on_atoms_removed)
	_structure_context.nano_structure.bonds_created.connect(_on_bonds_created)
	_structure_context.nano_structure.bonds_removed.connect(_on_bonds_removed)


func get_atoms_selection() -> PackedInt32Array:
	return PackedInt32Array(_atoms_selection.keys())


func get_bonds_selection() -> PackedInt32Array:
	return PackedInt32Array(_bonds_selection.keys())


func get_bonds_partially_influenced_by_selection() -> PackedInt32Array:
	return PackedInt32Array(_bonds_partially_influenced_by_atoms.keys())


func get_non_selected_bonds_fully_influenced_by_selection() -> PackedInt32Array:
	return PackedInt32Array(_non_selected_bonds_fully_influenced_by_atoms.keys())


func get_bonds_partially_influenced_by_selection_as_dict() -> Dictionary:
	return _bonds_partially_influenced_by_atoms.duplicate()


func get_non_selected_bonds_fully_influenced_by_selection_as_dict() -> Dictionary:
	return _non_selected_bonds_fully_influenced_by_atoms.duplicate()

func get_newest_selected_atom_id() -> int:
	if _atoms_selection.is_empty():
		assert(false, "Can't return newest selected atom id, there is no selection")
		return AtomicStructure.INVALID_ATOM_ID
	return _atoms_selection.keys().back()


func has_selection() -> bool:
	return not _atoms_selection.is_empty() or not _bonds_selection.is_empty()


func has_atom_selection() -> bool:
	return not _atoms_selection.is_empty()


func are_many_atom_selected() -> bool:
	return _atoms_selection.size() > 1


func has_bond_selection() -> bool:
	return not _bonds_selection.is_empty()


func has_cached_selection_set() -> bool:
	return not _selection_layers.is_empty()


func clear_atom_selection() -> void:
	_atoms_selection.clear()
	_bonds_partially_influenced_by_atoms.clear()
	_non_selected_bonds_fully_influenced_by_atoms.clear()
	_selection_layers.clear()
	_aabb_rebuild_needed = true
	
	
func clear_bond_selection() -> void:
	_bonds_selection.clear()
	_selection_layers.clear()
	_aabb_rebuild_needed = true


func clear_selection_layers() -> void:
	_selection_layers.clear()


func deselect_atoms(in_atoms_to_deselect: PackedInt32Array) -> AtomDeselectionResult:
	var _related_structure: NanoStructure = _structure_context.nano_structure
	var success: bool = false
	var removed_partially_influenced_bonds: PackedInt32Array = PackedInt32Array()
	var added_partially_influenced_bonds: PackedInt32Array = PackedInt32Array()
	
	for atom_to_deselect in in_atoms_to_deselect:
		success = _atoms_selection.erase(atom_to_deselect) or success
	
	for deselected_atom in in_atoms_to_deselect:
		var related_bonds: PackedInt32Array = _related_structure.atom_get_bonds(deselected_atom)
		for bond_id in related_bonds:
			var was_bond_under_partial_influence: bool = _bonds_partially_influenced_by_atoms.erase(bond_id)
			if was_bond_under_partial_influence:
				removed_partially_influenced_bonds.append(bond_id)
				continue
			var paired_atom_id: int = _related_structure.atom_get_bond_target(deselected_atom, bond_id)
			if _atoms_selection.has(paired_atom_id):
				_bonds_partially_influenced_by_atoms[bond_id] = true
				_non_selected_bonds_fully_influenced_by_atoms.erase(bond_id)
				added_partially_influenced_bonds.append(bond_id)
	
	_aabb_rebuild_needed = success
	return AtomDeselectionResult.new(success, removed_partially_influenced_bonds,
		added_partially_influenced_bonds, in_atoms_to_deselect)


func select_atoms(in_atoms: PackedInt32Array) -> AtomSelectionResult:
	var any_new_atom_selected: bool = _internal_select_atoms(in_atoms)
	return _determine_bond_influence(any_new_atom_selected, in_atoms, false)


func select_atoms_and_get_auto_selected_bonds(in_atoms: PackedInt32Array) -> AtomSelectionResult:
	var any_new_atom_selected: bool = _internal_select_atoms(in_atoms)
	return _determine_bond_influence(any_new_atom_selected, in_atoms, true)


func select_by_type(in_types: PackedInt32Array) -> AtomSelectionResult:
	var related_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	var should_select: Callable = func(atom_id: int) -> bool:
		return in_types.has(related_structure.atom_get_atomic_number(atom_id))
	
	var visible_atoms := Array(related_structure.get_visible_atoms())
	var atoms_to_select := PackedInt32Array(visible_atoms.filter(should_select))
	return select_atoms_and_get_auto_selected_bonds(atoms_to_select)


func select_connected(in_show_hidden_objects: bool = false) -> AtomSelectionResult:
	var related_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	var atoms_to_select: Dictionary = {}
	var bonds_to_visit: Dictionary = _bonds_partially_influenced_by_atoms.duplicate()
	bonds_to_visit.merge(_bonds_selection)
	var all_bonds_visited: bool = false
	var hidden_atoms_to_show: PackedInt32Array = PackedInt32Array()
	var should_show_hydrogens: bool = false
	
	# Traverse the bonds network from the edges of the current selection and
	# store every unselected atoms it can find.
	while not all_bonds_visited:
		all_bonds_visited = true
		for bond_id: int in bonds_to_visit:
			if not bonds_to_visit[bond_id]: # Ignore the bonds already visited
				continue
			var bond: Vector3i = related_structure.get_bond(bond_id)
			for atom_id: int in [bond.x, bond.y]:
				if _atoms_selection.has(atom_id) or atoms_to_select.has(atom_id):
					continue
				if not related_structure.is_atom_visible(atom_id):
					if not in_show_hidden_objects:
						continue
					if related_structure.is_atom_hidden_by_user(atom_id):
						hidden_atoms_to_show.push_back(atom_id)
					if not should_show_hydrogens and not related_structure.are_hydrogens_visible() and related_structure.atom_get_atomic_number(atom_id) == 1:
						should_show_hydrogens = true
				atoms_to_select[atom_id] = true
				for connected_bond in related_structure.atom_get_bonds(atom_id):
					if not bonds_to_visit.has(connected_bond):
						bonds_to_visit[connected_bond] = true
			
			all_bonds_visited = false
			bonds_to_visit[bond_id] = false # Mark the bond as visited

	if atoms_to_select.is_empty():
		return AtomSelectionResult.new(false, PackedInt32Array(), PackedInt32Array(), PackedInt32Array())
	
	if should_show_hydrogens or not hidden_atoms_to_show.is_empty():
		var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
		if should_show_hydrogens:
			related_structure.enable_hydrogens_visibility()
		if not hidden_atoms_to_show.is_empty():
			related_structure.set_atoms_visibility(hidden_atoms_to_show, true)
		workspace_context.snapshot_moment("Update Visibility")
	
	var atoms_list: PackedInt32Array = PackedInt32Array(atoms_to_select.keys())
	clear_selection_layers()
	return select_atoms_and_get_auto_selected_bonds(atoms_list)


func can_grow_selection() -> bool:
	if _bonds_partially_influenced_by_atoms.size() + _non_selected_bonds_fully_influenced_by_atoms.size() > 0:
		# This conditions covers cases where atoms are selected but bonds are not
		return true
		
	var related_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	for bond_id: int in _bonds_selection.keys():
		var bond_data: Vector3i = related_structure.get_bond(bond_id)
		for atom_id: int in [bond_data.x, bond_data.y]:
			if not related_structure.is_atom_visible(atom_id):
				# Hidden atoms are exceptions
				continue
			if not _atoms_selection.has(atom_id):
				# This condition covers the case where at least one of the atoms
				# of this selected bond is not selected
				return true
	return false


func grow_selection() -> AtomSelectionResult:
	var atoms_to_select_dict: Dictionary = {}
	# In the list of atoms to select we include already selected atoms,
	# this helps to automatically expand selections of bonds in some corner cases
	for atom_id: int in get_atoms_selection():
		atoms_to_select_dict[atom_id] = true
	
	var related_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	var bonds_to_test: Dictionary = _bonds_partially_influenced_by_atoms.duplicate()
	bonds_to_test.merge(_bonds_selection)
	for bond_id: int in bonds_to_test:
		var bond: Vector3i = related_structure.get_bond(bond_id)
		for atom_id: int in [bond.x, bond.y]:
			if not related_structure.is_atom_visible(atom_id):
				continue
			if not _atoms_selection.has(atom_id):
				atoms_to_select_dict[atom_id] = true
	
	var atoms_to_select: PackedInt32Array = PackedInt32Array(atoms_to_select_dict.keys())
	if atoms_to_select.is_empty():
		return AtomSelectionResult.new(false, PackedInt32Array(), PackedInt32Array(), PackedInt32Array())
	
	var result: AtomSelectionResult = select_atoms_and_get_auto_selected_bonds(atoms_to_select)
	var selection_set: SelectionSet = SelectionSet.new(atoms_to_select, result.new_bonds_selected)
	_selection_layers.push_back(selection_set)
	return result


func shrink_selection() -> AtomDeselectionResult:
	if _selection_layers.is_empty():
		return AtomDeselectionResult.new(false, PackedInt32Array(), PackedInt32Array(), PackedInt32Array())
	var selection: SelectionSet = _selection_layers.pop_back()
	deselect_bonds(selection.bonds)
	var result: AtomDeselectionResult = deselect_atoms(selection.atoms)
	result.removed_partially_influenced_bonds.append_array(selection.bonds)
	return result


func _internal_select_atoms(in_atoms: PackedInt32Array) -> bool:
	var related_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	var out_is_any_new_atom_selected: bool = false
	for atom_id in in_atoms:
		if not _atoms_selection.has(atom_id):
			_atoms_selection[atom_id] = true
			out_is_any_new_atom_selected = true
			var selected_position: Vector3 = related_structure.atom_get_position(atom_id)
			_aabb = _aabb.expand(selected_position)
	return out_is_any_new_atom_selected


func _determine_bond_influence(in_any_atom_selected: bool, in_atoms: PackedInt32Array,
			in_update_bond_selection: bool) -> AtomSelectionResult:
	var related_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	var new_partially_influenced_bonds: PackedInt32Array = PackedInt32Array()
	var removed_partially_influenced_bonds: PackedInt32Array = PackedInt32Array()
	var freshly_selected_bonds: PackedInt32Array = PackedInt32Array()
	for atom_id in in_atoms:
		var bonds: PackedInt32Array = related_structure.atom_get_bonds(atom_id)
		for bond_id in bonds:
			var was_already_partially_influenced: bool = _bonds_partially_influenced_by_atoms.has(bond_id)
			if was_already_partially_influenced:
				#no longer partially influenced, it's now influenced by both atoms
				_bonds_partially_influenced_by_atoms.erase(bond_id)
				removed_partially_influenced_bonds.append(bond_id)
			
			var bond_participant: int = related_structure.atom_get_bond_target(atom_id, bond_id)
			if is_atom_selected(bond_participant):
				if in_update_bond_selection:
					_bonds_selection[bond_id] = true
					freshly_selected_bonds.append(bond_id)
					_non_selected_bonds_fully_influenced_by_atoms.erase(bond_id)
				else:
					_non_selected_bonds_fully_influenced_by_atoms[bond_id] = true
			else:
				_bonds_partially_influenced_by_atoms[bond_id] = true
				new_partially_influenced_bonds.append(bond_id)
	return AtomSelectionResult.new(in_any_atom_selected, new_partially_influenced_bonds,
			removed_partially_influenced_bonds, freshly_selected_bonds)


func is_atom_selected(in_atom_id: int) -> bool:
	return _atoms_selection.has(in_atom_id)


func is_bond_selected(in_bond_id: int) -> bool:
	return _bonds_selection.get(in_bond_id, false)


func select_bonds(in_bonds_ids: PackedInt32Array) -> bool:
	var related_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	var any_bond_selected: bool = false
	for bond_id in in_bonds_ids:
		if not _bonds_selection.has(bond_id):
			_bonds_selection[bond_id] = true
			any_bond_selected = true
			_non_selected_bonds_fully_influenced_by_atoms.erase(bond_id)
			
			var bond_data: Vector3i = related_structure.get_bond(bond_id)
			var first_bonded_atom_pos: Vector3 = related_structure.atom_get_position(bond_data.x)
			var second_bonded_atom_pos: Vector3 = related_structure.atom_get_position(bond_data.y)
			_aabb = _aabb.expand(first_bonded_atom_pos)
			_aabb = _aabb.expand(second_bonded_atom_pos)
	
	return any_bond_selected


func deselect_bonds(in_bonds_to_deselect: PackedInt32Array, out_deselected_bonds: PackedInt32Array = []) -> bool:
	var overall_success: bool = false
	var bond_success: bool = false
	for bond_to_deselect in in_bonds_to_deselect:
		bond_success = _bonds_selection.erase(bond_to_deselect)
		if bond_success:
			out_deselected_bonds.push_back(bond_to_deselect)
		overall_success = overall_success or bond_success
	_aabb_rebuild_needed = overall_success
	return overall_success


func get_aabb() -> AABB:
	if _aabb_rebuild_needed:
		_aabb = AABB()
		var already_included_atoms: Dictionary = _rebuild_bond_aabb()
		_rebuild_atom_aabb(already_included_atoms)
		_aabb_rebuild_needed = false
	return _aabb


func _rebuild_bond_aabb() -> Dictionary:
	var out_already_included_atoms: Dictionary = {}
	if _bonds_selection.is_empty():
		return out_already_included_atoms
	
	var related_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	var initial_bond: Vector3i = related_structure.get_bond(_bonds_selection.keys().front())
	var initial_position: Vector3 = related_structure.atom_get_position(initial_bond.x)
	var _aabb_bonds: AABB = AABB(initial_position, Vector3.ZERO)
	for bond_id: int in _bonds_selection:
		var bond_data: Vector3i = related_structure.get_bond(bond_id)
		var first_bonded_atom_pos: Vector3 = related_structure.atom_get_position(bond_data.x)
		var second_bonded_atom_pos: Vector3 = related_structure.atom_get_position(bond_data.y)
		_aabb_bonds = _aabb_bonds.expand(first_bonded_atom_pos)
		_aabb_bonds = _aabb_bonds.expand(second_bonded_atom_pos)
		if is_atom_selected(bond_data.x):
			out_already_included_atoms[bond_data.x] = true
		if is_atom_selected(bond_data.y):
			out_already_included_atoms[bond_data.y] = true
	
	if _aabb.is_equal_approx(AABB()):
		# in this case _aabb has wrong position (0,0,0), we don't want to resize it,
		# instead we want _aabb with proper position and 0 size
		_aabb = _aabb_bonds
	else:
		_aabb = _aabb.merge(_aabb_bonds)
	
	return out_already_included_atoms


func _rebuild_atom_aabb(in_already_included_atoms: Dictionary) -> void:
	if _atoms_selection.is_empty():
		return
	
	var related_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	var first_atom_position: Vector3 = related_structure.atom_get_position(_atoms_selection.keys().front())
	var _aabb_atoms: AABB = AABB(first_atom_position, Vector3.ZERO)
	for atom_id: int in _atoms_selection:
		if in_already_included_atoms.has(atom_id):
			continue
		var selected_position: Vector3 = related_structure.atom_get_position(atom_id)
		_aabb_atoms = _aabb_atoms.expand(selected_position)
	
	if _aabb.is_equal_approx(AABB()):
		# in this case _aabb has wrong position (0,0,0), we don't want to resize it,
		# instead we want _aabb with proper position and 0 size
		_aabb = _aabb_atoms
	else:
		_aabb = _aabb.merge(_aabb_atoms)


func _on_atoms_moved(_atoms: PackedInt32Array) -> void:
	_aabb_rebuild_needed = true


func _on_atoms_removed(in_atoms_removed: PackedInt32Array) -> void:
	for atom_id in in_atoms_removed:
		_atoms_selection.erase(atom_id)


func _on_bonds_removed(in_bonds_removed: PackedInt32Array) -> void:
	for bond_id in in_bonds_removed:
		_bonds_selection.erase(bond_id)
		_bonds_partially_influenced_by_atoms.erase(bond_id)


func _on_bonds_created(in_new_bonds: PackedInt32Array) -> void:
	# Update partial influence of new bonds
	var related_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	if not is_instance_valid(related_structure): return
	for bond_id in in_new_bonds:
		var bond_data: Vector3i = related_structure.get_bond(bond_id)
		var selected_array: Array = [is_atom_selected(bond_data.x), is_atom_selected(bond_data.y)]
		_non_selected_bonds_fully_influenced_by_atoms.erase(bond_id)
		_bonds_partially_influenced_by_atoms.erase(bond_id)
		match selected_array:
			[true, true]:
				# both atoms are selected, bond is fully influenced
				if not is_bond_selected(bond_id):
					_non_selected_bonds_fully_influenced_by_atoms[bond_id] = true
			[true, false], [false, true]:
				_bonds_partially_influenced_by_atoms[bond_id] = true
			[false, false]:
				# do nothing
				pass

# # # #
# Snapshots
func get_snapshot() -> Array:
	return [_atoms_selection.duplicate(true),
	_bonds_selection.duplicate(true),
	_bonds_partially_influenced_by_atoms.duplicate(true),
	_non_selected_bonds_fully_influenced_by_atoms.duplicate(true),
	_selection_layers.duplicate(true)]


func apply_snapshot(in_snapshot: Array) -> ApplySnapshotResult:
	var _bonds_partially_influenced_by_atoms_before: Dictionary = _bonds_partially_influenced_by_atoms.duplicate()
	var _non_selected_bonds_fully_influenced_by_atoms_before: Dictionary = _non_selected_bonds_fully_influenced_by_atoms.duplicate()
	
	_atoms_selection = in_snapshot[0].duplicate(true)
	_bonds_selection = in_snapshot[1].duplicate(true)
	_bonds_partially_influenced_by_atoms = in_snapshot[2].duplicate(true)
	_non_selected_bonds_fully_influenced_by_atoms = in_snapshot[3].duplicate(true)
	_selection_layers = in_snapshot[4].duplicate(true)
	_aabb_rebuild_needed = true
	
	var new_partially_influenced_bonds: Dictionary = {}
	for bond: int in _bonds_partially_influenced_by_atoms:
		if not _bonds_partially_influenced_by_atoms_before.has(bond):
			new_partially_influenced_bonds[bond] = true
	
	var bonds_released_from_partial_influence: Dictionary = {}
	for bond: int in _bonds_partially_influenced_by_atoms_before:
		if not _bonds_partially_influenced_by_atoms.has(bond):
			bonds_released_from_partial_influence[bond] = true
	
	return ApplySnapshotResult.new(PackedInt32Array(new_partially_influenced_bonds.keys()),
			PackedInt32Array(bonds_released_from_partial_influence.keys()))


class AtomDeselectionResult:
	var selection_changed: bool = false
	var removed_partially_influenced_bonds: PackedInt32Array;
	var new_partially_influenced_bonds: PackedInt32Array;
	var removed_atoms: PackedInt32Array;
	
	func _init(in_changed: bool,
			in_removed_partially_influenced_bonds: PackedInt32Array,
			in_new_partially_influenced_bonds: PackedInt32Array,
			in_removed_atoms: PackedInt32Array
			) -> void:
		selection_changed = in_changed
		removed_partially_influenced_bonds = in_removed_partially_influenced_bonds
		new_partially_influenced_bonds = in_new_partially_influenced_bonds
		removed_atoms = in_removed_atoms


class AtomSelectionResult:
	var selection_changed: bool
	var new_partially_influenced_bonds: PackedInt32Array
	var removed_partially_influenced_bonds: PackedInt32Array;
	var new_bonds_selected: PackedInt32Array;
	
	func _init(in_changed: bool, in_new_partially_influenced_bonds: PackedInt32Array,
				in_removed_partially_influenced_bonds: PackedInt32Array,
				in_new_bonds_selected: PackedInt32Array) -> void:
		selection_changed = in_changed
		new_partially_influenced_bonds = in_new_partially_influenced_bonds
		removed_partially_influenced_bonds = in_removed_partially_influenced_bonds
		new_bonds_selected = in_new_bonds_selected


class ApplySnapshotResult:
	var bonds_released_from_partial_influence: PackedInt32Array
	var new_partially_influenced_bonds: PackedInt32Array
	
	func _init(in_new_partially_influenced_bonds: PackedInt32Array,
			in_bonds_released_from_partial_influence: PackedInt32Array) -> void:
		new_partially_influenced_bonds = in_new_partially_influenced_bonds
		bonds_released_from_partial_influence = in_bonds_released_from_partial_influence


class SelectionSet:
	var atoms: PackedInt32Array
	var bonds: PackedInt32Array
	
	func _init(in_atoms: PackedInt32Array, in_bonds: PackedInt32Array) -> void:
		atoms = in_atoms
		bonds = in_bonds
	
	func duplicate() -> SelectionSet:
		return SelectionSet.new(atoms.duplicate(), bonds.duplicate())
