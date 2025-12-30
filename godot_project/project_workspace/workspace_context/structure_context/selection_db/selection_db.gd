class_name SelectionDB extends Node
# One api for all selections, responsible for performing operations on selections
# and holding atom selection data (that part is delegated to _atom_selection: AtomSelection object)

signal atom_selection_changed
signal dna_control_points_selection_changed
signal selection_changed
signal atoms_deselected(in_deselected_atoms: PackedInt32Array)
signal dna_control_points_deselected(in_deselected_control_points: PackedInt32Array)
signal virtual_object_selection_changed(is_selected: bool)
signal dna_spline_selection_changed(is_selected: bool)
signal springs_deselected(in_deselected_springs: PackedInt32Array)


var _atom_selection: AtomSelection
var _dna_control_point_selection: Dictionary[int, bool]
var _structure_context: StructureContext
var _spring_selection: SpringSelection

var _application_is_editor_build: bool = OS.has_feature("editor")
var _is_virtual_object_selected: bool = false
var _is_dna_spline_selected: bool = false
var _is_initialized: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_atom_selection = get_node("AtomSelection") as AtomSelection
		_spring_selection = get_node("SpringSelection") as SpringSelection
	if what == NOTIFICATION_READY:
		assert(get_parent() is StructureContext)
		pass


func initialize(in_parent_structure_context: StructureContext) -> void:
	_structure_context = in_parent_structure_context
	_atom_selection.initialize(in_parent_structure_context)
	_spring_selection.initialize(in_parent_structure_context)
	_is_initialized = true


func is_initialized() -> bool:
	return _is_initialized


func has_selection() -> bool:
	if not is_instance_valid(_structure_context.nano_structure):
		# user applied another undo between _update_gizmo.call_deferred() and _update_gizmo call
		return false
	
	return _atom_selection.has_selection() \
			or _is_virtual_object_selected \
			or _is_dna_spline_selected \
			or _spring_selection.has_selection() \
			or _dna_control_point_selection.size() > 0


func has_cached_selection_set() -> bool:
	return _atom_selection.has_cached_selection_set()


func is_any_atom_selected() -> bool:
	return _atom_selection.has_atom_selection()


func are_many_atom_selected() -> bool:
	return _atom_selection.are_many_atom_selected()


func is_any_bond_selected() -> bool:
	return _atom_selection.has_bond_selection()


func is_any_spring_selected() -> bool:
	return _spring_selection.has_selection()


func is_atom_selected(in_atom_id: int) -> bool:
	return _atom_selection.is_atom_selected(in_atom_id)


func is_bond_selected(in_bond_id: int) -> bool:
	return _atom_selection.is_bond_selected(in_bond_id)


func is_spring_selected(in_spring_id: int) -> bool:
	return _spring_selection.is_spring_selected(in_spring_id)


func is_virtual_object_selected() -> bool:
	return _is_virtual_object_selected


func is_dna_spline_selected() -> bool:
	return _is_dna_spline_selected


func get_selected_atoms() -> PackedInt32Array:
	return _atom_selection.get_atoms_selection()


func get_newest_selected_atom_id() -> int:
	return _atom_selection.get_newest_selected_atom_id()


func get_selected_bonds() -> PackedInt32Array:
	return _atom_selection.get_bonds_selection()


func get_selected_springs() -> PackedInt32Array:
	return _spring_selection.get_selection()


func get_bonds_partially_influenced_by_selection() -> PackedInt32Array:
	return _atom_selection.get_bonds_partially_influenced_by_selection()


func select_springs(in_springs_to_select: PackedInt32Array) -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	var new_springs_selected: PackedInt32Array = _spring_selection.select_springs(in_springs_to_select)
	var any_new_spring_selected: bool = not new_springs_selected.is_empty()
	if any_new_spring_selected:
		var rendering: Rendering = _structure_context.get_rendering()
		rendering.highlight_springs(new_springs_selected, nano_structure)
		selection_changed.emit()


func deselect_springs(in_springs_to_deselect: PackedInt32Array) -> bool:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	if in_springs_to_deselect.is_empty():
		return false
	var deselected_springs: PackedInt32Array = PackedInt32Array()
	if _spring_selection.deselect_springs(in_springs_to_deselect, deselected_springs):
		var rendering: Rendering = _structure_context.get_rendering()
		rendering.lowlight_springs(deselected_springs, _structure_context.nano_structure)
		springs_deselected.emit(deselected_springs)
		return true
	return false


func select_atoms(in_atoms_to_select: PackedInt32Array) -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	_validate_atom_selection(in_atoms_to_select)
	var result: AtomSelection.AtomSelectionResult = _atom_selection.select_atoms(in_atoms_to_select)
	if result.selection_changed:
		var rendering: Rendering = _structure_context.get_rendering()
		rendering.highlight_atoms(_atom_selection.get_atoms_selection(), nano_structure, result.new_partially_influenced_bonds,
				result.removed_partially_influenced_bonds)
		atom_selection_changed.emit()
		selection_changed.emit()


func deselect_atoms(in_atoms_to_deselect: PackedInt32Array) -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	if in_atoms_to_deselect.is_empty():
		return
	var result: AtomSelection.AtomDeselectionResult = _atom_selection.deselect_atoms(in_atoms_to_deselect);
	_process_atom_deselection_result(result)


func deselect_bonds(in_bonds_to_deselect: PackedInt32Array) -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	if in_bonds_to_deselect.is_empty():
		return
	var deselection_succesfull: bool = _atom_selection.deselect_bonds(in_bonds_to_deselect)
	if deselection_succesfull:
		var rendering: Rendering = _structure_context.get_rendering()
		rendering.lowlight_bonds(in_bonds_to_deselect, nano_structure)
		selection_changed.emit()


func select_bonds(in_bonds_to_select: PackedInt32Array) -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	var any_bond_selected: bool = _atom_selection.select_bonds(in_bonds_to_select)
	if any_bond_selected:
		var rendering: Rendering = _structure_context.get_rendering()
		rendering.highlight_bonds(in_bonds_to_select, nano_structure)
		selection_changed.emit()


func select_atoms_and_get_auto_selected_bonds(in_atoms_to_select: PackedInt32Array) -> PackedInt32Array:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	var result: AtomSelection.AtomSelectionResult = _atom_selection.select_atoms_and_get_auto_selected_bonds(in_atoms_to_select)
	_process_atom_selection_result(result)
	return result.new_bonds_selected


func select_by_type(types_to_select: PackedInt32Array) -> void:
	var nano_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	if not is_instance_valid(nano_structure):
		# Object is a virtual, nothing to do here
		return
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	var result: AtomSelection.AtomSelectionResult = _atom_selection.select_by_type(types_to_select)
	_process_atom_selection_result(result)


func select_connected(in_show_hidden_objects: bool) -> AtomSelection.AtomSelectionResult:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	var result: AtomSelection.AtomSelectionResult = _atom_selection.select_connected(in_show_hidden_objects)
	_process_atom_selection_result(result)
	return result


func can_grow_selection() -> bool:
	return _atom_selection.can_grow_selection()


func grow_selection() -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	var result: AtomSelection.AtomSelectionResult = _atom_selection.grow_selection()
	_process_atom_selection_result(result)


func shrink_selection() -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	var result: AtomSelection.AtomDeselectionResult = _atom_selection.shrink_selection()
	_process_atom_deselection_result(result)


func clear_bond_selection() -> void:
	if _atom_selection.get_bonds_selection().is_empty():
		return
	var nano_structure: NanoStructure = _structure_context.nano_structure
	var rendering: Rendering = _structure_context.get_rendering()
	rendering.lowlight_bonds(_atom_selection.get_bonds_selection(), nano_structure)
	_atom_selection.clear_bond_selection()
	selection_changed.emit()


func set_bond_selection(in_bonds_to_select: PackedInt32Array) -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	var previous_selection: PackedInt32Array = _atom_selection.get_bonds_selection()
	var rendering: Rendering = _structure_context.get_rendering()
	clear_bond_selection()
	select_bonds(in_bonds_to_select)
	
	rendering.highlight_bonds(in_bonds_to_select, nano_structure)
	
	if previous_selection != _atom_selection.get_bonds_selection():
		selection_changed.emit()


func invert_selection() -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	if nano_structure is AtomicStructure:
		assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
		
		# ---- Atoms ----
		var inverted_atoms: PackedInt32Array = nano_structure.get_visible_atoms()
		inverted_atoms.sort()
		var selected_atoms: PackedInt32Array = get_selected_atoms()
		selected_atoms.sort()
		
		# Avoid nested loops.
		var last_removed_index: int = 0
		for selected_atom in selected_atoms:
			# This is a bit faster than bsearch (Tested on small sample size).
			last_removed_index = inverted_atoms.find(selected_atom, last_removed_index)
			inverted_atoms.remove_at(last_removed_index)
		
		set_atom_selection(inverted_atoms)
		
		# ---- Bonds (Must be after atoms) ----
		var inverted_bonds: PackedInt32Array = nano_structure.get_visible_bonds()
		inverted_bonds.sort()
		var selected_bonds: PackedInt32Array = get_selected_bonds()
		selected_bonds.sort()
		
		last_removed_index = 0
		for selected_bond in selected_bonds:
			last_removed_index = inverted_bonds.find(selected_bond, last_removed_index)
			inverted_bonds.remove_at(last_removed_index)
		
		set_bond_selection(inverted_bonds)
		
		# ---- Springs ----
		var visible_springs: PackedInt32Array = nano_structure.springs_get_visible()
		var springs_to_select: PackedInt32Array = PackedInt32Array()
		for spring_id: int in visible_springs:
			if not _spring_selection.is_spring_selected(spring_id):
				springs_to_select.append(spring_id)
		set_spring_selection(springs_to_select)
	
	# ---- DNA Structures ----
	if nano_structure is DnaStructure and nano_structure.get_edit_mode() == DnaStructure.EditMode.SequenceAndPath:
		if _structure_context.workspace_context.get_edited_dna_spline_id() == nano_structure.int_guid:
			var dna_structure := nano_structure as DnaStructure
			var all_points := PackedInt32Array(range(dna_structure.get_control_point_count()))
			var selected_points: PackedInt32Array = _structure_context.get_selected_dna_spline_countrol_points()
			var new_selection: Array = all_points.duplicate()
			for p in selected_points:
				new_selection.erase(p)
			set_dna_control_point_selection(PackedInt32Array(new_selection))
		else:
			set_dna_spline_selected(!is_dna_spline_selected())
	
	# ---- Virtual Objects ----
	if nano_structure.is_virtual_object():
		set_virtual_object_selected(!is_virtual_object_selected())


func select_all() -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	if nano_structure.is_virtual_object():
		set_virtual_object_selected(true)
	elif  nano_structure is DnaStructure and nano_structure.get_edit_mode() == DnaStructure.EditMode.SequenceAndPath:
		set_dna_spline_selected(true)
		if _structure_context.workspace_context.get_edited_dna_spline_id() == _structure_context.get_int_guid():
			set_dna_control_point_selection(range(nano_structure.get_control_point_count()))
	else:
		assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
		set_atom_selection(nano_structure.get_visible_atoms())
		set_bond_selection(nano_structure.get_visible_bonds())
		set_spring_selection(nano_structure.springs_get_visible())


func set_atom_selection(in_atoms_to_select: PackedInt32Array) -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	assert(!nano_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	_validate_atom_selection(in_atoms_to_select)
	
	var partial_influence_bonds_before: Dictionary = _atom_selection.get_bonds_partially_influenced_by_selection_as_dict()
	var full_influence_bonds_before: Dictionary = _atom_selection.get_non_selected_bonds_fully_influenced_by_selection_as_dict()
	var previous_selection: PackedInt32Array = _atom_selection.get_atoms_selection()
	_atom_selection.clear_atom_selection()
	_atom_selection.select_atoms(in_atoms_to_select)
	
	var deselected_atoms: PackedInt32Array = PackedInt32Array()
	for previously_selected_atom_id in previous_selection:
		var is_valid_deselection: bool = not _atom_selection.is_atom_selected(previously_selected_atom_id) and \
			nano_structure.is_atom_valid(previously_selected_atom_id)
		if is_valid_deselection:
			deselected_atoms.append(previously_selected_atom_id)
	
	var rendering: Rendering = _structure_context.get_rendering()
	var bonds_influenced_by_selection_change: Dictionary = _atom_selection.get_bonds_partially_influenced_by_selection_as_dict()
	bonds_influenced_by_selection_change.merge(partial_influence_bonds_before)
	bonds_influenced_by_selection_change.merge(full_influence_bonds_before)
	rendering.refresh_bond_influence(bonds_influenced_by_selection_change.keys(), nano_structure)
	rendering.highlight_atoms(_atom_selection.get_atoms_selection(), nano_structure, PackedInt32Array(), PackedInt32Array())
	if not deselected_atoms.is_empty():
		rendering.lowlight_atoms(deselected_atoms, nano_structure, PackedInt32Array(), PackedInt32Array())
		atoms_deselected.emit(deselected_atoms)
	if previous_selection != _atom_selection.get_atoms_selection():
		atom_selection_changed.emit()
		selection_changed.emit()


func set_virtual_object_selected(in_selected: bool) -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	if in_selected == _is_virtual_object_selected || not nano_structure.is_virtual_object():
		return
	assert(nano_structure.get_visible(), "Cannot change selection of a hidden object")
	_is_virtual_object_selected = in_selected
	virtual_object_selection_changed.emit(in_selected)


func set_dna_spline_selected(in_selected: bool) -> void:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	if in_selected == _is_dna_spline_selected || not nano_structure is DnaStructure:
		return
	assert(nano_structure.get_visible(), "Cannot change selection of a hidden object")
	_is_dna_spline_selected = in_selected
	dna_spline_selection_changed.emit(in_selected)


func set_dna_control_point_selection(in_control_points_to_select: PackedInt32Array) -> void:
	var dna_structure: DnaStructure = _structure_context.nano_structure as DnaStructure
	assert(dna_structure.get_edit_mode() == DnaStructure.EditMode.SequenceAndPath, "Invalid edit mdoe for this operation")
	assert(!dna_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	_validate_dna_control_point_selection(in_control_points_to_select)
	
	var previous_selection := PackedInt32Array(_dna_control_point_selection.keys())
	_dna_control_point_selection = {}
	for p in in_control_points_to_select:
		_dna_control_point_selection[p] = true
	
	var deselected_control_points: PackedInt32Array = PackedInt32Array()
	for prev_control_point in previous_selection:
		var is_valid_deselection: bool = _dna_control_point_selection.get(prev_control_point, false) == false \
			and dna_structure.is_control_point_valid(prev_control_point)
		if is_valid_deselection:
			deselected_control_points.append(prev_control_point)
	
	var rendering: Rendering = _structure_context.get_rendering()
	rendering.highlight_dna_control_points(_dna_control_point_selection.keys(), dna_structure)
	if not deselected_control_points.is_empty():
		rendering.lowlight_dna_control_points(deselected_control_points, dna_structure)
		dna_control_points_deselected.emit(deselected_control_points)
	if previous_selection != PackedInt32Array(_dna_control_point_selection.keys()):
		dna_control_points_selection_changed.emit()
		selection_changed.emit()


func select_dna_control_points(in_control_points: PackedInt32Array) -> void:
	var dna_structure: DnaStructure = _structure_context.nano_structure as DnaStructure
	_validate_dna_control_point_selection(in_control_points)
	var changed: bool = false
	for p: int in in_control_points:
		changed = changed or _dna_control_point_selection.get(p, false) == false
		_dna_control_point_selection[p] = true
	if changed:
		var rendering: Rendering = _structure_context.get_rendering()
		rendering.highlight_dna_control_points(in_control_points, dna_structure)
		dna_control_points_selection_changed.emit()
		selection_changed.emit()


func deselect_dna_control_points(in_control_points: PackedInt32Array) -> void:
	var dna_structure: DnaStructure = _structure_context.nano_structure as DnaStructure
	assert(!dna_structure.is_being_edited(), "Setting the selection while structure is changing is insecure and should be avoided")
	if in_control_points.is_empty():
		return
	var deselected_points: PackedInt32Array = []
	for p: int in in_control_points:
		if _dna_control_point_selection.has(p):
			deselected_points.append(p)
			_dna_control_point_selection.erase(p)
	if not deselected_points.is_empty():
		var rendering: Rendering = _structure_context.get_rendering()
		rendering.lowlight_dna_control_points(deselected_points, dna_structure)
		dna_control_points_deselected.emit(deselected_points)
		dna_control_points_selection_changed.emit()
		selection_changed.emit()


func get_selected_dna_spline_countrol_points() -> PackedInt32Array:
	return _dna_control_point_selection.keys()


func set_spring_selection(in_springs_to_select: PackedInt32Array) -> void:
	var previous_selection: PackedInt32Array = _spring_selection.get_selection()
	_spring_selection.clear_selection()
	_spring_selection.select_springs(in_springs_to_select)
	var deselected_springs: PackedInt32Array = PackedInt32Array()
	for previously_selected_spring_id: int in previous_selection:
		var is_valid_deselection: bool = not _spring_selection.is_spring_selected(previously_selected_spring_id)
		if is_valid_deselection:
			deselected_springs.append(previously_selected_spring_id)
	
	var nano_structure: NanoStructure = _structure_context.nano_structure
	var rendering: Rendering = _structure_context.get_rendering()
	rendering.lowlight_springs(deselected_springs, nano_structure)
	rendering.highlight_springs(in_springs_to_select, nano_structure)
	springs_deselected.emit(deselected_springs)
	if previous_selection != _spring_selection.get_selection():
		selection_changed.emit()


func clear_selection() -> void:
	if not has_selection():
		return
	
	var nano_structure: NanoStructure = _structure_context.nano_structure
	var deselected_atoms: PackedInt32Array = _atom_selection.get_atoms_selection().duplicate()
	var bonds_selection_to_lowlight: PackedInt32Array = _atom_selection.get_bonds_selection()
	var bonds_released_from_partial_influence: PackedInt32Array = _atom_selection.get_bonds_partially_influenced_by_selection()
	var bonds_released_from_full_influence: PackedInt32Array = _atom_selection.get_non_selected_bonds_fully_influenced_by_selection()
	var dna_control_points_to_lowlight: PackedInt32Array = _dna_control_point_selection.keys()
	var spring_selection_to_lowlight: PackedInt32Array = _spring_selection.get_spring_selection()
	
	_atom_selection.clear_atom_selection()
	_atom_selection.clear_bond_selection()
	_spring_selection.clear_selection()
	_dna_control_point_selection.clear()
	
	var rendering: Rendering = _structure_context.get_rendering()
	set_virtual_object_selected(false)
	set_dna_spline_selected(false)
	
	if nano_structure is AtomicStructure:
		rendering.lowlight_atoms(deselected_atoms, nano_structure, bonds_released_from_partial_influence,
				PackedInt32Array())
		rendering.lowlight_bonds(bonds_selection_to_lowlight, nano_structure)
		rendering.refresh_bond_influence(bonds_released_from_full_influence, nano_structure)
		rendering.lowlight_springs(spring_selection_to_lowlight, nano_structure)
		
		atoms_deselected.emit(deselected_atoms)
		atom_selection_changed.emit()
	if not dna_control_points_to_lowlight.is_empty():
		rendering.lowlight_dna_control_points(dna_control_points_to_lowlight, nano_structure)
		dna_control_points_deselected.emit(dna_control_points_to_lowlight)
	selection_changed.emit()


func get_selection_aabb() -> AABB:
	assert(has_selection(), "Can't get selection AABB if structure has no selection")
	var selections_aabbs: Array[AABB] = []
	var nano_structure: NanoStructure = _structure_context.nano_structure
	if is_virtual_object_selected():
		var object_aabb: AABB = nano_structure.get_aabb()
		selections_aabbs.push_back(object_aabb)
	
	if _structure_context.workspace_context.get_edited_dna_spline_id() == nano_structure.int_guid:
		if not _dna_control_point_selection.is_empty():
			var dna_structure := _structure_context.nano_structure as DnaStructure
			var points: PackedInt32Array = _dna_control_point_selection.keys()
			var aabb := AABB(dna_structure.get_control_point_position(points[0]), Vector3.ZERO)
			for i in range(1, points.size()):
				aabb = aabb.expand(dna_structure.get_control_point_position(points[i]))
			selections_aabbs.push_back(aabb)
		else:
			assert(is_dna_spline_selected())
			selections_aabbs.push_back(nano_structure.get_aabb())
	elif is_dna_spline_selected():
		selections_aabbs.push_back(nano_structure.get_aabb())
		
	
	if _atom_selection.has_selection():
		selections_aabbs.push_back(_atom_selection.get_aabb())
	
	if _spring_selection.has_selection():
		selections_aabbs.push_back(_spring_selection.get_aabb())
	
	var aabb: AABB = selections_aabbs.pop_back()
	while selections_aabbs.size():
		var other_aabb: AABB = selections_aabbs.pop_back()
		aabb = aabb.merge(other_aabb)
	return aabb


func _validate_atom_selection(in_atoms_to_select: PackedInt32Array) -> void:
	# This check is very intensive, so it is meant to be skipped on release
	if _application_is_editor_build:
		var nano_structure: NanoStructure = _structure_context.nano_structure
		for atom_id in in_atoms_to_select:
			assert(nano_structure.is_atom_valid(atom_id), "Cannot set selection to an invalid atom")
			pass


func _validate_dna_control_point_selection(in_control_points: PackedInt32Array) -> void:
	# This check is very intensive, so it is meant to be skipped on release
	if _application_is_editor_build:
		var dna_structure: DnaStructure = _structure_context.nano_structure as DnaStructure
		for p in in_control_points:
			assert(dna_structure.is_control_point_valid(p), "Cannot set selection to an invalid control point")
			pass


func _process_atom_selection_result(result: AtomSelection.AtomSelectionResult) -> void:
	if result.selection_changed:
		var nano_structure: NanoStructure = _structure_context.nano_structure
		var rendering: Rendering = _structure_context.get_rendering()
		rendering.highlight_atoms(_atom_selection.get_atoms_selection(), nano_structure,
				result.new_partially_influenced_bonds, result.removed_partially_influenced_bonds)
		rendering.highlight_bonds(_atom_selection.get_bonds_selection(), nano_structure)
		atom_selection_changed.emit()
		selection_changed.emit()


func _process_atom_deselection_result(result: AtomSelection.AtomDeselectionResult) -> void:
	if result.selection_changed:
		var nano_structure: NanoStructure = _structure_context.nano_structure
		var rendering: Rendering = _structure_context.get_rendering()
		rendering.lowlight_atoms(result.removed_atoms, nano_structure,
				result.removed_partially_influenced_bonds, result.new_partially_influenced_bonds)
		# Bonds no longer partially influenced might still be explicitely selected, don't lowlight these.
		var bonds_to_lowlight: PackedInt32Array = PackedInt32Array()
		for bond_id: int in result.removed_partially_influenced_bonds:
			if not is_bond_selected(bond_id):
				bonds_to_lowlight.push_back(bond_id)
		rendering.lowlight_bonds(bonds_to_lowlight, nano_structure)
		
		atoms_deselected.emit(result.removed_atoms)
		atom_selection_changed.emit()
		selection_changed.emit()


func get_selection_snapshot() -> Dictionary:
	var result_data: Dictionary = {
		atom_snapshot = _atom_selection.get_snapshot(),
		spring_snapshot = _spring_selection.get_snapshot(),
		is_virtual_object_selected = _is_virtual_object_selected,
		is_dna_spline_selected = _is_dna_spline_selected,
		dna_control_points_snapshot = _dna_control_point_selection.duplicate()
	}
	return result_data


func apply_selection_snapshot(in_snapshot: Dictionary) -> void:
	_is_virtual_object_selected = in_snapshot.is_virtual_object_selected
	_is_dna_spline_selected = in_snapshot.is_dna_spline_selected
	_dna_control_point_selection = in_snapshot.dna_control_points_snapshot.duplicate()
	var atom_snapshot: Array = in_snapshot.atom_snapshot
	var spring_snapshot: Array = in_snapshot.spring_snapshot
	var _apply_result: AtomSelection.ApplySnapshotResult = _atom_selection.apply_snapshot(atom_snapshot)
	_spring_selection.apply_snapshot(spring_snapshot)
