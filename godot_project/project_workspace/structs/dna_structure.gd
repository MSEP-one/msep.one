class_name DnaStructure extends AtomicStructure

signal edit_mode_changed(in_mode: EditMode)
# Path related signals
signal bases_count_changed(new_count: int)
signal sequence_changed(new_sequence: String)
signal path_changed()
signal parameters_changed(read_only_parameters: DnaStructureParameters)

enum Strand {
	A = 1,
	B = 2,
	BOTH = 3,
}
enum EditMode {
	SequenceAndPath,
	AtomsAndBonds,
}

const StrandPolicy = DnaStructureParameters.StrandPolicy
const PackedMolecule = preload("res://autoloads/dna_builder/templates/packed_molecule.gd")
const INVALID_CONTROL_POINT_IDX: int = -1


@export var _curve: Curve3D:
	set = _set_curve
@export var _twists_offset_radians: float
@export var _sequence: String
@export var _parameters: DnaStructureParameters
@export var _edit_mode := EditMode.SequenceAndPath

# Atoms and Bases caches
var _base_transform_cache: Dictionary[int, Transform3D]
var _atoms_count_cache: int = -1
var _atoms_ids_cache: Dictionary[Strand, PackedInt32Array] = {}
var _atoms_cache: Dictionary[int, AtomData] = {}
var _bonds_count_cache: int = -1
var _bonds_ids_cache: Dictionary[Strand, PackedInt32Array] = {}
var _bonds_cache: Dictionary[int, Vector3i]
var _highest_spring_id: int = -1
static var _unpacked_atom_ids: Dictionary[int, UnpackedAtomId]
static var _unpacked_bond_ids: Dictionary[int, UnpackedBondId]

var _last_sequence: String = ""
var _last_bases_cout: int = 0
var _signal_queue_path_changed: bool = false
var _signal_queue_parameters_changed: bool = false
var _baked_path: PackedVector3Array = []

@export var _springs: Dictionary = {
	# id<int> : NanoSpring
}
@export var _motor_links: Dictionary[int, int] = {
	# atom_id<int> : motor_id<int>
}


static func create_dna(out_parameters: DnaStructureParameters, in_sequence: String = "") -> DnaStructure:
	var instance := DnaStructure.new()
	instance._parameters = out_parameters.duplicate(true)
	instance._sequence = in_sequence
	return instance


func _init() -> void:
	if _parameters == null:
		_parameters = DnaStructureParameters.new()
	if _curve == null:
		# Newly created object
		_curve = Curve3D.new()
		_curve.set_block_signals(true)
		_curve.bake_interval = 0.02
		_curve.set_block_signals(false)


func _set_curve(in_curve: Curve3D) -> void:
	if _curve != null and _curve.changed.is_connected(_on_curve_changed):
		_curve.changed.disconnect(_on_curve_changed)
	_curve = in_curve
	_curve.changed.connect(_on_curve_changed)


func grab_curve(out_path3d: Path3D) -> void:
	out_path3d.curve = _curve


## Get a list of points representing the path
## in_path_override can be provided to get an alternative path while editing the spline of this structure
func get_baked_path(in_path_override: Curve3D = null) -> PackedVector3Array:
	var curve: Curve3D = _curve if in_path_override == null else in_path_override
	if curve.point_count == 1:
		return [curve.get_point_position(0)]
	elif curve.point_count == 0:
		return []
	if _baked_path.is_empty() or _signal_queue_path_changed or in_path_override != null:
		var baked_path: PackedVector3Array = curve.get_baked_points()
		var total_length: float = get_path_length()
		if curve.get_baked_length() < total_length:
			var last_pos: Vector3 = baked_path[-1]
			var z_dir: Vector3 = baked_path[-2].direction_to(last_pos)
			var remaining_distance: float = total_length - curve.get_baked_length()
			var final_pos: Vector3 = last_pos + z_dir * remaining_distance
			while remaining_distance >= curve.bake_interval:
				last_pos += z_dir * curve.bake_interval
				baked_path.append(last_pos)
				remaining_distance -= curve.bake_interval
			baked_path.append(final_pos)
		if in_path_override == null:
			_baked_path = baked_path
		else:
			return baked_path
	return _baked_path.duplicate()


#region: Edit tracking
func set_edit_mode(in_mode: EditMode) -> void:
	# This may be counter intuitive, but logic is you should not be able to change
	# Path/Sequence + Atoms/Bonds in the same start/end edit process
	assert(!_is_being_edited, "Edit Mode can only be changed while edition is not happening")
	if _edit_mode == in_mode: return
	if in_mode == EditMode.SequenceAndPath:
		# Atoms and bonds has been removed
		var atoms_to_signal: PackedInt32Array = get_valid_atoms()
		var bonds_to_signal: PackedInt32Array = get_valid_bonds()
		var springs_to_remove: PackedInt32Array = _springs.keys()
		_edit_mode = in_mode
		_atoms_cache = {}
		_atoms_count_cache = -1
		_bonds_count_cache = -1
		_springs.clear()
		locked_atoms = {}
		color_overrides = {}
		springs_removed.emit(springs_to_remove)
		atoms_removed.emit(atoms_to_signal)
		bonds_removed.emit(bonds_to_signal)
		# TODO: Track springs? locked atoms? color overrides?
		# changes on bases can easily invalidate springs,
		# but maybe the property can be cleared when edit mode changes
	elif in_mode == EditMode.AtomsAndBonds:
		# Atoms and bonds added back
		_edit_mode = in_mode
		_atoms_count_cache = -1
		_bonds_count_cache = -1
		var atoms_to_signal: PackedInt32Array = get_valid_atoms()
		var bonds_to_signal: PackedInt32Array = get_valid_bonds()
		atoms_added.emit(atoms_to_signal)
		bonds_created.emit(bonds_to_signal)
	edit_mode_changed.emit(in_mode)


func get_edit_mode() -> EditMode:
	return _edit_mode


func start_edit() -> void:
	assert(not _is_being_edited, "I'm already being edited, make sure to call end_edit() when you are done with edits")
	super.start_edit()
	_last_bases_cout = _sequence.length()
	_last_sequence = _sequence
	return


func end_edit() -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	if _edit_mode == EditMode.SequenceAndPath:
		_is_being_edited = false
		var has_changed: bool = (
			_last_bases_cout != _sequence.length()
			or _last_sequence != _sequence
			or _signal_queue_path_changed
			or _signal_queue_parameters_changed
			)
		if has_changed:
			if _signal_queue_path_changed:
				path_changed.emit()
				_baked_path.clear()
				_signal_queue_path_changed = false
			# Emmit count changed signal before actual sequence
			if _last_bases_cout != _sequence.length():
				var count: = _sequence.length()
				bases_count_changed.emit(count)
				_last_bases_cout = _sequence.length()
			if _last_sequence != _sequence:
				_last_sequence = _sequence
				_atoms_count_cache = -1
				_atoms_ids_cache = {}
				_atoms_cache = {}
				_bonds_count_cache = -1
				_bonds_ids_cache = {}
				_bonds_cache = {}
				_baked_path.clear()
				sequence_changed.emit(_sequence)
			if _signal_queue_parameters_changed:
				_baked_path.clear()
				_parameters.set_read_only(true)
				parameters_changed.emit(_parameters)
				_parameters.set_read_only(false)
				_signal_queue_parameters_changed = false
			emit_changed()
	else:
		super.end_edit()


## UNUSED [s]Removes every atom, bond, and spring from this structure[/s]
func clear() -> void:
	assert(false, "Cannot delete atoms and bonds in this structure")
	return
#endregion: Edit tracking


#region: Parameters
func set_bases_per_turn(in_bases_per_turn: float) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	_signal_queue_parameters_changed = true
	_parameters.bases_per_turn = in_bases_per_turn


func get_bases_per_turn() -> float:
	return _parameters.bases_per_turn


func set_rise_nanometers(in_rise_nanometers: float) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	_signal_queue_parameters_changed = true
	_parameters.rise_nanometers = in_rise_nanometers
	_adjust_sequence_to_path_length()


func get_rise_nanometers() -> float:
	return _parameters.rise_nanometers


func set_dna_radius_nanometers(in_radius_nanometers: float) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	_signal_queue_parameters_changed = true
	_parameters.dna_radius_nanometers = in_radius_nanometers


func get_dna_radius_nanometers() -> float:
	return _parameters.dna_radius_nanometers


func set_initial_twist_rad(in_initial_twist_rad: float) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	_signal_queue_parameters_changed = true
	_parameters.initial_twist_rad = in_initial_twist_rad


func get_initial_twist_rad() -> float:
	return _parameters.initial_twist_rad


func set_strand_policy(in_strand_policy: StrandPolicy) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	_signal_queue_parameters_changed = true
	_parameters.strand_policy = in_strand_policy


func get_strand_policy() -> StrandPolicy:
	return _parameters.strand_policy


func get_strands() -> Array[Strand]:
	match get_strand_policy():
		StrandPolicy.A:
			return [Strand.A]
		StrandPolicy.B:
			return [Strand.B]
		StrandPolicy.DOUBLE:
			return [Strand.A, Strand.B]
		_:
			assert(false, "Should not happen")
			return []


func set_include_hydrogens(in_include_hydrogens: bool) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	_signal_queue_parameters_changed = true
	_parameters.include_hydrogens = in_include_hydrogens


func get_include_hydrogens() -> bool:
	return _parameters.include_hydrogens
#endregion


#region: Path
func _on_curve_changed() -> void:
	_signal_queue_path_changed = true
	_base_transform_cache.clear()
	_adjust_sequence_to_path_length()


func insert_control_point(position: Vector3, in_index: int = -1) -> void:
	assert(_is_being_edited)
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	_curve.add_point(position, Vector3.ZERO, Vector3.ZERO, in_index)
	var index: int = in_index if in_index > -1 else _curve.point_count - 1
	recalculate_curve_in_out(_curve, index - 1)
	recalculate_curve_in_out(_curve, index)
	recalculate_curve_in_out(_curve, index + 1)


func remove_control_point(in_index: int) -> void:
	assert(_is_being_edited)
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	_curve.remove_point(in_index)
	if in_index > 0:
		recalculate_curve_in_out(_curve, in_index - 1)
	if in_index < _curve.point_count:
		recalculate_curve_in_out(_curve, in_index)


func is_control_point_valid(in_index: int) -> bool:
	return in_index >= 0 and in_index < _curve.point_count


func set_control_point_position(in_index: int, int_position: Vector3) -> void:
	assert(_is_being_edited)
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	_curve.set_point_position(in_index, int_position)
	recalculate_curve_in_out(_curve, in_index - 1)
	recalculate_curve_in_out(_curve, in_index)
	recalculate_curve_in_out(_curve, in_index + 1)


func get_control_point_count() -> int:
	return _curve.point_count


func get_control_point_position(in_index: int) -> Vector3:
	return _curve.get_point_position(in_index)


func get_path_length() -> float:
	if _sequence.length() < 1:
		return 0.0
	return (_sequence.length() - 1) * get_rise_nanometers()


func get_base_transform(in_strand: Strand, in_base_index: int) -> Transform3D:
	var cache_index: int = (in_base_index + 1) * (-1 if in_strand == Strand.B else 1)
	assert(cache_index != 0, "Invalid cache_index 0 (since cannot be distinguished for A and B strand)")
	if not cache_index in _base_transform_cache:
		var at_pos: float = in_base_index * _parameters.rise_nanometers
		var y_dir := Vector3.ZERO
		var z_dir := Vector3.ZERO
		var path_pos: Vector3
		var points: PackedVector3Array = get_baked_path()
		assert(at_pos <= get_path_length())
		# position is along the curve
		var advance: float = 0
		var point_idx: int = 0
		var curr_pos: Vector3 = points[point_idx]
		var next_pos: Vector3 = points[point_idx + 1]
		var next_advance: float = advance + curr_pos.distance_to(next_pos)
		while at_pos > max(advance, next_advance) and point_idx < points.size() -2:
			point_idx += 1
			advance = next_advance
			curr_pos = points[point_idx]
			next_pos = points[point_idx + 1]
			next_advance += curr_pos.distance_to(next_pos)
		path_pos = curr_pos
		z_dir = points[point_idx].direction_to(points[point_idx + 1])
		y_dir = _curve.get_baked_up_vectors()[-1]
		y_dir = y_dir.rotated(z_dir, get_base_twist_rad(in_strand, in_base_index))
		var x_dir: Vector3 = y_dir.cross(z_dir)
		var basis := Basis(x_dir, y_dir, z_dir)
		var base_offset: float = _parameters.dna_radius_nanometers - DnaBuilder.DNA_BASES_OFFSET
		var final_pos: Vector3 = path_pos + x_dir * base_offset
		_base_transform_cache[cache_index] = Transform3D(basis, final_pos)
	return _base_transform_cache[cache_index]


func get_backbone_transform(in_strand: Strand, in_base_index: int) -> Transform3D:
	var transform: Transform3D = get_base_transform(in_strand, in_base_index)
	var backbone_offset_dir: Vector3 = transform.basis.x
	transform.origin += backbone_offset_dir * DnaBuilder.DNA_BASES_OFFSET
	return transform


func get_base_twist_rad(in_strand: Strand, in_base_index: int) -> float:
	var rad_per_base: float = deg_to_rad(360) / _parameters.bases_per_turn
	var angle: float = (rad_per_base * in_base_index) + _twists_offset_radians
	if in_strand == Strand.B:
		angle += deg_to_rad(180)
	return angle


static func recalculate_curve_in_out(out_curve: Curve3D, in_index: int) -> void:
	if out_curve.point_count < 2:
		# Not enough points for this operation
		return
	if in_index < 0 or in_index >= out_curve.point_count:
		# Index out of range. no change needed.
		return
	if in_index == 0:
		var p0: Vector3 = out_curve.get_point_position(0)
		var p1: Vector3 = out_curve.get_point_position(1)
		var dist: float = p0.distance_to(p1) / 2.0
		var dir: Vector3 = p0.direction_to(p1)
		out_curve.set_point_out(in_index, dir * dist)
	elif in_index >= out_curve.point_count - 1:
		var p1: Vector3 = out_curve.get_point_position(in_index)
		var p0: Vector3 = out_curve.get_point_position(in_index - 1)
		var dist: float = p0.distance_to(p1) / 2.0
		var dir: Vector3 = p1.direction_to(p0)
		out_curve.set_point_in(in_index, dir * dist)
	else:
		var p1: Vector3 = out_curve.get_point_position(in_index + 1)
		var p0: Vector3 = out_curve.get_point_position(in_index - 1)
		var dist: float = p0.distance_to(p1) / 4.0
		var dir: Vector3 = p0.direction_to(p1)
		out_curve.set_point_in(in_index, -dir * dist)
		out_curve.set_point_out(in_index, dir * dist)
#endregion: Path


#region: Sequence
func set_sequence(in_sequence: String) -> void:
	assert(_is_being_edited)
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	if _sequence != in_sequence:
		_sequence = in_sequence
		_adjust_sequence_to_path_length()


func get_sequence() -> String:
	return _sequence


func _adjust_sequence_to_path_length() -> void:
	assert(_is_being_edited)
	assert(_edit_mode == EditMode.SequenceAndPath, "Cannot change helix proeprties in this state")
	var expected_sequence_length: int = floori(_curve.get_baked_length() / _parameters.rise_nanometers)
	if expected_sequence_length == _sequence.length():
		return
	# Remove only X'es at the end of the sequence
	var modified_sequence: String = _sequence.rstrip("X")
	if modified_sequence.length() < expected_sequence_length:
		modified_sequence += "X".repeat(expected_sequence_length - modified_sequence.length())
	# IMPORTANT: This comparison avoids unnecesary COW changes to _sequence
	if modified_sequence != _sequence:
		_sequence = modified_sequence
#endregion: Sequence


#region: Atoms and Bonds
## DNA Structure does not allow creating, removing, or modifying atoms and bonds
## so this function always returns false
func can_create_and_delete_atoms() -> bool:
	return false


## Returns number of atoms that has been created in this NanoStructure
func get_valid_atoms_count() -> int:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	if _edit_mode == EditMode.SequenceAndPath:
		return 0
	if _atoms_count_cache == -1:
		var base_count: Dictionary[String, int] = {
			"A" : DnaBuilder.get_template_atom_count("A", _parameters.include_hydrogens),
			"T" : DnaBuilder.get_template_atom_count("T", _parameters.include_hydrogens),
			"G" : DnaBuilder.get_template_atom_count("G", _parameters.include_hydrogens),
			"C" : DnaBuilder.get_template_atom_count("C", _parameters.include_hydrogens),
			"X" : 0,
			"B" : DnaBuilder.get_template_atom_count("backbone0", _parameters.include_hydrogens)
		}
		_atoms_count_cache = base_count["B"] * _sequence.length()
		if get_strand_policy() == StrandPolicy.DOUBLE:
			# account for both backbones
			_atoms_count_cache *= 2
		for base in _sequence:
			if get_strand_policy() in [StrandPolicy.A, StrandPolicy.DOUBLE]:
				_atoms_count_cache += base_count[base]
			if get_strand_policy() in [StrandPolicy.B, StrandPolicy.DOUBLE]:
				_atoms_count_cache += base_count[DnaBuilder.DNA_COMPLEMENT.get(base, "X")]
	return _atoms_count_cache


func get_atom_ids_for_strand(in_strand: Strand) -> PackedInt32Array:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	assert(in_strand != Strand.BOTH, "Invalid usage of get_atoms_for_strand, use get_valid_atoms() instead")
	
	if _edit_mode == EditMode.SequenceAndPath:
		return []
	
	if not in_strand in _atoms_ids_cache.keys():
		# Update cache
		_atoms_ids_cache[in_strand] = PackedInt32Array()
		var base_count: Dictionary[String, int] = {
			"A" : DnaBuilder.get_template_atom_count("A", _parameters.include_hydrogens),
			"T" : DnaBuilder.get_template_atom_count("T", _parameters.include_hydrogens),
			"G" : DnaBuilder.get_template_atom_count("G", _parameters.include_hydrogens),
			"C" : DnaBuilder.get_template_atom_count("C", _parameters.include_hydrogens),
			"X" : 0,
			"B" : DnaBuilder.get_template_atom_count("backbone0", _parameters.include_hydrogens)
		}
		for base_idx: int in _sequence.length():
			# Backbone
			var atom_count: int = base_count["B"]
			for sub_atom_id: int in atom_count:
				assert(not _get_atom_id(base_idx, in_strand, true, sub_atom_id) in _atoms_ids_cache[in_strand], "Math failed and there are repeated atom ids!")
				_atoms_ids_cache[in_strand].append(_get_atom_id(base_idx, in_strand, true, sub_atom_id))
			# Base
			var base: String = _sequence[base_idx]
			if in_strand == Strand.B:
				base = DnaBuilder.DNA_COMPLEMENT.get(base, "X")
			atom_count = base_count[base]
			for sub_atom_id: int in atom_count:
				assert(not _get_atom_id(base_idx, in_strand, false, sub_atom_id) in _atoms_ids_cache[in_strand], "Math failed and there are repeated atom ids!")
				_atoms_ids_cache[in_strand].append(_get_atom_id(base_idx, in_strand, false, sub_atom_id))
	return _atoms_ids_cache[in_strand]
	

## Returns the list of atom_ids
func get_valid_atoms() -> PackedInt32Array:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	
	if _edit_mode == EditMode.SequenceAndPath:
		return []
	
	if get_strand_policy() != StrandPolicy.DOUBLE:
		return get_atom_ids_for_strand(get_strands()[0])
	
	
	if not _atoms_ids_cache.get(Strand.BOTH, []).is_empty():
		return _atoms_ids_cache[Strand.BOTH]
	
	_atoms_ids_cache[Strand.BOTH] = PackedInt32Array()
	for strand: Strand in get_strands():
		_atoms_ids_cache[Strand.BOTH].append_array(get_atom_ids_for_strand(strand))
	return _atoms_ids_cache[Strand.BOTH]


## UNUSED
func add_atom(_in_args: Variant = null) -> int:
	assert(false, "Dna Structure cannot modify atoms")
	return INVALID_ATOM_ID


## UNUSED
func revalidate_atom(_in_atom_idx: int) -> bool:
	assert(false, "Dna Structure cannot modify atoms")
	return false


## UNUSED
func remove_atom(_in_atom_id: int) -> bool:
	assert(false, "Dna Structure cannot modify atoms")
	return false


func is_atom_valid(in_atom_id: int) -> bool:
	if _edit_mode == EditMode.SequenceAndPath:
		return false
	
	var id_data: UnpackedAtomId = _unpack_atom_id(in_atom_id)
	if id_data.base_idx < 0 or id_data.base_idx >= _sequence.length():
		return false
	if not id_data.strand in get_strands():
		return false
	var template: PackedMolecule = _get_base_template_for_unpacked_atom(id_data)
	return id_data.sub_atom_id >= 0 and id_data.sub_atom_id < template.atoms.size()


## Returns the numbers of protons in atom's nucleous. This reffers to the id of an
## element in the Periodic Table
func atom_get_atomic_number(in_atom_id: int) -> int:
	if _edit_mode == EditMode.SequenceAndPath:
		return INVALID_ATOMIC_NUMBER
	return _get_atom_data(in_atom_id).atomic_number


## UNUSED
func atom_set_atomic_number(_in_atom_id: int, _in_atomic_number: int) -> void:
	assert(false, "Dna Structure cannot modify atoms")
	return


## Calculate the [url=https://en.wikipedia.org/wiki/Formal_charge]formal charge[/url] of a given atom
func atom_get_formal_charge(_in_atom_id: int) -> int:
	# TODO: for now assume 0
	return 0


## Returns the position of the atom, relative to structure's transform
func atom_get_position(in_atom_id: int) -> Vector3:
	if _edit_mode == EditMode.SequenceAndPath:
		return Vector3.ONE * NAN
	return _get_atom_data(in_atom_id).position


## Sets the position of a given atom, relative to structure's transform
## Returs true if succeeds or false if something prevents the change
## This is uniquely supported to update atoms positions during simulation
func atom_set_position(in_atom_id: int, in_pos: Vector3) -> bool:
	assert(_is_being_edited)
	assert(_edit_mode == EditMode.AtomsAndBonds, "Atoms and Bonds cannot be edited in this mode")
	const TO_UPDATE_POSITION = true
	_get_atom_data(in_atom_id, TO_UPDATE_POSITION).position = in_pos
	_signal_queue_atoms_moved.push_back(in_atom_id)
	return true


## Should be used instead of [code]atom_set_position()[/code] in cases where there is many atoms to move,
## for performance reasons - this way [code]changed[/code] signal is emitted only once
func atoms_set_positions(in_atoms: PackedInt32Array, in_positions: PackedVector3Array) -> void:
	assert(in_atoms.size() == in_positions.size())
	for i in in_atoms.size():
		atom_set_position(in_atoms[i], in_positions[i])


## returns IDs of the bonds that given atom is participating in
func atom_get_bonds(in_atom_id: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var id_data: UnpackedAtomId = _unpack_atom_id(in_atom_id)
	var template: PackedMolecule = _get_base_template_for_unpacked_atom(id_data)
	for sub_bond_id: int in template.bonds.size():
		var bond: Vector3i = template.bonds[sub_bond_id]
		if id_data.sub_atom_id in [bond.x, bond.y]:
			var bond_id: int = _get_bond_id(id_data.base_idx, id_data.strand, id_data.is_backbone, sub_bond_id)
			result.append(bond_id)
	# Check glue bonds
	var bases_to_scan: Dictionary[int, bool] = {}
	bases_to_scan[id_data.base_idx - 1] = true
	bases_to_scan[id_data.base_idx] = true
	bases_to_scan[id_data.base_idx + 1] = true
	for base_idx: int in bases_to_scan.keys():
		for is_backbone: bool in [true, false]:
			var glue_bond_id: int = _get_glue_bond_id(base_idx, id_data.strand, is_backbone)
			if not is_bond_valid(glue_bond_id):
				continue
			# Check if this bond actually connects both atoms
			var bond: Vector3i = get_bond(glue_bond_id)
			if in_atom_id in [bond.x, bond.y]:
				result.append(glue_bond_id)
	return result


## Returns the ID of the another atom that's participating in in_bond_id
func atom_get_bond_target(in_atom_id: int, in_bond_id: int) -> int:
	var bond_data: Vector3i = get_bond(in_bond_id)
	if bond_data.x == in_atom_id:
		return bond_data.y
	elif bond_data.y == in_atom_id:
		return bond_data.x
	else:
		push_error("Bond ", in_bond_id, " is not involved with atom ", in_atom_id)
		return AtomicStructure.INVALID_ATOM_ID


## Returns bond id between first atom and second atom or -1 if bond do not exists
func atom_find_bond_between(in_atom_id_a: int, in_atom_id_b: int) -> int:
	if _edit_mode != EditMode.AtomsAndBonds:
		return INVALID_BOND_ID
	
	var a_id_data: UnpackedAtomId = _unpack_atom_id(in_atom_id_a)
	var b_id_data: UnpackedAtomId = _unpack_atom_id(in_atom_id_b)
	if a_id_data.strand != b_id_data.strand:
		# Not in the same strand, hence not bonded
		return INVALID_BOND_ID
	# from now on they are in the same strand
	elif a_id_data.base_idx != b_id_data.base_idx:
		# Assume is glue bond between backbones
		if not a_id_data.is_backbone or not b_id_data.is_backbone:
			# Atoms not bonded
			return INVALID_BOND_ID
		var bases_to_scan: Dictionary[int, bool] = {}
		bases_to_scan[a_id_data.base_idx - 1] = true
		bases_to_scan[a_id_data.base_idx] = true
		bases_to_scan[a_id_data.base_idx + 1] = true
		bases_to_scan[b_id_data.base_idx - 1] = true
		bases_to_scan[b_id_data.base_idx] = true
		bases_to_scan[b_id_data.base_idx + 1] = true
		for base_idx: int in bases_to_scan.keys():
			var backbone_bond_id: int = _get_glue_bond_id(base_idx, a_id_data.strand, true)
			# Check if this bond actually connects both atoms
			var bond: Vector3i = get_bond(backbone_bond_id)
			var bond_atoms: PackedInt32Array = [bond.x, bond.y]
			if in_atom_id_a in bond_atoms and in_atom_id_b in bond_atoms:
				return backbone_bond_id
		# None of the proposed glue bonds happened to be 
		return INVALID_BOND_ID
	# from now on they are in the same base index
	elif a_id_data.is_backbone != b_id_data.is_backbone:
		# Assume is glue between base and backbone
		var glue_bond: int = _get_glue_bond_id(a_id_data.base_idx, a_id_data.strand, false)
		var bond: Vector3i = get_bond(glue_bond)
		var bond_atoms: PackedInt32Array = [bond.x, bond.y]
		if in_atom_id_a in bond_atoms and in_atom_id_b in bond_atoms:
			return glue_bond
		return INVALID_BOND_ID
	# from now on they are in the same template, backbone or base
	else:
		var template: PackedMolecule = _get_base_template_for_unpacked_atom(a_id_data)
		for sub_bond_id: int in template.bonds.size():
			var bond: Vector3i = template.bonds[sub_bond_id]
			var bond_atom_sub_ids: PackedInt32Array = [bond.x, bond.y]
			if a_id_data.sub_atom_id in bond_atom_sub_ids and b_id_data.sub_atom_id in bond_atom_sub_ids:
				return _get_bond_id(a_id_data.base_idx, a_id_data.strand, a_id_data.is_backbone, sub_bond_id)
	return INVALID_BOND_ID


func atoms_count_visible_by_type(types_to_count: PackedInt32Array) -> int:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	if _edit_mode != EditMode.AtomsAndBonds:
		return 0
	var count: int = 0
	const FOR_UPDATING_DATA: bool = false
	for atom_id: int in get_valid_atoms():
		var atom: AtomData = _get_atom_data(atom_id, FOR_UPDATING_DATA)
		if atom.atomic_number in types_to_count and is_atom_visible(atom_id):
			count += 1
	return count


## UNUSED
func add_bond(_in_atom_id_a: int, _in_atom_id_b: int, _in_bond_order: int) -> int:
	assert(false, "Dna Structure cannot modify bonds")
	return INVALID_ATOM_ID


## UNUSED
func remove_bond(_in_bond_id: int) -> void:
	assert(false, "Dna Structure cannot modify bonds")
	return


## UNUSED
func revalidate_bond(_in_bond_id: int) -> bool:
	assert(false, "Dna Structure cannot modify bonds")
	return false


## Returns wether or not a bond has been removed from the structure
func is_bond_valid(in_bond_id: int) -> bool:
	var id_data: UnpackedBondId = _unpack_bond_id(in_bond_id)
	if id_data.is_glue_bond:
		if id_data.is_backbone:
			# check if base is on range
			return id_data.base_idx > 0 and id_data.base_idx < _sequence.length()
		else:
			# glue to the base, is always valid
			return id_data.base_idx >= 0 and id_data.base_idx < _sequence.length()
	else:
		var template: PackedMolecule = _get_base_template_for_unpacked_bond(id_data)
		return id_data.sub_bond_id >= 0 and id_data.sub_bond_id < template.bonds.size()


func get_bond_ids_for_strand(in_strand: Strand) -> PackedInt32Array:
	assert(not _is_being_edited, "I'm being edited, performing operations on bonds in this state is unrecommended")
	assert(in_strand != Strand.BOTH, "Invalid usage of get_bonds_for_strand, use get_valid_bonds() instead")
	
	if _edit_mode != EditMode.AtomsAndBonds:
		return []
	
	if not in_strand in _bonds_ids_cache.keys():
		# Update cache
		_bonds_ids_cache[in_strand] = PackedInt32Array()
		var base_count: Dictionary[String, int] = {
			"A" : DnaBuilder.get_template_bond_count("A", _parameters.include_hydrogens),
			"T" : DnaBuilder.get_template_bond_count("T", _parameters.include_hydrogens),
			"G" : DnaBuilder.get_template_bond_count("G", _parameters.include_hydrogens),
			"C" : DnaBuilder.get_template_bond_count("C", _parameters.include_hydrogens),
			"X" : 0,
			"B" : DnaBuilder.get_template_bond_count("backbone0", _parameters.include_hydrogens)
		}
		for base_idx: int in _sequence.length():
			# Backbone
			var bond_count: int = base_count["B"]
			for sub_bond_id: int in bond_count:
				assert(not _get_bond_id(base_idx, in_strand, true, sub_bond_id) in _bonds_ids_cache[in_strand], "Math failed and there are repeated bond ids!")
				_bonds_ids_cache[in_strand].append(_get_bond_id(base_idx, in_strand, true, sub_bond_id))
			if base_idx > 0:
				assert(not _get_glue_bond_id(base_idx, in_strand, true) in _bonds_ids_cache[in_strand], "Math failed and there are repeated bond ids!")
				# append glue bond
				_bonds_ids_cache[in_strand].append(_get_glue_bond_id(base_idx, in_strand, true))
			# Base
			var base: String = _sequence[base_idx]
			if in_strand == Strand.B:
				base = DnaBuilder.DNA_COMPLEMENT.get(base, "X")
			bond_count = base_count[base]
			for sub_bond_id: int in bond_count:
				assert(not _get_bond_id(base_idx, in_strand, false, sub_bond_id) in _bonds_ids_cache[in_strand], "Math failed and there are repeated bond ids!")
				_bonds_ids_cache[in_strand].append(_get_bond_id(base_idx, in_strand, false, sub_bond_id))
			if base != "X":
				# Add glue bond between backbone and base
				assert(not _get_glue_bond_id(base_idx, in_strand, false) in _bonds_ids_cache[in_strand], "Math failed and there are repeated bond ids!")
				# append glue bond
				_bonds_ids_cache[in_strand].append(_get_glue_bond_id(base_idx, in_strand, false))
	return _bonds_ids_cache[in_strand]


## Returns the list of bond_ids
func get_valid_bonds() -> PackedInt32Array:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	
	if _edit_mode != EditMode.AtomsAndBonds:
		return []
	
	if not _bonds_ids_cache.get(Strand.BOTH, []).is_empty():
		return _bonds_ids_cache[Strand.BOTH]
	
	_bonds_ids_cache[Strand.BOTH] = PackedInt32Array()
	for strand: Strand in get_strands():
		_bonds_ids_cache[Strand.BOTH].append_array(get_bond_ids_for_strand(strand))
	return _bonds_ids_cache[Strand.BOTH]


## Returns the list with all existing bonds ids
func get_bonds_ids() -> PackedInt32Array:
	return get_valid_bonds()


## Returns wether the bond should be rendered and/or mouse picked
func is_bond_visible(in_bond_id: int) -> bool:
	if _edit_mode != EditMode.AtomsAndBonds:
		return false
	return super.is_bond_visible(in_bond_id)


## Returns true if the bond is explicitely hidden with the "Hide Selected" action.
## Unlike is_bond_visible(), this method does not consider the hydrogen rendering state.
func is_bond_hidden_by_user(in_bond_id: int) -> bool:
	if _edit_mode != EditMode.AtomsAndBonds:
		return false
	return super.is_bond_hidden_by_user(in_bond_id)


## Returns the list of bond_ids that are not hidden in the structure
func get_visible_bonds() -> PackedInt32Array:
	if _edit_mode != EditMode.AtomsAndBonds:
		return []
	return super.get_visible_bonds()


## Returns number of bonds that has been created in this NanoStructure
## and have not been removed.
func get_valid_bonds_count() -> int:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	
	if _edit_mode != EditMode.AtomsAndBonds:
		return 0
	
	if _bonds_count_cache == -1:
		const GLUE_BOND = 1
		var base_count: Dictionary[String, int] = {
			"A" : DnaBuilder.get_template_bond_count("A", _parameters.include_hydrogens) + GLUE_BOND,
			"T" : DnaBuilder.get_template_bond_count("T", _parameters.include_hydrogens) + GLUE_BOND,
			"G" : DnaBuilder.get_template_bond_count("G", _parameters.include_hydrogens) + GLUE_BOND,
			"C" : DnaBuilder.get_template_bond_count("C", _parameters.include_hydrogens) + GLUE_BOND,
			"X" : 0,
			"B" : DnaBuilder.get_template_bond_count("backbone0", _parameters.include_hydrogens)
		}
		_bonds_count_cache = (base_count["B"] + GLUE_BOND) * _sequence.length() - GLUE_BOND
		if get_strand_policy() == StrandPolicy.DOUBLE:
			# account for both backbones
			_bonds_count_cache *= 2
		for base in _sequence:
			if get_strand_policy() in [StrandPolicy.A, StrandPolicy.DOUBLE]:
				_bonds_count_cache += base_count[base]
			if get_strand_policy() in [StrandPolicy.B, StrandPolicy.DOUBLE]:
				_bonds_count_cache += base_count[DnaBuilder.DNA_COMPLEMENT.get(base, "X")]
	return _bonds_count_cache


## Returns bond information in form of Vector3i
## x component: ID of the first atom participating in bond
## y component: ID of the second atom participating in bond
## z component: bond order
func get_bond(in_bond_id: int) -> Vector3i:
	assert(not _is_being_edited, "I'm being edited, performing operations on bonds in this state is unrecommended")
	
	if _edit_mode != EditMode.AtomsAndBonds:
		return Vector3i(INVALID_ATOM_ID, INVALID_ATOM_ID, -1)
	
	if not _bonds_cache.has(in_bond_id):
		var bond_data := Vector3i(-1, -1, -1)
		var id_info: UnpackedBondId = _unpack_bond_id(in_bond_id)
		if id_info.is_backbone:
			var base: String = "backbone1" if id_info.strand == Strand.B else "backbone0"
			var template: PackedMolecule = DnaBuilder.get_template(base, get_include_hydrogens())
			if id_info.is_glue_bond:
				bond_data.x = _get_atom_id(id_info.base_idx - 1, id_info.strand, true, template.next_backbone_atom_id)
				bond_data.y = _get_atom_id(id_info.base_idx, id_info.strand, true, template.previous_backbone_atom_id)
				bond_data.z = 1
			else:
				var template_bond: Vector3i = template.bonds[id_info.sub_bond_id]
				bond_data.x = _get_atom_id(id_info.base_idx, id_info.strand, true, template_bond.x)
				bond_data.y = _get_atom_id(id_info.base_idx, id_info.strand, true, template_bond.y)
				bond_data.z = template_bond.z
		else:
			var base: String = _sequence[id_info.base_idx]
			if id_info.strand == Strand.B:
				base = DnaBuilder.DNA_COMPLEMENT.get(base, "X")
			var template: PackedMolecule = DnaBuilder.get_template(base, get_include_hydrogens())
			if id_info.is_glue_bond:
				var backbone: String = "backbone1" if id_info.strand == Strand.B else "backbone0"
				var backbone_template: PackedMolecule = DnaBuilder.get_template(backbone, get_include_hydrogens())
				bond_data.x = _get_atom_id(id_info.base_idx, id_info.strand, false, template.base_to_backbone_atom_id)
				bond_data.y = _get_atom_id(id_info.base_idx, id_info.strand, true, backbone_template.base_to_backbone_atom_id)
				bond_data.z = 1
			else:
				var template_bond: Vector3i = template.bonds[id_info.sub_bond_id]
				bond_data.x = _get_atom_id(id_info.base_idx, id_info.strand, false, template_bond.x)
				bond_data.y = _get_atom_id(id_info.base_idx, id_info.strand, false, template_bond.y)
				bond_data.z = template_bond.z
		_bonds_cache[in_bond_id] = bond_data
	return _bonds_cache[in_bond_id]


## Sets the bond order
func bond_set_order(_in_bond_id: int, _in_bond_order: int) -> void:
	assert(false, "Dna Structure cannot modify bonds")
	return


func _get_atom_data(in_atom_id: int, in_to_update_data: bool = false) -> AtomData:
	assert(in_to_update_data == _is_being_edited, "Invalid operation at this moment, information can only be "
			+ ("UPDATED" if _is_being_edited else "READ"))
	assert(is_atom_valid(in_atom_id), "This atom does not belong to the structure")
	if not _atoms_cache.has(in_atom_id):
		_atoms_cache[in_atom_id] = AtomData.new(_unpack_atom_id(in_atom_id), self)
	return _atoms_cache[in_atom_id]


static func _unpack_atom_id(in_atom_id: int) -> UnpackedAtomId:
	if not _unpacked_atom_ids.has(in_atom_id):
		_unpacked_atom_ids[in_atom_id] = UnpackedAtomId.new(in_atom_id)
	return _unpacked_atom_ids[in_atom_id]


static func _get_atom_id(in_base_idx: int, in_strand: Strand, in_is_backbone: bool, in_sub_atom_id: int) -> int:
	var atom_id: int = in_base_idx * 100
	if in_strand == Strand.B:
		atom_id += 50
	if in_is_backbone:
		atom_id += 20
	atom_id += in_sub_atom_id
	return atom_id


func _get_base_template_for_unpacked_atom(in_packed: UnpackedAtomId) -> PackedMolecule:
	assert(in_packed.base_idx >= 0 and in_packed.base_idx < _sequence.length(), "Base index out of range")
	assert(in_packed.strand in get_strands(), "This structure doesn't have %s strand" % Strand.find_key(in_packed.strand))
	var base: String = "backbone0" if in_packed.is_backbone else _sequence[in_packed.base_idx]
	if in_packed.strand == Strand.B:
		base = "backbone1" if in_packed.is_backbone else DnaBuilder.DNA_COMPLEMENT.get(base, "X")
	return DnaBuilder.get_template(base, get_include_hydrogens())


func _get_base_template_for_unpacked_bond(in_packed: UnpackedBondId) -> PackedMolecule:
	assert(in_packed.base_idx >= 0 and in_packed.base_idx < _sequence.length(), "Base index out of range")
	assert(in_packed.strand in get_strands(), "This structure doesn't have %s strand" % Strand.find_key(in_packed.strand))
	var base: String = "backbone0" if in_packed.is_backbone else _sequence[in_packed.base_idx]
	if in_packed.strand == Strand.B:
		base = "backbone1" if in_packed.is_backbone else DnaBuilder.DNA_COMPLEMENT.get(base, "X")
	return DnaBuilder.get_template(base, get_include_hydrogens())


static func _unpack_bond_id(in_bond_id: int) -> UnpackedBondId:
	if not _unpacked_bond_ids.has(in_bond_id):
		_unpacked_bond_ids[in_bond_id] = UnpackedBondId.new(in_bond_id)
	return _unpacked_bond_ids[in_bond_id]


static func _get_bond_id(in_base_idx: int, in_strand: Strand, in_is_backbone: bool, in_sub_bond_id: int) -> int:
	var bond_id: int = in_base_idx * 100
	if in_strand == Strand.B:
		bond_id += 50
	if in_is_backbone:
		bond_id += 20
	bond_id += in_sub_bond_id
	return bond_id


static func _get_glue_bond_id(in_base_idx: int, in_strand: Strand, in_is_backbone_to_backbone: bool) -> int:
	var bond_id: int = in_base_idx * 100
	bond_id += 95 if in_strand == Strand.B else 90
	if in_is_backbone_to_backbone:
		bond_id += 1
	return bond_id


static func _is_glue_bond_id(in_bond_id: int) -> bool:
	var base_idx: int = floori(in_bond_id / 100.0)
	in_bond_id -= base_idx * 100
	return in_bond_id >= 90

#endregion: Atoms and Bonds


#region: Anchors and Springs
func spring_create(in_anchor_id: int, in_atom_id: int, in_spring_constant_force: float,
			is_equilibrium_length_automatic: bool, in_equilibrium_manual_length: float) -> int:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(_edit_mode == EditMode.AtomsAndBonds, "Cannot edit springs in this mode")
	_highest_spring_id += 1
	_springs[_highest_spring_id] = NanoSpring.create(in_anchor_id, in_atom_id, in_spring_constant_force,
			is_equilibrium_length_automatic, in_equilibrium_manual_length)
	_signal_queue_springs_added.append(_highest_spring_id)
	var workspace: Workspace = MolecularEditorContext.find_workspace_possessing_structure(self)
	var anchor: NanoVirtualAnchor = workspace.get_structure_by_int_guid(in_anchor_id)
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
	if _edit_mode == EditMode.SequenceAndPath:
		return true
	return _springs.has(in_spring_id)


func spring_invalidate(in_spring_id: int) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(_edit_mode == EditMode.AtomsAndBonds, "Cannot edit springs in this mode")
	var atom_id: int = spring_get_atom_id(in_spring_id)
	var anchor_id: int = spring_get_anchor_id(in_spring_id)
	_atoms_to_related_springs[atom_id].erase(in_spring_id)
	_springs.erase(in_spring_id)
	_signal_queue_springs_moved.erase(in_spring_id)
	var workspace: Workspace = MolecularEditorContext.find_workspace_possessing_structure(self)
	var anchor: NanoVirtualAnchor = workspace.get_structure_by_int_guid(anchor_id)
	anchor.handle_spring_removed(self, in_spring_id)
	
	var is_still_linked_to_anchor: bool = anchor.is_structure_related(int_guid)
	if not is_still_linked_to_anchor:
		if anchor.position_changed.is_connected(_on_anchor_position_change):
			anchor.position_changed.disconnect(_on_anchor_position_change)
		if anchor.visibility_changed.is_connected(_on_anchor_visibility_changed):
			anchor.visibility_changed.disconnect(_on_anchor_visibility_changed)
	_signal_queue_springs_removed.append(in_spring_id)


func spring_is_visible(in_spring_id: int) -> bool:
	var spring: NanoSpring = _springs[in_spring_id]
	if not spring.anchor_is_visible:
		return false
	return super.spring_is_visible(in_spring_id)


func spring_get_atom_id(in_spring_id: int) -> int:
	if _edit_mode == EditMode.SequenceAndPath:
		return INVALID_ATOM_ID
	return _springs[in_spring_id].target_atom


func spring_get_atom_position(in_spring_id: int) -> Vector3:
	if _edit_mode == EditMode.SequenceAndPath:
		return Vector3()
	var spring: NanoSpring = _springs[in_spring_id]
	return atom_get_position(spring.target_atom)


func spring_get_anchor_id(in_spring_id: int) -> int:
	if _edit_mode == EditMode.SequenceAndPath:
		return -1
	var spring: NanoSpring = _springs[in_spring_id]
	return spring.target_anchor


func spring_get_anchor_position(in_spring_id: int, in_parent_context: StructureContext) -> Vector3:
	if _edit_mode == EditMode.SequenceAndPath:
		return Vector3()
	assert(in_parent_context.nano_structure == self, "This method expects parent StructureContext")
	var anchor_id: int = in_parent_context.nano_structure.spring_get_anchor_id(in_spring_id)
	var workspace: Workspace = in_parent_context.workspace_context.workspace
	var anchor: NanoVirtualAnchor = workspace.get_structure_by_int_guid(anchor_id) as NanoVirtualAnchor
	return anchor.get_position()


func spring_get_equilibrium_length_is_auto(in_spring_id: int) -> bool:
	if _edit_mode == EditMode.SequenceAndPath:
		return false
	var spring: NanoSpring = _springs[in_spring_id]
	return spring.equilibrium_length_is_auto


func spring_set_equilibrium_lenght_is_auto(in_spring_id: int, in_is_auto: bool) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(_edit_mode == EditMode.AtomsAndBonds, "Cannot edit springs in this mode")
	var spring: NanoSpring = _springs[in_spring_id]
	spring.equilibrium_length_is_auto = in_is_auto


func spring_set_equilibrium_manual_length(in_spring_id: int, new_equilibrium_manual_length: float) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(_edit_mode == EditMode.AtomsAndBonds, "Cannot edit springs in this mode")
	var spring: NanoSpring = _springs[in_spring_id]
	spring.equilibrium_manual_length = new_equilibrium_manual_length


func spring_get_equilibrium_manual_length(in_spring_id: int) -> float:
	if _edit_mode == EditMode.SequenceAndPath:
		return 0
	var spring: NanoSpring = _springs[in_spring_id]
	return spring.equilibrium_manual_length


func spring_calculate_equilibrium_auto_length(in_spring_id: int, _in_parent_context: StructureContext) -> float:
	if _edit_mode == EditMode.SequenceAndPath:
		return 0
	var begin: Vector3 = spring_get_atom_position(in_spring_id)
	var end: Vector3 = spring_get_anchor_position(in_spring_id, _in_parent_context)
	var length: float = begin.distance_to(end)
	return length


func spring_get_constant_force(in_spring_id: int) -> float:
	if _edit_mode == EditMode.SequenceAndPath:
		return 0
	var spring: NanoSpring = _springs[in_spring_id]
	return spring.constant_force


func spring_set_constant_force(in_spring_id: int, new_force: float) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(_edit_mode == EditMode.AtomsAndBonds, "Cannot edit springs in this mode")
	var spring: NanoSpring = _springs[in_spring_id]
	spring.constant_force = new_force


func springs_get_all() -> PackedInt32Array:
	if _edit_mode == EditMode.SequenceAndPath:
		return PackedInt32Array()
	return PackedInt32Array(_springs.keys())


func springs_get_valid() -> PackedInt32Array:
	if _edit_mode == EditMode.SequenceAndPath:
		return PackedInt32Array()
	return PackedInt32Array(_springs.keys())


func springs_count() -> int:
	if _edit_mode == EditMode.SequenceAndPath:
		return 0
	return _springs.size()



func atom_get_springs(in_atom_id: int) -> PackedInt32Array:
	if _edit_mode == EditMode.SequenceAndPath:
		return PackedInt32Array()
	if _atoms_to_related_springs.has(in_atom_id):
		return PackedInt32Array(_atoms_to_related_springs[in_atom_id].keys())
	return PackedInt32Array()
#endregion: Anchors and Strings


#region: Virtual Motors
func _set_connected_motor(in_motor_id: int) -> void:
	if !_initialized:
		#during initialization do not emit signals
		connected_motor = in_motor_id
		return
	# disabled since we are now working on snapshots, this probably should not have any setter anymore
	#assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	connected_motor = in_motor_id
	_motor_links.clear()
	_signal_queue_motor_links_changed = get_valid_atoms() ## all atoms where changed


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


func motor_links_count() -> int:
	if connected_motor != 0:
		return get_valid_atoms_count()
	return _motor_links.size()


func motor_links_get_all() -> Dictionary: # { atom_id<int> = motor_id<int> }
	if connected_motor != 0:
		var motor_links: Dictionary = {}
		for atom_id: int in get_valid_atoms():
			motor_links[atom_id] = connected_motor
		return motor_links
	return _motor_links.duplicate()


func atom_set_motor_link(in_atom_id: int, out_motor_context: StructureContext) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(_edit_mode == EditMode.AtomsAndBonds, "Atoms and Bonds cannot be edited in this mode")
	assert(is_instance_valid(out_motor_context) and out_motor_context.nano_structure is NanoVirtualMotor,
			"Invalid motor target for creating a link")
	assert(connected_motor == 0, "Linking a particual atom when the entire structure is connected is not possible")
	assert(is_atom_valid(in_atom_id), "Invalid atom ID")
	var motor_id: int = out_motor_context.nano_structure.int_guid
	if _motor_links.get(in_atom_id, 0) == motor_id:
		# Nothin to do here
		return
	_signal_queue_motor_links_changed.push_back(in_atom_id)
	_motor_links[in_atom_id] = motor_id


func atom_clear_motor_link(in_atom_id: int) -> void:
	assert(_is_being_edited, "To perform any changes to AtomicStructure you need to put it in edit mode by calling start_edit()")
	assert(_edit_mode == EditMode.AtomsAndBonds, "Atoms and Bonds cannot be edited in this mode")
	assert(connected_motor == 0, "Disconnecting a particular atom when the entire structure is connected is not possible")
	assert(is_atom_valid(in_atom_id), "Invalid atom ID")
	if _motor_links.has(in_atom_id):
		_motor_links.erase(in_atom_id)
		_signal_queue_motor_links_changed.push_back(in_atom_id)


func atom_has_motor_link(in_atom_id: int) -> bool:
	if connected_motor != 0:
		return true
	return _motor_links.has(in_atom_id)


#endregion

func get_type() -> StringName:
	return &"DnaStructure"


func get_readable_type() -> String:
	return "DNA Chain"


func get_tooltip_text() -> String:
	var length: float = _sequence.length()
	var sufix: String = "bp" if _parameters.strand_policy == StrandPolicy.DOUBLE else "b"
	if length >= 1000000:
		length = length / 1000000
		sufix = "M" + sufix
	elif length > 1000:
		length = length / 1000
		sufix = "K" + sufix
	if sufix in ["bp", "b"]:
		return "%.0f %s" % [length, sufix]
	else:
		return "%.3f %s" % [length, sufix]


func get_icon() -> Texture2D:
	return null


func get_aabb(in_bounds_type := AABB_BoundsType.AtomsPositions) -> AABB:
	if _edit_mode == EditMode.AtomsAndBonds:
		var aabb: AABB = AABB()
		if get_valid_atoms_count() == 0:
			return aabb
		var elements_radius: Dictionary[int, float]
		var is_first: bool = true
		for atom_id: int in get_valid_atoms():
			var atom: AtomData = _get_atom_data(atom_id)
			var atom_aabb := AABB(atom.position, Vector3.ZERO)
			if in_bounds_type != AABB_BoundsType.AtomsPositions and not atom.atomic_number in elements_radius:
				var element_data: ElementData = PeriodicTable.get_by_atomic_number(atom.atomic_number)
				match in_bounds_type:
					AABB_BoundsType.VisualRadius:
						elements_radius[atom.atomic_number] = (
							Representation.get_atom_radius(element_data, get_representation_settings()) \
							* Representation.get_atom_scale_factor(get_representation_settings())
						)
					AABB_BoundsType.CovalentRadius:
						elements_radius[atom.atomic_number] = element_data.covalent_radius[1]
					AABB_BoundsType.ContactRadius:
						elements_radius[atom.atomic_number] = element_data.contact_radius
			atom_aabb = atom_aabb.grow(elements_radius.get(atom.atomic_number, 0.0)).abs()
			if is_first:
				aabb = atom_aabb
				is_first = false
			else:
				aabb = aabb.expand(atom_aabb.position)
				aabb = aabb.expand(atom_aabb.end)
		return aabb.abs()
	else:
		if _curve.point_count == 0:
			return AABB()
		var aabb := AABB(_curve.get_point_position(0), Vector3.ZERO)
		for p in range(1, _curve.point_count):
			aabb = aabb.expand(_curve.get_point_position(p))
		aabb = aabb.grow(_parameters.dna_radius_nanometers)
		return aabb


func is_spline_within_screen_rect(in_camera: Camera3D, screen_rect: Rect2i) -> bool:
	for p: int in get_control_point_count():
		var point_2d: Vector2 = in_camera.unproject_position(get_control_point_position(p))
		if not screen_rect.abs().has_point(point_2d):
			return false
	return true





func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = super.create_state_snapshot()
	
	var springs_dump: Dictionary = {}
	for spring_id: int in _springs:
		var spring: NanoSpring = _springs[spring_id]
		springs_dump[spring_id] = spring.duplicate()

	state_snapshot["script.resource_path"] = get_script().resource_path
	state_snapshot["_edit_mode"] = _edit_mode
	state_snapshot["_curve"] = _create_curve_snapshot()
	state_snapshot["_twists_offset_radians"] = _twists_offset_radians
	state_snapshot["_sequence"] = _sequence
	state_snapshot["_parameters"] = _parameters.create_state_snapshot()
	state_snapshot["_base_transform_cache"] = _base_transform_cache.duplicate()
	state_snapshot["_atoms_count_cache"] = _atoms_count_cache
	state_snapshot["_atoms_ids_cache"] = _atoms_ids_cache.duplicate()
	state_snapshot["_springs"] = springs_dump
	state_snapshot["_highest_spring_id"] = _highest_spring_id
	var atom_cache_state: Dictionary = {}
	for id: int in _atoms_cache.keys():
		atom_cache_state[id] = AtomData.to_state(_atoms_cache[id])
	state_snapshot["_atoms_cache"] = atom_cache_state
	state_snapshot["_bonds_count_cache"] = _bonds_count_cache
	state_snapshot["_bonds_ids_cache"] = _bonds_ids_cache.duplicate()
	state_snapshot["_bonds_cache"] = _bonds_cache.duplicate()
	state_snapshot["_baked_path"] = _baked_path.duplicate()
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_edit_mode = in_state_snapshot["_edit_mode"]
	_set_curve_snapshot(in_state_snapshot["_curve"])
	_twists_offset_radians = in_state_snapshot["_twists_offset_radians"]
	_sequence = in_state_snapshot["_sequence"]
	_parameters.apply_state_snapshot(in_state_snapshot["_parameters"])
	_base_transform_cache = in_state_snapshot["_base_transform_cache"].duplicate()
	_atoms_count_cache = in_state_snapshot["_atoms_count_cache"]
	_atoms_ids_cache = in_state_snapshot["_atoms_ids_cache"].duplicate()
	_atoms_cache = {}
	for id: int in in_state_snapshot["_atoms_cache"].keys():
		_atoms_cache[id] = AtomData.from_state(in_state_snapshot["_atoms_cache"][id])
	_bonds_count_cache = in_state_snapshot["_bonds_count_cache"]
	_bonds_ids_cache = in_state_snapshot["_bonds_ids_cache"].duplicate()
	_bonds_cache = in_state_snapshot["_bonds_cache"].duplicate()
	_baked_path = in_state_snapshot["_baked_path"].duplicate()
	
	_springs.clear()
	var springs_to_apply: Dictionary = in_state_snapshot["_springs"]
	for spring_id: int in springs_to_apply:
		var spring: NanoSpring = springs_to_apply[spring_id].duplicate()
		_springs[spring_id] = spring
	_highest_spring_id = in_state_snapshot["_highest_spring_id"]
	
	super.apply_state_snapshot(in_state_snapshot)


func _create_curve_snapshot() -> PackedVector3Array:
	var snapshot: PackedVector3Array = []
	for p in _curve.point_count:
		snapshot.append(_curve.get_point_position(p))
		snapshot.append(_curve.get_point_in(p))
		snapshot.append(_curve.get_point_out(p))
	return snapshot


func _set_curve_snapshot(in_curve_snapshot: PackedVector3Array) -> void:
	_curve.set_block_signals(true)
	assert(in_curve_snapshot.size() % 3 == 0, "Invalid size of curve snapshot, expected 3 vectors per curve point")
	_curve.point_count = roundi(in_curve_snapshot.size() / 3.0)
	for p in range(0, in_curve_snapshot.size(), 3):
		var idx: int = roundi(p / 3.0)
		_curve.set_point_position(idx, in_curve_snapshot[p])
		_curve.set_point_in(idx, in_curve_snapshot[p + 1])
		_curve.set_point_out(idx, in_curve_snapshot[p + 2])
	_curve.set_block_signals(false)


class UnpackedAtomId:
	var original_id: int = 0
	var base_idx: int = 0
	var strand: Strand = Strand.A
	var is_backbone: bool = false
	var sub_atom_id: int = 0
	var _read_only: bool = false
	func _init(atom_id: int) -> void:
		original_id = atom_id
		base_idx = floori(atom_id / 100.0)
		atom_id -= base_idx * 100
		if atom_id >= 50:
			strand = Strand.B
			atom_id -= 50
		if atom_id >= 20:
			is_backbone = true
			atom_id -= 20
		sub_atom_id = atom_id
		assert(DnaStructure._get_atom_id(base_idx, strand, is_backbone, sub_atom_id) == original_id,
			"Failed to unpack atom id %d" % original_id)
		_read_only = true
	func _set(property: StringName, _value: Variant) -> bool:
		if _read_only and property in [&"original_id", &"base_idx", &"strand", &"is_backbone", &"sub_atom_id"]:
			if OS.is_debug_build():
				assert(false, "Attempted to change value '%s' in read only DnaStructure.UnpackedAtomId object" % property)
				pass
			else:
				push_error("Attempted to change value '%s' in read only DnaStructure.UnpackedAtomId object" % property)
			return true
		return false

class UnpackedBondId:
	var original_id: int = 0
	var base_idx: int = 0
	var strand: Strand = Strand.A
	var is_backbone: bool = false
	var is_glue_bond: bool = false
	var sub_bond_id: int = 0
	var _read_only: bool = false
	func _init(in_bond_id: int) -> void:
		original_id = in_bond_id
		is_glue_bond = DnaStructure._is_glue_bond_id(in_bond_id)
		base_idx = floori(in_bond_id / 100.0)
		in_bond_id -= base_idx * 100
		if is_glue_bond:
			if in_bond_id >= 95:
				strand = Strand.B
				in_bond_id -= 95
			else:
				strand = Strand.A
				in_bond_id -= 90
			assert(in_bond_id in [0, 1], "Unexpected bond id!")
			var is_backbone_to_backbone_glue: bool = in_bond_id == 1
			is_backbone = is_backbone_to_backbone_glue
			assert(DnaStructure._get_glue_bond_id(base_idx, strand, is_backbone_to_backbone_glue) == original_id,
				"Failed to unpack bond id %d" % original_id)
		else:
			if in_bond_id >= 50:
				strand = Strand.B
				in_bond_id -= 50
			if in_bond_id >= 20:
				is_backbone = true
				in_bond_id -= 20
			sub_bond_id = in_bond_id
			assert(DnaStructure._get_bond_id(base_idx, strand, is_backbone, sub_bond_id) == original_id,
				"Failed to unpack bond id %d" % original_id)
		_read_only = true
	func _set(property: StringName, _value: Variant) -> bool:
		if _read_only and property in [&"original_id", &"base_idx", &"strand", &"is_backbone", &"is_glue_bond", &"is_backbone_to_backbone_glue", &"sub_bond_id"]:
			if OS.is_debug_build():
				assert(false, "Attempted to change value '%s' in read only DnaStructure.UnpackedBondId object" % property)
				pass
			else:
				push_error("Attempted to change value '%s' in read only DnaStructure.UnpackedBondId object" % property)
			return true
		return false


class AtomData:
	var atomic_number: int =  PeriodicTable.INVALID_ATOMIC_NUMBER
	var position: Vector3
	
	func _init(id_data: UnpackedAtomId, owner: DnaStructure) -> void:
		if id_data == null and owner == null:
			# Assume reconstructing cache
			return
		var base: String
		if id_data.is_backbone:
			base = "backbone0" if id_data.strand == Strand.A else "backbone1"
		else:
			base = owner.get_sequence()[id_data.base_idx]
			if id_data.strand == Strand.B:
				base = DnaBuilder.DNA_COMPLEMENT.get(base, "X")
		if base == "X":
			assert(false, "Invalid atom ID %d" % id_data.original_id)
			return
		var base_template: PackedMolecule = DnaBuilder.get_template(base, owner.get_include_hydrogens())
		assert(id_data.sub_atom_id < base_template.atoms.size(),
			"Invalid atom ID %d (sub_atom_id = %d)" % [id_data.original_id, id_data.sub_atom_id])
		var atom_info: Vector4 = base_template.atoms[id_data.sub_atom_id]
		atomic_number = int(atom_info.w)
		position = Vector3(atom_info.x, atom_info.y, atom_info.z)
		var xform: Transform3D = (
			owner.get_backbone_transform(id_data.strand, id_data.base_idx)
			if id_data.is_backbone else
			owner.get_base_transform(id_data.strand, id_data.base_idx)
		)
		position = xform * position
	
	
	static func to_state(atom: AtomData) -> Dictionary:
		return {
			atomic_number =  atom.atomic_number,
			position = atom.position
		}
	
	static func from_state(data: Dictionary) -> AtomData:
		var atom := AtomData.new(null, null)
		atom.atomic_number = data.atomic_number
		atom.position = data.position
		return atom

