class_name DnaStructure extends NanoStructure

signal bases_count_changed(new_count: int)
signal sequence_changed(new_sequence: String)
signal path_changed()
signal parameters_changed(read_only_parameters: DnaStructureParameters)

signal atoms_color_override_changed(changed_atoms: PackedInt32Array)

enum Strand {
	A = 1,
	B = 2,
	BOTH = 3,
}
const StrandPolicy = DnaStructureParameters.StrandPolicy
const INVALID_CONTROL_POINT_IDX: int = -1

@export var _curve: Curve3D:
	set = _set_curve
@export var _twists_offset_radians: float
@export var _sequence: String
@export var _parameters: DnaStructureParameters
@export var _color_overrides: Dictionary[int, Color] = {}

# Atoms and Bases caches
var _base_transform_cache: Dictionary[int, Transform3D]
var _atoms_count_cache: int = -1
var _atoms_ids_cache: Dictionary[Strand, PackedInt32Array] = {}
var _atoms_cache: Dictionary[int, AtomData] = {}
var _bonds_count_cache: int = -1
var _bonds_ids_cache: Dictionary[Strand, PackedInt32Array] = {}
var _bonds_cache: Dictionary[int, Vector3i]
static var _unpacked_atom_ids: Dictionary[int, UnpackedAtomId]
static var _unpacked_bond_ids: Dictionary[int, UnpackedBondId]

var _is_being_edited: bool = false
var _last_sequence: String = ""
var _last_bases_cout: int = 0
var _signal_queue_path_changed: bool = false
var _signal_queue_parameters_changed: bool = false
var _signal_queue_atoms_color_changed: PackedInt32Array = []
var _baked_path: PackedVector3Array = []

static func create(out_parameters: DnaStructureParameters, in_sequence: String = "") -> DnaStructure:
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
		_curve.bake_interval = 0.02


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
		var total_length: float = get_rise_nanometers() * (_sequence.length() - 1)
		if curve.get_baked_length() < total_length:
			var last_pos: Vector3 = baked_path[-1]
			var z_dir: Vector3 = baked_path[-2].direction_to(last_pos)
			var remaining_distance: float = total_length - curve.get_baked_length()
			var final_pos: Vector3 = last_pos + z_dir * remaining_distance
			baked_path.append(final_pos)
		if in_path_override == null:
			_baked_path = baked_path
		else:
			return baked_path
	return _baked_path.duplicate()


#region: Edit tracking
func start_edit() -> void:
	assert(not _is_being_edited, "I'm already being edited, make sure to call end_edit() when you are done with edits")
	_is_being_edited = true
	_last_bases_cout = _sequence.length()
	_last_sequence = _sequence
	_atoms_count_cache = -1
	_atoms_ids_cache = {}
	_atoms_cache = {}
	_bonds_count_cache = -1
	_bonds_ids_cache = {}
	_bonds_cache = {}
	return


func is_being_edited() -> bool:
	return _is_being_edited


func end_edit() -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	_is_being_edited = false
	_atoms_count_cache = -1
	_atoms_ids_cache = {}
	_atoms_cache = {}
	_bonds_count_cache = -1
	_bonds_ids_cache = {}
	_bonds_cache = {}
	
	var has_changed: bool = (
		_last_bases_cout != _sequence.length()
		or _last_sequence != _sequence
		or _signal_queue_path_changed
		or _signal_queue_parameters_changed
		or not _signal_queue_atoms_color_changed.is_empty()
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
			_baked_path.clear()
			sequence_changed.emit(_sequence)
		if _signal_queue_parameters_changed:
			_baked_path.clear()
			_parameters.set_read_only(true)
			parameters_changed.emit(_parameters)
			_parameters.set_read_only(false)
			_signal_queue_parameters_changed = false
		if not _signal_queue_atoms_color_changed.is_empty():
			atoms_color_override_changed.emit(_signal_queue_atoms_color_changed)
			_signal_queue_atoms_color_changed = []
		emit_changed()
#endregion: Edit tracking


#region: Parameters
func set_bases_per_turn(in_bases_per_turn: float) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	_signal_queue_parameters_changed = true
	_parameters.bases_per_turn = in_bases_per_turn


func get_bases_per_turn() -> float:
	return _parameters.bases_per_turn


func set_rise_nanometers(in_rise_nanometers: float) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	_signal_queue_parameters_changed = true
	_parameters.rise_nanometers = in_rise_nanometers
	_adjust_sequence_to_path_length()


func get_rise_nanometers() -> float:
	return _parameters.rise_nanometers


func set_dna_radius_nanometers(in_radius_nanometers: float) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	_signal_queue_parameters_changed = true
	_parameters.dna_radius_nanometers = in_radius_nanometers


func get_dna_radius_nanometers() -> float:
	return _parameters.dna_radius_nanometers


func set_initial_twist_rad(in_initial_twist_rad: float) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	_signal_queue_parameters_changed = true
	_parameters.initial_twist_rad = in_initial_twist_rad


func get_initial_twist_rad() -> float:
	return _parameters.initial_twist_rad


func set_strand_policy(in_strand_policy: StrandPolicy) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
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
	_curve.add_point(position, Vector3.ZERO, Vector3.ZERO, in_index)
	var index: int = in_index if in_index > -1 else _curve.point_count - 1
	recalculate_curve_in_out(_curve, index - 1)
	recalculate_curve_in_out(_curve, index)
	recalculate_curve_in_out(_curve, index + 1)


func remove_control_point(in_index: int) -> void:
	assert(_is_being_edited)
	_curve.remove_point(in_index)
	if in_index > 0:
		recalculate_curve_in_out(_curve, in_index - 1)
	if in_index < _curve.point_count:
		recalculate_curve_in_out(_curve, in_index)


func is_control_point_valid(in_index: int) -> bool:
	return in_index >= 0 and in_index < _curve.point_count


func set_control_point_position(in_index: int, int_position: Vector3) -> void:
	assert(_is_being_edited)
	_curve.set_point_position(in_index, int_position)
	recalculate_curve_in_out(_curve, in_index - 1)
	recalculate_curve_in_out(_curve, in_index)
	recalculate_curve_in_out(_curve, in_index + 1)


func get_control_point_count() -> int:
	return _curve.point_count


func get_control_point_position(in_index: int) -> Vector3:
	return _curve.get_point_position(in_index)


func get_path_length() -> float:
	# This is obtained from the Path3D
	return _curve.get_baked_length()


func create_path3d() -> Path3D:
	var path := Path3D.new()
	path.curve = _curve
	return path



func get_base_transform(in_strand: Strand, in_base_index: int) -> Transform3D:
	var cache_index: int = (in_base_index + 1) * (-1 if in_strand == Strand.B else 1)
	assert(cache_index != 0, "Invalid cache_index 0 (since cannot be distinguished for A and B strand)")
	if not cache_index in _base_transform_cache:
		var at_pos: float = in_base_index * _parameters.rise_nanometers
		var y_dir := Vector3.ZERO
		var z_dir := Vector3.ZERO
		var path_pos: Vector3
		var points: PackedVector3Array = get_baked_path()
		if at_pos > _curve.get_baked_length():
			# Sequence is longer than the curve, continue in a straight length
			var last_pos: Vector3 = points[-1]
			z_dir = points[-2].direction_to(last_pos)
			var remaining_distance: float = at_pos - _curve.get_baked_length()
			path_pos = last_pos + z_dir * remaining_distance
			y_dir = _curve.get_baked_up_vectors()[-1]
		else:
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
			# TODO: Adjust path pos interpolating points[point_idx - 1] to points[point_idx]
			path_pos = curr_pos
			z_dir = points[point_idx].direction_to(points[point_idx + 1])
			y_dir = _curve.get_baked_up_vectors()[point_idx]
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
	if _sequence != in_sequence:
		_sequence = in_sequence
		_adjust_sequence_to_path_length()


func get_sequence() -> String:
	return _sequence


func _adjust_sequence_to_path_length() -> void:
	var expected_sequence_length: int = floori(get_path_length() / _parameters.rise_nanometers)
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
## Returns number of atoms that has been created in this NanoStructure
func get_valid_atoms_count() -> int:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
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
				_atoms_count_cache += base_count[DnaBuilder.DNA_COMPLEMENT[base]]
	return _atoms_count_cache


func get_atom_ids_for_strand(in_strand: Strand) -> PackedInt32Array:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	assert(in_strand != Strand.BOTH, "Invalid usage of get_atoms_for_strand, use get_valid_atoms() instead")
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
	if not _atoms_ids_cache.get(Strand.BOTH, []).is_empty():
		return _atoms_ids_cache[Strand.BOTH]
	
	_atoms_ids_cache[Strand.BOTH] = PackedInt32Array()
	for strand: Strand in get_strands():
		_atoms_ids_cache[Strand.BOTH].append_array(get_atom_ids_for_strand(strand))
	return _atoms_ids_cache[Strand.BOTH]


## Returns wether the atom should be rendered and/or mouse picked
func is_atom_visible(in_atom_id: int) -> bool:
	if is_atom_hidden_by_user(in_atom_id):
		return false
	if not are_hydrogens_visible() and atom_get_atomic_number(in_atom_id) == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
		return false
	return true


## Returns true if the atom is explicitely hidden with the "Hide Selected" action.
## Unlike is_atom_visible(), this method does not consider the hydrogen rendering state.
func is_atom_hidden_by_user(_in_atom_id: int) -> bool:
	# TODO: Support hide and show atoms
	return false #hidden_atoms.get(in_atom_id, false)


## Returns the list of valid atom_ids that are not hidden
func get_visible_atoms() -> PackedInt32Array:
	# TODO: Support hide and show atoms
	return get_valid_atoms()


## Returns the numbers of protons in atom's nucleous. This reffers to the id of an
## element in the Periodic Table
func atom_get_atomic_number(in_atom_id: int) -> int:
	return _get_atom_data(in_atom_id).atomic_number


## Calculate the [url=https://en.wikipedia.org/wiki/Formal_charge]formal charge[/url] of a given atom
func atom_get_formal_charge(_in_atom_id: int) -> int:
	# TODO: for now assume 0
	return 0


## Returns the position of the atom, relative to structure's transform
func atom_get_position(in_atom_id: int) -> Vector3:
	return _get_atom_data(in_atom_id).position


## Sets the position of a given atom, relative to structure's transform
## Returs true if succeeds or false if something prevents the change
## This is uniquely supported to update atoms positions during simulation
func atom_set_position(in_atom_id: int, in_pos: Vector3) -> bool:
	const TO_UPDATE_POSITION = true
	_get_atom_data(in_atom_id, TO_UPDATE_POSITION).position = in_pos
	return true


## Should be used instead of [code]atom_set_position()[/code] in cases where there is many atoms to move,
## for performance reasons - this way [code]changed[/code] signal is emitted only once
func atoms_set_positions(_in_atoms: PackedInt32Array, _in_positions: PackedVector3Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return



## Returns true if the atom is locked
func atom_is_locked(_in_atom_id: int) -> bool:
	# TBD: could all atoms in a base be locked?
	return false


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
	return PackedInt32Array() # PackedInt32Array(locked_atoms.keys())


## returns IDs of the bonds that given atom is participating in
func atom_get_bonds(_in_atom_id: int) -> PackedInt32Array:
	# TODO
	return PackedInt32Array()


## Returns the ID of the another atom that's participating in in_bond_id
func atom_get_bond_target(_in_atom_id: int, _in_bond_id: int) -> int:
	# TODO
	return AtomicStructure.INVALID_ATOM_ID


## Returns bond id between first atom and second atom or -1 if bond do not exists
func atom_find_bond_between(_in_atom_id_a: int, _in_atom_id_b: int) -> int:
	# TODO
	return -1


func has_color_override(in_atom_id: int) -> bool:
	return _color_overrides.has(in_atom_id)


func get_color_override(in_atom_id: int) -> Color:
	return _color_overrides.get(in_atom_id, null)


func set_color_override(in_atoms: PackedInt32Array, color: Color) -> void:
	assert(_is_being_edited, "Color override can only be changed while structure is being edited")
	for atom_id: int in in_atoms:
		_color_overrides[atom_id] = color
	_signal_queue_atoms_color_changed.append_array(in_atoms)


func get_color_overrides() -> Dictionary:
	return _color_overrides.duplicate()


func remove_color_override(in_atoms: PackedInt32Array) -> void:
	assert(_is_being_edited, "Color override can only be changed while structure is being edited")
	for atom_id: int in in_atoms:
		_color_overrides.erase(atom_id)
	_signal_queue_atoms_color_changed.append_array(in_atoms)


func are_hydrogens_visible() -> bool:
	return _representation_settings.get_ref().get_hydrogens_visible()


func get_bond_ids_for_strand(in_strand: Strand) -> PackedInt32Array:
	assert(not _is_being_edited, "I'm being edited, performing operations on bonds in this state is unrecommended")
	assert(in_strand != Strand.BOTH, "Invalid usage of get_bonds_for_strand, use get_valid_bonds() instead")
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
	if not _bonds_ids_cache.get(Strand.BOTH, []).is_empty():
		return _bonds_ids_cache[Strand.BOTH]
	
	_bonds_ids_cache[Strand.BOTH] = PackedInt32Array()
	for strand: Strand in get_strands():
		_bonds_ids_cache[Strand.BOTH].append_array(get_bond_ids_for_strand(strand))
	return _bonds_ids_cache[Strand.BOTH]


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
	# TODO: Support hiding bonds
	return false # hidden_bonds.get(in_bond_id, false)


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
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	if _bonds_count_cache == -1:
		var base_count: Dictionary[String, int] = {
			"A" : DnaBuilder.get_template_bond_count("A", _parameters.include_hydrogens),
			"T" : DnaBuilder.get_template_bond_count("T", _parameters.include_hydrogens),
			"G" : DnaBuilder.get_template_bond_count("G", _parameters.include_hydrogens),
			"C" : DnaBuilder.get_template_bond_count("C", _parameters.include_hydrogens),
			"X" : 0,
			"B" : DnaBuilder.get_template_bond_count("backbone0", _parameters.include_hydrogens)
		}
		_bonds_count_cache = base_count["B"] * _sequence.length()
		if get_strand_policy() == StrandPolicy.DOUBLE:
			# account for both backbones
			_bonds_count_cache *= 2
		for base in _sequence:
			if get_strand_policy() in [StrandPolicy.A, StrandPolicy.DOUBLE]:
				_bonds_count_cache += base_count[base]
			if get_strand_policy() in [StrandPolicy.B, StrandPolicy.DOUBLE]:
				_bonds_count_cache += base_count[DnaBuilder.DNA_COMPLEMENT[base]]
	return _bonds_count_cache


## Returns bond information in form of Vector3i
## x component: ID of the first atom participating in bond
## y component: ID of the second atom participating in bond
## z component: bond order
func get_bond(in_bond_id: int) -> Vector3i:
	assert(not _is_being_edited, "I'm being edited, performing operations on bonds in this state is unrecommended")
	if not _bonds_cache.has(in_bond_id):
		var bond_data := Vector3i(-1, -1, -1)
		var id_info: UnpackedBondId = _unpack_bond_id(in_bond_id)
		if id_info.is_backbone:
			var base: String = "backbone1" if id_info.strand == Strand.B else "backbone0"
			var template: DnaBuilder.PackedMolecule = DnaBuilder.get_template(base, get_include_hydrogens())
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
			var template: DnaBuilder.PackedMolecule = DnaBuilder.get_template(base, get_include_hydrogens())
			if id_info.is_glue_bond:
				var backbone: String = "backbone1" if id_info.strand == Strand.B else "backbone0"
				var backbone_template: DnaBuilder.PackedMolecule = DnaBuilder.get_template(backbone, get_include_hydrogens())
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
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func bond_is_hydrogen_involved(in_bond_id: int) -> bool:
	var bond_data: Vector3i = get_bond(in_bond_id)
	var is_hydrogen_involved: bool = atom_is_hydrogen(bond_data.x)
	is_hydrogen_involved = is_hydrogen_involved or atom_is_hydrogen(bond_data.y)
	return is_hydrogen_involved


func _get_atom_data(in_atom_id: int, in_to_update_data: bool = false) -> AtomData:
	if not in_to_update_data:
		assert(!_is_being_edited, "Cannot query atom data while structure is being edited, is not safe")
		pass
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


func _get_bond_data(in_bond_id: int) -> Vector3i:
	if not _bonds_cache.has(in_bond_id):
		var bond_data := UnpackedBondId.new(in_bond_id)
		_bonds_cache[in_bond_id]
	return _bonds_cache[in_bond_id]


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

func get_type() -> StringName:
	return &"DnaStructure"


func get_readable_type() -> String:
	return "DNA Structure"


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


func get_aabb() -> AABB:
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
	state_snapshot["script.resource_path"] = get_script().resource_path
	state_snapshot["_curve"] = _create_curve_snapshot()
	state_snapshot["_twists_offset_radians"] = _twists_offset_radians
	state_snapshot["_sequence"] = _sequence
	state_snapshot["_parameters"] = _parameters.create_state_snapshot()
	state_snapshot["_base_transform_cache"] = _base_transform_cache.duplicate()
	state_snapshot["_atoms_count_cache"] = _atoms_count_cache
	state_snapshot["_atoms_ids_cache"] = _atoms_ids_cache.duplicate()
	state_snapshot["_atoms_cache"] = _atoms_cache.duplicate(true)
	state_snapshot["_bonds_count_cache"] = _bonds_count_cache
	state_snapshot["_bonds_ids_cache"] = _bonds_ids_cache.duplicate()
	state_snapshot["_bonds_cache"] = _bonds_cache.duplicate()
	state_snapshot["_baked_path"] = _baked_path.duplicate()
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_set_curve_snapshot(in_state_snapshot["_curve"])
	_twists_offset_radians = in_state_snapshot["_twists_offset_radians"]
	_sequence = in_state_snapshot["_sequence"]
	_parameters.apply_state_snapshot(in_state_snapshot["_parameters"])
	_base_transform_cache = in_state_snapshot["_base_transform_cache"].duplicate()
	_atoms_count_cache = in_state_snapshot["_atoms_count_cache"]
	_atoms_ids_cache = in_state_snapshot["_atoms_ids_cache"].duplicate()
	_atoms_cache = in_state_snapshot["_atoms_cache"].duplicate(true)
	_bonds_count_cache = in_state_snapshot["_bonds_count_cache"]
	_bonds_ids_cache = in_state_snapshot["_bonds_ids_cache"].duplicate()
	_bonds_cache = in_state_snapshot["_bonds_cache"].duplicate()
	_baked_path = in_state_snapshot["_baked_path"].duplicate()
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
		var base_template: DnaBuilder.PackedMolecule = DnaBuilder.get_template(base, owner.get_include_hydrogens())
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

