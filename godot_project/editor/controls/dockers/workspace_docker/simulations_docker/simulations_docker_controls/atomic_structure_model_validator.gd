class_name AtomicStructureModelValidator extends Node


signal results_outdated()
signal validation_finished(found_overlaps: bool)
signal alert_selected(has_invisible_atoms: bool)


const COLOR_DELETED: Color = Color.WEB_GRAY
const DELETED_ICON: Texture2D = preload("res://editor/controls/menu_bar/menu_edit/icons/icon_delete.svg")
const MAX_COVALENT_RADIUS: float = 0.232
const MAX_SHAKE_ITERATIONS: int = 5


var _thread: Thread
var _overlaps: Dictionary = {
#	overlap_data<OverlapData> = tree_item<TreeItem>
}
var _tree_items: Dictionary = {
#	tree_item<TreeItem> = true<bool>
}


var _workspace_context: WorkspaceContext = null
var _overlaps_are_fixed: bool = false


func set_workspace_context(in_workspace_context: WorkspaceContext) -> void:
	assert(not is_instance_valid(_workspace_context), "Already initialized")
	_workspace_context = in_workspace_context
	in_workspace_context.structure_contents_changed.connect(_on_workspace_context_structure_contents_changed)
	in_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
	in_workspace_context.history_changed.connect(_on_history_changed)


func _on_history_changed() -> void:
	_update_state_of_tree_items()


func _validate_bonds_in_thread(
		in_visible_structure_contexts: Array[StructureContext],
		out_promise: Promise,
		in_selection_only: bool) -> void:
	var validation_results: Array[Metadata] = []
	for structure_context: StructureContext in in_visible_structure_contexts:
		if not structure_context.nano_structure is AtomicStructure:
			continue
		var atomic_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
		var ignored_springs: Array[Metadata] = []
		var spatial_hash_grid: SpatialHashGrid = SpatialHashGrid.new(MAX_COVALENT_RADIUS)
		var atoms: PackedInt32Array
		if in_selection_only:
			atoms = structure_context.get_selected_atoms()
		else:
			atoms = atomic_structure.get_visible_atoms()
		
		for atom_id: int in atoms:
			var atom_data: AtomData = AtomData.new(atom_id, structure_context)
			if atom_data.has_invalid_bonds():
				validation_results.push_back(atom_data)
			spatial_hash_grid.add_atom(atom_data)
			
			# Collect Ignored Springs:
			# Springs hooked to atoms that are locked in position will be ignored
			if atomic_structure.atom_is_locked(atom_id):
				var atom_springs: PackedInt32Array = atomic_structure.atom_get_springs(atom_id)
				if not atom_springs.is_empty():
					var ignored_springs_data := IgnoredSpring.new(atom_id, atom_springs, structure_context)
					ignored_springs.push_back(ignored_springs_data)
		
		validation_results.append_array(spatial_hash_grid.get_overlaps())
		validation_results.append_array(ignored_springs)
		
	
	var drastically_bad_sp3_groups: Array[Dictionary] = WorkspaceUtils.collect_drastically_invalid_tetrahedral_structure(
		in_visible_structure_contexts, in_selection_only)
	
	for group: Dictionary in drastically_bad_sp3_groups:
		var bad_bond_angle_data := DrasticSp3Data.new(group.atoms_ids, group.bond_ids, group.structure_context)
		validation_results.append(bad_bond_angle_data)
	
	var bad_bond_angles_groups: Array[Dictionary] = WorkspaceUtils.collect_invalid_bond_angles(
		in_visible_structure_contexts, in_selection_only)
	
	for group: Dictionary in bad_bond_angles_groups:
		var bad_bond_angle_data := InvalidSp123Data.new(group.type, group.atoms_ids, group.bond_ids, group.structure_context)
		validation_results.append(bad_bond_angle_data)
	
	out_promise.fulfill.bind(validation_results).call_deferred()


func validate_atomic_model(in_selection_only: bool) -> void:
	if _thread and _thread.is_alive():
		return
	var promise: Promise = Promise.new()
	_thread = Thread.new()
	_thread.start(_validate_bonds_in_thread.bind(_workspace_context.get_visible_structure_contexts(), promise, in_selection_only))
	
	_workspace_context.start_async_work(_workspace_context.tr("Validating bonds ..."))
	await promise.wait_for_fulfill()
	_thread.wait_to_finish()
	_workspace_context.end_async_work()
	assert(not promise.has_error())
	
	var validation_results: Array[Metadata] = promise.get_result()
	_overlaps.clear()
	_tree_items.clear()
	_overlaps_are_fixed = false
	
	for metadata: Metadata in validation_results:
		var item: TreeItem
		if metadata.alert_level == Metadata.AlertLevel.WARNING:
			item = _workspace_context.push_warning_alert(metadata.text, _on_tree_item_selected, _on_tree_item_selected.bind(true))
		else:
			item = _workspace_context.push_error_alert(metadata.text, _on_tree_item_selected, _on_tree_item_selected.bind(true))
		_tree_items[item] = true
		item.set_metadata(0, metadata)
		if metadata is OverlapData:
			_overlaps[metadata] = item
	
	validation_finished.emit(not _overlaps.is_empty())


## Returns true if there's at least one valid overlap data
func has_overlapping_atoms() -> bool:
	for overlap_data: OverlapData in _overlaps:
		# If the tree item was deleted, the overlap isn't valid anymore
		var tree_item: Variant = _overlaps[overlap_data]
		if not is_instance_valid(tree_item):
			continue
		if not overlap_data.has_invalid_atoms():
			return true
	return false


func fix_overlapping_atoms() -> void:
	
	for overlap: OverlapData in _overlaps:
		if overlap.is_fixed:
			continue
		var nano_structure: NanoStructure = overlap.structure_context.nano_structure
		if not nano_structure.is_being_edited():
			nano_structure.start_edit()
		
			var original_atoms: PackedInt32Array = nano_structure.get_visible_atoms()
			var original_positions: PackedVector3Array = PackedVector3Array()
			for original_atom_id: int in original_atoms:
				original_positions.push_back(nano_structure.atom_get_position(original_atom_id))
		
		# Store the atoms positions a small random offset to prevent two atoms having
		# the exact same coordinates
		var atoms_positions: Dictionary = {
			# atom_id<int>: position<Vector3>
		}
		for atom_id in overlap.atoms_id:
			if not nano_structure.is_atom_valid(atom_id):
				# atom was deleted after overlaps was validated
				continue
			var atom_position: Vector3 = nano_structure.atom_get_position(atom_id)
			var random_dir: Vector3 = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.01
			atoms_positions[atom_id] = atom_position + random_dir
		
		# Relax the atoms positions.
		# For each atom, find the nearest atom and move away. Repeat up to MAX_SHAKE_ITERATIONS
		var move_offset: float = MAX_COVALENT_RADIUS * 0.25
		var max_separation_distance_squared: float = pow(MAX_COVALENT_RADIUS, 2.0)
		for iteration: int in MAX_SHAKE_ITERATIONS:
			var atoms_were_moved: bool = false
			for atom_id: int in atoms_positions:
				var dir := Vector3.ONE * 99999.0
				var min_distance := 99999.0

				# Find the closest atom
				for other_atom_id: int in atoms_positions:
					if atom_id == other_atom_id:
						continue
					var diff: Vector3 = atoms_positions[atom_id] - atoms_positions[other_atom_id]
					var distance: float = diff.length_squared()
					if distance < min_distance:
						dir = diff
						min_distance = distance
				
				if min_distance > max_separation_distance_squared:
					continue # Atom already far enough
				
				atoms_positions[atom_id] += dir.normalized() * move_offset
				atoms_were_moved = true
			
			if not atoms_were_moved:
				break # Atoms are no longer overlapping
			else:
				move_offset *= 0.75 # Make the next iteration less pronounced

		# Apply the new atoms positions
		var atoms_id: PackedInt32Array = PackedInt32Array(atoms_positions.keys())
		var new_positions: PackedVector3Array = PackedVector3Array(atoms_positions.values())
		nano_structure.atoms_set_positions(atoms_id, new_positions)
		
		# Gray out the tree item for this overlap
		var item: TreeItem = _overlaps[overlap]
		var prefix: String = item.get_text(0).substr(0, 2) # This is the warning or error unicode character
		item.set_text(0, prefix + "(Fixed) " + item.get_text(0))
		item.set_custom_color(0, COLOR_DELETED)
		item.set_icon_modulate(0, COLOR_DELETED)
		overlap.is_fixed = true

	for overlap: OverlapData in _overlaps:
		var nano_structure: NanoStructure = overlap.structure_context.nano_structure
		if nano_structure.is_being_edited():
			nano_structure.end_edit()
	
	_overlaps_are_fixed = true
	_workspace_context.snapshot_moment("Fix Overlapping Atoms Errors")


func _on_tree_item_selected(in_selected_item: TreeItem, show_hidden: bool = false) -> void:
	var metadata: Metadata = in_selected_item.get_metadata(0)
	if not metadata or metadata.has_invalid_atoms():
		alert_selected.emit(false)
		return
	
	var atom_selection: PackedInt32Array = PackedInt32Array()
	var spring_selection: PackedInt32Array = PackedInt32Array()
	if metadata is AtomData:
		atom_selection.push_back(metadata.id)
	elif metadata is OverlapData:
		atom_selection = metadata.atoms_id
	elif metadata is InvalidSp123Data or metadata is DrasticSp3Data:
		atom_selection = metadata.atom_ids
	elif metadata is IgnoredSpring:
		atom_selection = metadata.atoms_id
		spring_selection = metadata.spring_ids
	
	var structure_context: StructureContext = metadata.structure_context
	var atomic_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
	var visible_atom_selection: PackedInt32Array = PackedInt32Array()
	var visible_spring_selection: PackedInt32Array = PackedInt32Array()
	var has_hidden_hydrogens: bool = false
	for atom_id: int in atom_selection:
		if atomic_structure.is_atom_visible(atom_id):
			visible_atom_selection.push_back(atom_id)
			continue
		if has_hidden_hydrogens or _workspace_context.are_hydrogens_visualized():
			continue
		if atomic_structure.atom_get_atomic_number(atom_id) == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
			has_hidden_hydrogens = true
	for spring_id: int in spring_selection:
		if atomic_structure.spring_is_visible(spring_id):
			visible_spring_selection.push_back(spring_id)
			continue
		if has_hidden_hydrogens or _workspace_context.are_hydrogens_visualized():
			continue
		var atom_id: int = atomic_structure.spring_get_atom_id(spring_id)
		if atomic_structure.atom_get_atomic_number(atom_id) == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
			has_hidden_hydrogens = true
	
	var has_hidden_atoms: bool = atom_selection.size() != visible_atom_selection.size()
	var has_hidden_springs: bool = spring_selection.size() != visible_spring_selection.size()
	alert_selected.emit(has_hidden_atoms and not show_hidden)

	if structure_context != _workspace_context.get_current_structure_context():
		_workspace_context.change_current_structure_context(structure_context)
	for context in _workspace_context.get_editable_structure_contexts():
		context.clear_selection()
	
	if (has_hidden_atoms or has_hidden_springs) and show_hidden:
		atomic_structure.set_atoms_visibility(atom_selection, true)
		if has_hidden_springs:
			# Also make related anchors visible if necesary
			var related_anchor_ids: Dictionary = {
			#	anchor_id<int> = true
			}
			for spring: int in spring_selection:
				related_anchor_ids[atomic_structure.spring_get_anchor_id(spring)] = true
			for anchor_id: int in related_anchor_ids.keys():
				var anchor_context: StructureContext = _workspace_context.get_nano_structure_context_from_id(anchor_id)
				if not anchor_context.nano_structure.visible:
					anchor_context.nano_structure.visible = true
			atomic_structure.set_springs_visibility(spring_selection, true)
		if has_hidden_hydrogens:
			_workspace_context.enable_hydrogens_visualization(false)
		visible_atom_selection = atom_selection
		visible_spring_selection = spring_selection
	
	if not visible_atom_selection.is_empty():
		structure_context.select_atoms_and_get_auto_selected_bonds(visible_atom_selection)
	
	if not visible_spring_selection.is_empty():
		structure_context.select_springs(visible_spring_selection)
	
	if visible_atom_selection.size() + visible_spring_selection.size():
		var focus_aabb: AABB = WorkspaceUtils.get_selected_objects_aabb(_workspace_context)
		WorkspaceUtils.focus_camera_on_aabb(_workspace_context, focus_aabb)
	
	_workspace_context.snapshot_moment("Select Atoms")


func _on_workspace_context_structure_contents_changed(_structure: StructureContext) -> void:
	ScriptUtils.call_deferred_once(_update_state_of_tree_items)


func _on_workspace_context_structure_about_to_remove(_in_struct: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_update_state_of_tree_items)


func _update_state_of_tree_items() -> void:
	var is_outdated: bool = false
	# The tree item may have been freed
	# because of this we cast it to Variant first to avoid errors
	for v_item: Variant in _tree_items.keys():
		if not is_instance_valid(v_item):
			continue
		var item := v_item as TreeItem
		var prefix: String = item.get_text(0).substr(0, 2) # This is the warning or error unicode character
		var metadata: Metadata = item.get_metadata(0)
		if metadata.has_invalid_atoms():
			is_outdated = true
			item.set_icon(0, DELETED_ICON)
			item.set_text(0, prefix + "(Deleted) " + metadata.text)
			item.set_custom_color(0, COLOR_DELETED)
			item.set_icon_modulate(0, COLOR_DELETED)
			item.set_selectable(0, false)
			item.deselect(0)
		elif metadata is OverlapData and metadata.is_fixed:
			# Gray out the tree item for this overlap
			item.set_text(0, prefix + "(Fixed) " + metadata.text)
			item.set_custom_color(0, COLOR_DELETED)
			item.set_icon_modulate(0, COLOR_DELETED)
		else:
			item.set_icon(0, null)
			item.set_text(0, prefix + metadata.text)
			item.clear_custom_color(0)
			item.set_selectable(0, true)
	if is_outdated:
		results_outdated.emit()


func show_hidden_atoms(in_selected_alert: TreeItem) -> void:
	if in_selected_alert:
		_on_tree_item_selected(in_selected_alert, true)


class Metadata:
	enum AlertLevel {
		WARNING,
		ERROR
	}
	var alert_level: AlertLevel = AlertLevel.WARNING
	var text: String
	
	func has_invalid_atoms() -> bool:
		return true


class AtomData extends Metadata:
	var id: int
	var name: String
	var structure_context: StructureContext
	var current_bond_count: int
	var expected_bond_count: int
	var covalent_radius: float
	
	func _init(in_id: int, in_structure_context: StructureContext) -> void:
		id = in_id
		structure_context = in_structure_context
		
		var nano_structure: NanoStructure = structure_context.nano_structure
		var bonds: PackedInt32Array = nano_structure.atom_get_bonds(id)
		var atomic_number: int = nano_structure.atom_get_atomic_number(id)
		var element_data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
		name = element_data.name
		covalent_radius = element_data.covalent_radius[1]
		
		# Count existing bonds for atom_id
		for bond_id in bonds:
			var order: int = nano_structure.get_bond(bond_id).z
			assert(order > 0, "Invalid bond order")
			current_bond_count += order
		
		# Calculate expected bonds count
		var valence: int = element_data.valence
		if element_data.number <= 5:
			# Special case for elements close to Helium
			expected_bond_count = (2 - valence)
		elif valence < 4:
			expected_bond_count = abs(valence)
		else:
			expected_bond_count = abs(valence - 8)
		
		if has_invalid_bonds():
			text = "%s %s. Has %d covalent bond%s, but should have %d." % [
			name,
			"has too many bonds" if current_bond_count > expected_bond_count else "has too few bonds",
			current_bond_count,
			"s" if current_bond_count != 1 else "",
			expected_bond_count
			]
		else:
			text = ""
	
	func has_invalid_atoms() -> bool:
		if not is_instance_valid(structure_context) or not structure_context.is_inside_workspace():
			return true
		return not structure_context.nano_structure.is_atom_valid(id)
	
	func has_invalid_bonds() -> bool:
		return current_bond_count != expected_bond_count
	
	func get_position() -> Vector3:
		return structure_context.nano_structure.atom_get_position(id)


class OverlapData extends Metadata:
	var atoms_id: PackedInt32Array
	var structure_context: StructureContext
	var is_fixed: bool = false
	
	func _init(in_atoms: Array[AtomData], in_structure_context: StructureContext) -> void:
		structure_context = in_structure_context
		atoms_id = PackedInt32Array()
		var map: Dictionary = {
			# Element name <String> : Atoms count <int>
		}
		for atom: AtomData in in_atoms:
			atoms_id.push_back(atom.id)
			if not map.has(atom.name):
				map[atom.name] = 0
			map[atom.name] += 1
		# Format the string based on how many atoms are overlapping
		# ex: "1 Carbon, 1 Hydrogen and 2 Oxygens are overlapping"
		var delimiter: String = ", "
		var index: int = 0
		for element: String in map:
			var count: int = map[element]
			if index == map.size() - 2:
				delimiter = " and "
			elif index == map.size() - 1:
				delimiter = ""
			text += "%d %s%s%s" % [count, element, "s" if count != 1 else "", delimiter]
			index += 1
		text += " are overlapping."
	
	func has_invalid_atoms() -> bool:
		if not is_instance_valid(structure_context) or not structure_context.is_inside_workspace():
			return true
		for atom: int in atoms_id:
			if not structure_context.nano_structure.is_atom_valid(atom):
				return true
		return false


class IgnoredSpring extends Metadata:
	var atoms_id: PackedInt32Array
	var spring_ids: PackedInt32Array
	var structure_context: StructureContext
	
	func _init(in_atom_id: int, in_atom_springs: PackedInt32Array, in_structure_context: StructureContext) -> void:
		structure_context = in_structure_context
		atoms_id = [in_atom_id]
		var atomic_number: int = in_structure_context.nano_structure.atom_get_atomic_number(in_atom_id)
		var symbol: String = PeriodicTable.get_by_atomic_number(atomic_number).symbol
		spring_ids = in_atom_springs
		var message: String = tr_n(
			&"Spring attached to Locked {0} atom will be ignored during simulaitons",
			&"Springs attached to Locked {0} atom will be ignored during simulations", in_atom_springs.size())
		text += message.format([symbol])


	func has_invalid_atoms() -> bool:
		if not is_instance_valid(structure_context) or not structure_context.is_inside_workspace():
			return true
		var atomic_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
		for atom: int in atoms_id:
			if not atomic_structure.is_atom_valid(atom):
				return true
		for spring: int in spring_ids:
			if not atomic_structure.spring_has(spring):
				return true
		return false


class DrasticSp3Data extends Metadata:
	var atom_ids: PackedInt32Array
	var bond_ids: PackedInt32Array
	var structure_context: StructureContext
	
	func _init(in_atom_ids: PackedInt32Array, in_bond_ids: PackedInt32Array,
			in_structure_context: StructureContext) -> void:
		alert_level = AlertLevel.ERROR
		atom_ids = in_atom_ids
		bond_ids = in_bond_ids
		structure_context = in_structure_context
		var element_symbols: Array = Array(atom_ids).map(
			func(atom_id: int) -> String:
				var atomic_number: int = in_structure_context.nano_structure.atom_get_atomic_number(atom_id)
				var atomic_symbol: String = PeriodicTable.get_by_atomic_number(atomic_number).symbol
				return atomic_symbol
		)
		assert(element_symbols.size() == 5)
		text = tr("Incorrect Tetrahedral Bond Angles in structure: {0}({1})({2})({3})({4})"
				).format(element_symbols)
	
	func has_invalid_atoms() -> bool:
		if not is_instance_valid(structure_context) or not structure_context.is_inside_workspace():
			return true
		for bond_id: int in bond_ids:
			if not structure_context.nano_structure.is_bond_valid(bond_id):
				return true
		for atom: int in atom_ids:
			if not structure_context.nano_structure.is_atom_valid(atom):
				return true
		return false


class InvalidSp123Data extends Metadata:
	var atom_ids: PackedInt32Array
	var bond_ids: PackedInt32Array
	var structure_context: StructureContext
	
	func _init(in_sp_type: StringName, in_atom_ids: PackedInt32Array, in_bond_ids: PackedInt32Array,
			in_structure_context: StructureContext) -> void:
		assert(in_sp_type in [&"sp1", &"sp2", &"sp3"], "Unexpected sp distribution: '%s'" % in_sp_type)
		atom_ids = in_atom_ids
		bond_ids = in_bond_ids
		structure_context = in_structure_context
		var element_symbols: Array = Array(atom_ids).map(
			func(atom_id: int) -> String:
				var atomic_number: int = in_structure_context.nano_structure.atom_get_atomic_number(atom_id)
				var atomic_symbol: String = PeriodicTable.get_by_atomic_number(atomic_number).symbol
				return atomic_symbol
		)
		assert(element_symbols.size() == in_atom_ids.size())
		const MESSAGE_PER_SP_TYPE: Dictionary = {
			sp1 = "Lineal (sp1) Bond Angles out of range: {0}({1})({2})",
			sp2 = "Planar (sp2) Bond Angles out of range: {0}({1})({2})({3})",
			sp3 = "Tetrahedral (sp3) Bond Angles out of range: {0}({1})({2})({3})({4})",
		}
		text = tr(MESSAGE_PER_SP_TYPE[in_sp_type]).format(element_symbols)
	
	func has_invalid_atoms() -> bool:
		if not is_instance_valid(structure_context) or not structure_context.is_inside_workspace():
			return true
		for bond_id: int in bond_ids:
			if not structure_context.nano_structure.is_bond_valid(bond_id):
				return true
		for atom: int in atom_ids:
			if not structure_context.nano_structure.is_atom_valid(atom):
				return true
		return false


## The spatial hash grid is used to partition the atoms in a 3D grid and speed
## up the overlap calculations.
##
## When adding an atom, the atom position is snapped to the nearest _cell_size
## to get its parent cell id before adding the atom to the _grid.
## When querying for nearby atoms, we check all 8 surrounding cells (if they exists)
## and only calculate the distance to the atoms within these cells, instead of
## using the entire set.
class SpatialHashGrid:
	var _grid: Dictionary = {
		# cell_id <Vector3> : atoms <Array[AtomData]>
	}
	var _cell_size: float

	func _init(min_distance: float) -> void:
		_cell_size = min_distance

	func add_atom(atom: AtomData) -> void:
		var cell_id: Vector3 = snapped(atom.get_position(), Vector3(_cell_size, _cell_size, _cell_size))
		if not _grid.has(cell_id):
			_grid[cell_id] = []
		_grid[cell_id].push_back(atom)

	## Returns all 8 cells directly touching the cell (diagonals included)
	## The main (center) cell is not included in the results.
	func get_neighbor_cells(cell_id: Vector3) -> Array[Vector3]:
		var neighbor_cells: Array[Vector3] = []
		for x: int in [-1, 0, 1]:
			for y: int in [-1, 0, 1]:
				for z: int in [-1, 0, 1]:
					var offset: Vector3 = Vector3(x, y, z) * _cell_size
					var neighbor_id: Vector3 = offset + cell_id
					if neighbor_id.is_equal_approx(cell_id):
						continue # Don't include the center cell in the neighbors
					if _grid.has(neighbor_id):
						neighbor_cells.push_back(neighbor_id)
		return neighbor_cells

	## For each cell, find their 8 neighbors and get all the atoms within
	## Calculate the distance between the atoms and mark them as overlapping
	## if the distance is smaller than half their nominal bond length.
	## When a cell is processed, ignore it from future calculations to avoid
	## duplicates.
	func get_overlaps() -> Array[OverlapData]:
		var overlaps: Array[OverlapData] = []
		var processed_cells: Array[Vector3] = []
		for cell_id: Vector3 in _grid:
			var atoms: Array[AtomData] = []
			atoms.assign(_grid[cell_id])
			
			var neighbor_atoms: Array[AtomData] = []
			var overlapping_atoms: Array[AtomData] = []
			
			neighbor_atoms.append_array(atoms)
			for neighbor_cell: Vector3 in get_neighbor_cells(cell_id):
				if processed_cells.has(neighbor_cell):
					continue
				atoms.append_array(_grid[neighbor_cell])
			
			for atom: AtomData in atoms:
				var atom_pos: Vector3 = atom.get_position()
				for other_atom: AtomData in neighbor_atoms:
					if atom == other_atom:
						continue
					var other_atom_pos: Vector3 = other_atom.get_position()
					var min_distance: float = (atom.covalent_radius + other_atom.covalent_radius) * 0.5
					if atom_pos.distance_squared_to(other_atom_pos) < pow(min_distance, 2.0):
						if not overlapping_atoms.has(atom):
							overlapping_atoms.push_back(atom)
						if not overlapping_atoms.has(other_atom):
							overlapping_atoms.push_back(other_atom)
			
			if not overlapping_atoms.is_empty():
				var overlap := OverlapData.new(overlapping_atoms, atoms[0].structure_context)
				overlaps.push_back(overlap)
			
			processed_cells.push_back(cell_id)
		
		return overlaps
