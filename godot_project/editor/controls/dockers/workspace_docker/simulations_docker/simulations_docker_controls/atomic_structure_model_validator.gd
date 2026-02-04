class_name AtomicStructureModelValidator extends Node


signal results_outdated()
signal validation_finished(found_overlaps: bool)
signal alert_selected(has_invisible_atoms: bool)


const COLOR_DELETED: Color = Color.WEB_GRAY
const DELETED_ICON: Texture2D = preload("res://editor/controls/menu_bar/menu_edit/icons/icon_delete.svg")
const MAX_COVALENT_RADIUS: float = 0.232
const MAX_SHAKE_ITERATIONS: int = 5
# Cell size needs be large enough to hold the biggest atom + some margin of error
const MAX_HASH_GRID_CELL_SIZE: float = MAX_COVALENT_RADIUS * 3.0


var _thread: Thread
var _overlaps: Dictionary[OverlapData, int] = {} # Overlap data : Alert ID
var _data: Dictionary[Metadata, int] = {} # Data : Alert ID
var _workspace_context: WorkspaceContext = null
var _last_validation_version: int = -1


func set_workspace_context(in_workspace_context: WorkspaceContext) -> void:
	assert(not is_instance_valid(_workspace_context), "Already initialized")
	_workspace_context = in_workspace_context
	in_workspace_context.history_changed.connect(_on_history_changed)


func _on_history_changed() -> void:
	if _last_validation_version < 0 or _last_validation_version == _workspace_context.get_version():
		return
	
	var last_action: String = _workspace_context.get_last_snapshot_name()
	if not History.is_operation_whitelisted_during_simulation(last_action):
		_update_alerts()
		results_outdated.emit()


func _validate_bonds_in_thread(
		in_structure_contexts: Array[StructureContext],
		out_promise: Promise,
		in_atom_set: AtomicStructure.AtomSet) -> void:
	var validation_results: Array[Metadata] = []
	var spatial_hash_grid: SpatialHashGridOverlaps = SpatialHashGridOverlaps.new(MAX_COVALENT_RADIUS)
	
	for structure_context: StructureContext in in_structure_contexts:
		if not structure_context.nano_structure is AtomicStructure:
			continue
		var atomic_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
		var ignored_springs: Array[Metadata] = []
		var atoms: PackedInt32Array
		match in_atom_set:
			AtomicStructure.AtomSet.SELECTED_ONLY:
				atoms = structure_context.get_selected_atoms()
			AtomicStructure.AtomSet.ALL_VISIBLE:
				if atomic_structure.get_visible():
					atoms = atomic_structure.get_visible_atoms()
			AtomicStructure.AtomSet.ALL:
				atoms = atomic_structure.get_valid_atoms()
		
		if atoms.is_empty():
			continue
		
		for atom_id: int in atoms:
			var atom_data: AtomData = AtomData.new(atom_id, structure_context)
			if atom_data.has_invalid_bonds():
				validation_results.push_back(atom_data)
			spatial_hash_grid.add_item(atom_data.get_position(), atom_data)
			
			# Collect Ignored Springs:
			# Springs hooked to atoms that are locked in position will be ignored
			if atomic_structure.atom_is_locked(atom_id):
				var atom_springs: PackedInt32Array = atomic_structure.atom_get_springs(atom_id)
				if not atom_springs.is_empty():
					var ignored_springs_data := IgnoredSpring.new(atom_id, atom_springs, structure_context)
					ignored_springs.push_back(ignored_springs_data)
		
		validation_results.append_array(ignored_springs)
	
	validation_results.append_array(spatial_hash_grid.get_overlaps())
	
	var drastically_bad_sp3_groups: Array[Dictionary] = WorkspaceUtils.collect_drastically_invalid_tetrahedral_structure(
		in_structure_contexts, in_atom_set)
	
	for group: Dictionary in drastically_bad_sp3_groups:
		var bad_bond_angle_data := DrasticSp3Data.new(group.atoms_ids, group.bond_ids, group.structure_context)
		validation_results.append(bad_bond_angle_data)
	
	var bad_bond_angles_groups: Array[Dictionary] = WorkspaceUtils.collect_invalid_bond_angles(
		in_structure_contexts, in_atom_set)
	
	for group: Dictionary in bad_bond_angles_groups:
		var bad_bond_angle_data := InvalidSp123Data.new(group.type, group.atoms_ids, group.bond_ids, group.structure_context)
		validation_results.append(bad_bond_angle_data)
	
	out_promise.fulfill.bind(validation_results).call_deferred()


func validate_atomic_model(atom_set: AtomicStructure.AtomSet) -> void:
	if _thread and _thread.is_alive():
		return
	_last_validation_version = _workspace_context.get_version() + 1
	var promise: Promise = Promise.new()
	_thread = Thread.new()
	_thread.start(_validate_bonds_in_thread.bind(_workspace_context.get_all_structure_contexts(), promise, atom_set))
	
	_workspace_context.start_async_work(_workspace_context.tr("Validating model ..."))
	await promise.wait_for_fulfill()
	_thread.wait_to_finish()
	_workspace_context.end_async_work()
	assert(not promise.has_error())
	
	var validation_results: Array[Metadata] = promise.get_result()
	_overlaps.clear()
	_data.clear()
	
	for metadata: Metadata in validation_results:
		var alert_id: int
		if metadata.alert_level == Metadata.AlertLevel.WARNING:
			alert_id = _workspace_context.push_warning_alert(metadata.text, _on_alert_selected, _on_alert_selected.bind(true))
		else:
			alert_id = _workspace_context.push_error_alert(metadata.text, _on_alert_selected, _on_alert_selected.bind(true))
		_data[metadata] = alert_id
		if metadata is OverlapData:
			_overlaps[metadata as OverlapData] = alert_id
	
	validation_finished.emit(not _overlaps.is_empty())


## Returns true if there's at least one valid overlap data
func has_overlapping_atoms() -> bool:
	for overlap_data: OverlapData in _overlaps:
		if overlap_data.is_fixed:
			continue
		if not overlap_data.has_invalid_atoms():
			return true
	return false


func fix_overlapping_atoms() -> void:
	# Create a hash grid of the whole workspace to avoid moving an overlapping
	# atom on top of another atom not involved in the original overlap.
	# This hash grid does not contains the overlapping atoms.
	var static_atom_grid := SpatialHashGrid.new(MAX_HASH_GRID_CELL_SIZE)
	for other_context: StructureContext in _workspace_context.get_all_structure_contexts():
		if not other_context.nano_structure is AtomicStructure:
			continue
		var atomic_structure: AtomicStructure = other_context.nano_structure
		for atom_id: int in atomic_structure.get_valid_atoms():
			var atom_position: Vector3 = atomic_structure.atom_get_position(atom_id)
			static_atom_grid.add_item(atom_position, atom_id)
	
	var overlap_atom_grid := SpatialHashGrid.new(MAX_HASH_GRID_CELL_SIZE)
	for overlap: OverlapData in _overlaps:
		if overlap.is_fixed:
			continue
		var nano_structure: AtomicStructure = overlap.structure_context.nano_structure
		if not is_instance_valid(nano_structure):
			continue
		
		# Find the overlap center position.
		var current_overlap_atoms: Dictionary[int, SpatialHashGrid.Item] = {}
		var overlap_center: Vector3 = Vector3.ZERO
		for atom_id in overlap.atoms_id:
			if not nano_structure.is_atom_valid(atom_id):
				# Atom was deleted after the validation
				continue
			var atom_position: Vector3 = nano_structure.atom_get_position(atom_id)
			overlap_center += atom_position
			static_atom_grid.remove_item_by_position(atom_position)
			var item: SpatialHashGrid.Item
			item = overlap_atom_grid.add_item(atom_position, {"id": atom_id, "data": overlap})
			current_overlap_atoms[atom_id] = item

		if current_overlap_atoms.is_empty():
			continue
		overlap_center /= current_overlap_atoms.size()
		
		# Move each overlapping atoms away from the center point, by at least
		# their atomic radius.
		for atom_id: int in current_overlap_atoms:
			var item: SpatialHashGrid.Item = current_overlap_atoms[atom_id]
			var position: Vector3 = item.position
			while position.is_equal_approx(overlap_center):
				position = item.position + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)
			var dir_from_center: Vector3 = overlap_center.direction_to(position)
			var atomic_number: int = nano_structure.atom_get_atomic_number(atom_id)
			var element_data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
			var radius: float = element_data.covalent_radius[1]
			const DISTANCE_MARGIN: float = 1.1
			var new_position: Vector3 = overlap_center + dir_from_center * radius * DISTANCE_MARGIN
			overlap_atom_grid.move_item(item, new_position)
	
	# Atoms might still overlap with other overlap groups, or with the rest of
	# the structure (described in static_atom_grid).
	# Relax all the overlapping atoms in the same pass.
	# For each atom, find the nearest atom and move away. Repeat up to MAX_SHAKE_ITERATIONS
	var multiplier: float = 1.0
	for iteration: int in MAX_SHAKE_ITERATIONS:
		var atoms_were_moved: bool = false
		for item: SpatialHashGrid.Item in overlap_atom_grid.get_all_items():
			# Find the closest atom
			var nearby_atoms: Array[SpatialHashGrid.Item] = []
			nearby_atoms = overlap_atom_grid.get_items_around(item.position)
			nearby_atoms.append_array(static_atom_grid.get_items_around(item.position))
			var closest_atom: SpatialHashGrid.Item
			var min_distance_squared: float = INF
			var separation_vector: Vector3
			for candidate_item in nearby_atoms:
				if item == candidate_item:
					continue
				var diff: Vector3 = item.position - candidate_item.position
				var distance_squared: float = diff.length_squared()
				if distance_squared < min_distance_squared:
					separation_vector = diff
					min_distance_squared = distance_squared
					closest_atom = candidate_item
			if not closest_atom:
				continue
			
			# Move the atom away from the closest atom
			var move_offset: float = MAX_COVALENT_RADIUS * 0.25 * multiplier
			var max_separation_distance_squared: float = pow(MAX_COVALENT_RADIUS, 2.0)
			if min_distance_squared > max_separation_distance_squared:
				continue # Atom already far enough
			var new_position: Vector3 = item.position + separation_vector.normalized() * move_offset
			overlap_atom_grid.move_item(item, new_position)
			atoms_were_moved = true
		
		if not atoms_were_moved:
			break # Atoms are no longer overlapping
		multiplier *= 0.75 # Make the next iteration less pronounced

	# Apply the new positions
	for item: SpatialHashGrid.Item in overlap_atom_grid.get_all_items():
		var overlap: OverlapData = item.user_data.get("data")
		var atom_id: int = item.user_data.get("id")
		var nano_structure: NanoMolecularStructure = overlap.structure_context.nano_structure
		if not nano_structure.is_being_edited():
			nano_structure.start_edit()
		nano_structure.atom_set_position(atom_id, item.position)
	
	for overlap: OverlapData in _overlaps:
		var nano_structure: NanoMolecularStructure = overlap.structure_context.nano_structure
		if nano_structure.is_being_edited():
			nano_structure.end_edit()
		# Update the alert for this overlap
		overlap.is_fixed = true
		var alert_id: int = _overlaps[overlap]
		_workspace_context.mark_alert_as_fixed(alert_id)
	
	_workspace_context.snapshot_moment("Fix Overlapping Atoms Errors")


func _on_alert_selected(in_alert_id: int, show_hidden: bool = false) -> void:
	var metadata: Metadata = _data.find_key(in_alert_id)
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
		var atom_id2: int = atomic_structure.spring_get_second_atom_id(spring_id)
		if atom_id2 != AtomicStructure.INVALID_ATOMIC_NUMBER and atomic_structure.atom_get_atomic_number(atom_id2) == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
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
				if not atomic_structure.spring_is_atom_to_atom(spring):
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


func _update_alerts() -> void:
	for data: Metadata in _data:
		if data.has_invalid_atoms():
			var alert_id: int = _data[data]
			_workspace_context.mark_alert_as_invalid(alert_id)


func show_hidden_atoms(in_selected_alert: int) -> void:
	_on_alert_selected(in_selected_alert, true)


class Metadata:
	enum AlertLevel {
		WARNING,
		ERROR
	}
	var alert_level: AlertLevel = AlertLevel.WARNING
	var text: String
	var is_fixed: bool

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
	var other_structures: Array # Array[StructureContext]

	func _init(in_atoms: Array[AtomData], in_structure_context: StructureContext, 
			in_other_structures: Array = []) -> void:
		structure_context = in_structure_context
		atoms_id = PackedInt32Array()
		other_structures.assign(in_other_structures)
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
		var plural: bool = map.size() > 1
		for element: String in map:
			var count: int = map[element]
			if count > 1:
				plural = true
			if index == map.size() - 2:
				delimiter = " and "
			elif index == map.size() - 1:
				delimiter = ""
			text += "%d %s%s%s" % [count, element, "s" if count != 1 else "", delimiter]
			index += 1
		text += " of group " + structure_context.nano_structure.get_structure_name()
		if plural:
			text += " are overlapping"
		else:
			text += " is overlapping"
		match other_structures.size():
			0:
				text += "."
			1:
				text += " with group: %s." % [other_structures[0].nano_structure.get_structure_name()]
			_:
				text += " with groups: "
				for i in other_structures.size():
					text += other_structures[i].nano_structure.get_structure_name()
					if i < other_structures.size() - 1:
						text += ", "
				text += "."

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


## Specialization of the SpatialHashGrid
## Scans for atoms close enough that their covalent radius intersect.
class SpatialHashGridOverlaps extends SpatialHashGrid:
	func get_overlaps() -> Array[OverlapData]:
		var result: Array[OverlapData] = []
		
		var visited: Dictionary[Vector2i, bool] = {}
		for close_atoms: Array[AtomData] in get_user_data_closer_than(MAX_COVALENT_RADIUS):
			# Scan every pair of atoms within the local group (close_atoms)
			# Atoms overlaps if the sum of their radii is smaller than the distance between them.
			for i: int in close_atoms.size() - 1 :
				var atom: AtomData = close_atoms[i]
				var atom_unique_id := Vector2i(
					atom.structure_context.int_guid, atom.id
				)
				if visited.has(atom_unique_id):
					# Skip if already included in another overlap
					continue
				# Find overlapping atoms and group them by their structure context
				var overlapping_atoms: Dictionary = {} # StructureContext: Array[AtomData]
				var atom_pos: Vector3 = atom.get_position()
				overlapping_atoms[atom.structure_context] = [atom]
				for j: int in range(i + 1, close_atoms.size()):
					var other_atom: AtomData = close_atoms[j]
					var other_unique_id := Vector2i(
						other_atom.structure_context.int_guid, other_atom.id
					)
					if visited.has(other_unique_id):
						# Skip if already included in another overlap
						continue
					var other_atom_pos: Vector3 = other_atom.get_position()
					var min_distance: float = (atom.covalent_radius + other_atom.covalent_radius) * 0.5
					if atom_pos.distance_squared_to(other_atom_pos) < pow(min_distance, 2.0):
						if not overlapping_atoms.has(other_atom.structure_context):
							overlapping_atoms[other_atom.structure_context] = []
						overlapping_atoms[other_atom.structure_context].push_back(other_atom)
						visited[other_unique_id] = true
				# Overlapping atoms might belong to different structures.
				# Create a new OverlapData per structure to prevent the user from selecting
				# atoms from different groups at once when clicking on the error.
				# NOTE: If all atoms happens to be in the same group, then other_structures will
				# end up being an empty array, creating a unique warning
				for current_structure: StructureContext in overlapping_atoms:
					var atoms: Array[AtomData] = []
					atoms.assign(overlapping_atoms[current_structure])
					var other_structures: Array = overlapping_atoms.keys().duplicate()
					other_structures.erase(current_structure)
					var overlap_count: int = atoms.size()
					for other: StructureContext in other_structures:
						overlap_count += overlapping_atoms[other].size()
					if overlap_count <= 1:
						continue
					var overlap := OverlapData.new(atoms, current_structure, other_structures)
					result.push_back(overlap)
		return result
