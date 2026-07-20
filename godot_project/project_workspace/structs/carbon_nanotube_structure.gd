class_name CarbonNanotubeStructure extends AtomicVirtualStructure


const NanotubeRepresentation = RepresentationSettings.NanotubeRepresentation

signal path_changed(from: Vector3, to: Vector3)
signal chiral_indices_changed(n: int, m: int)

@export var _chiral_index_n: int
@export var _chiral_index_m: int
@export var _position_begin: Vector3
@export var _position_end: Vector3
@export var _trim_invalid_valence_carbons: bool = true


var _signal_queue_path_changed: bool

var _last_n: int
var _last_m: int
var _last_trim_invalid_valence_carbons: bool
var _basis: CarbonTubuleBasis
var _template: CarbonTubuleBasis.CrystalCell

var _aabb_cache := AABB()
var _atoms_count_cache: int = -1
var _atoms_ids_cache: PackedInt32Array
var _atoms_cache: Dictionary[int, AtomData] = {}
var _bonds_count_cache: int = -1
var _bonds_ids_cache: PackedInt32Array = []
var _bonds_cache: Dictionary[int, Vector3i] = {}
var _tube_direction: Vector3
static var _unpacked_atom_ids: Dictionary[int, UnpackedAtomId]
static var _unpacked_bond_ids: Dictionary[int, UnpackedBondId]

var _track_atoms: bool = false


static func create_nanotube(n: int, m: int, from_pos: Vector3, to_pos: Vector3, in_trim_invalid_valence_carbons: bool) -> CarbonNanotubeStructure:
	var tube := CarbonNanotubeStructure.new()
	tube._chiral_index_n = n
	tube._chiral_index_m = m
	tube._position_begin = from_pos
	tube._position_end = to_pos
	tube._trim_invalid_valence_carbons = in_trim_invalid_valence_carbons
	tube.start_edit()
	tube._signal_queue_path_changed = true
	tube.end_edit()
	return tube


func set_representation_settings(in_representation_settings: RepresentationSettings) -> void:
	var prev_representation: RepresentationSettings = get_representation_settings()
	if prev_representation != null and prev_representation.dna_representation_changed.is_connected(_on_nanotube_representation_changed):
		prev_representation.nanotube_representation_changed.disconnect(_on_nanotube_representation_changed)
	in_representation_settings.nanotube_representation_changed.connect(_on_nanotube_representation_changed)
	super.set_representation_settings(in_representation_settings)
	_on_nanotube_representation_changed(get_representation_settings().get_nanotube_representation())


func _on_nanotube_representation_changed(in_representation: NanotubeRepresentation) -> void:
	_track_atoms = in_representation == NanotubeRepresentation.ATOMS_AND_BONDS
	var has_valid_state: bool = _chiral_index_n >= 2 and _chiral_index_m >= 0
	if has_valid_state:
		start_edit()
		_signal_queue_path_changed = true
		end_edit()


#region: Parameters
func set_chiral_index_n(in_n: int) -> void:
	assert(_is_being_edited, "Parameters can only be changed while structure is being edited")
	_chiral_index_n = in_n


func get_chiral_index_n() -> int:
	return _chiral_index_n


func set_chiral_index_m(in_m: int) -> void:
	assert(_is_being_edited, "Parameters can only be changed while structure is being edited")
	_chiral_index_m = in_m


func get_chiral_index_m() -> int:
	return _chiral_index_m


func set_trim_invalid_valence_carbons(in_trim: bool) -> void:
	assert(_is_being_edited, "Parameters can only be changed while structure is being edited")
	_trim_invalid_valence_carbons = in_trim


func is_trim_invalid_valence_carbons_enabled() -> bool:
	return _trim_invalid_valence_carbons
#endregion: Parameters


#region: Path
func set_control_point_position(in_index: int, in_position: Vector3) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	assert(in_index >= 0 and in_index < 2, "Invalid control point index")
	if in_index == 0:
		if _position_begin == in_position:
			return
		_position_begin = in_position
	else:
		if _position_end == in_position:
			return
		_position_end = in_position
	_signal_queue_path_changed = true


func get_control_point_count() -> int:
	const CONTROL_POINT_COUNT = 2
	return CONTROL_POINT_COUNT


func get_control_point_position(in_index: int) -> Vector3:
	assert(in_index >= 0 and in_index < 2, "Invalid control point index")
	return _position_begin if in_index == 0 else _position_end


func get_tube_length() -> float:
	return _position_begin.distance_to(_position_end)


func set_tube_length(in_length: float) -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	if _tube_direction == Vector3.ZERO:
		_tube_direction = Vector3.RIGHT
	set_control_point_position(1, _position_begin + _tube_direction.normalized() * in_length)


func get_estimated_diameter() -> float:
	return _basis.get_estimated_diameter()


func get_estimated_circumference() -> float:
	return _basis.get_estimated_circumference()


func get_repetition_count() -> int:
	var tube_length: float = _position_begin.distance_to(_position_end)
	var cell_length: float = _basis.get_translational_vector_length()
	var repeat_count: int = ceili(tube_length / cell_length)
	return repeat_count


func get_repetition_transform(in_repetition_idx: int) -> Transform3D:
	# The cell generates atoms with the tube axis along +Z = Vector3.BACK.
	const CELL_Z_AXIS := Vector3.BACK  # (0, 0, 1)
	var cell_length: float = _basis.get_translational_vector_length()
	
	var axis_rotation := Basis()
	if _tube_direction.is_equal_approx(CELL_Z_AXIS):
		pass  # already aligned, identity rotation
	elif _tube_direction.is_equal_approx(-CELL_Z_AXIS):
		axis_rotation = Basis(Vector3.RIGHT, PI)  # 180 degrees flip
	else:
		var rotation_axis: Vector3 = CELL_Z_AXIS.cross(_tube_direction).normalized()
		var rotation_angle: float = CELL_Z_AXIS.angle_to(_tube_direction)
		axis_rotation = Basis(rotation_axis, rotation_angle)
	
	var repetition_origin: Vector3 = _position_begin + _tube_direction * cell_length * in_repetition_idx
	return Transform3D(axis_rotation, repetition_origin)
#endregion: Path


#region: Edit tracking
func start_edit() -> void:
	assert(not _is_being_edited, "I'm already being edited, make sure to call end_edit() when you are done with edits")
	super.start_edit()
	_last_n = _chiral_index_n
	_last_m = _chiral_index_m
	_last_trim_invalid_valence_carbons = _trim_invalid_valence_carbons
	return


func end_edit() -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	var has_changed: bool = (
		_signal_queue_path_changed
		or _last_n != _chiral_index_n
		or _last_m != _chiral_index_m
		or _last_trim_invalid_valence_carbons != _trim_invalid_valence_carbons
	)
	if has_changed:
		_aabb_cache = AABB()
		if _signal_queue_path_changed:
			_tube_direction = _position_begin.direction_to(_position_end)
			path_changed.emit(_position_begin, _position_end)
			_signal_queue_path_changed = false
		if _template == null or _last_n != _chiral_index_n or _last_m != _chiral_index_m:
			_basis = CarbonTubuleBasis.new(_chiral_index_n, _chiral_index_m)
			_template = _basis.generate()
		if _track_atoms:
			var prev_atoms_cache: Dictionary[int, AtomData] = _atoms_cache.duplicate()
			var prev_bonds_cache: Dictionary[int, Vector3i] = _bonds_cache.duplicate()
			_atoms_count_cache = -1
			_atoms_ids_cache = []
			_atoms_cache = {}
			_bonds_count_cache = -1
			_bonds_ids_cache = []
			_bonds_cache = {}
			# HACK: temporarly set is being edited to false to fetch values
			_is_being_edited = false
			var all_new_atom_ids: PackedInt32Array = get_valid_atoms()
			# Track added/removed/moved atoms
			var all_old_atom_ids: PackedInt32Array = prev_atoms_cache.keys()
			var was_atom_removed: Callable = func (old_atom_id: int) -> bool:
				return not (old_atom_id in all_new_atom_ids)
			var was_atom_added: Callable = func (new_atom_id: int) -> bool:
				return not (new_atom_id in all_old_atom_ids)
			var was_atom_moved: Callable = func (atom_id: int) -> bool:
				if was_atom_added.call(atom_id) or was_atom_removed.call(atom_id):
					return false
				return prev_atoms_cache[atom_id].position != atom_get_position(atom_id)
			_signal_queue_atoms_removed = Array(all_old_atom_ids).filter(was_atom_removed)
			_signal_queue_atoms_added = Array(all_new_atom_ids).filter(was_atom_added)
			_signal_queue_atoms_moved = Array(all_new_atom_ids).filter(was_atom_moved)
			for atom_id in all_new_atom_ids:
				if was_atom_added.call(atom_id) or was_atom_removed.call(atom_id):
					continue
				if prev_atoms_cache[atom_id].atomic_number != atom_get_atomic_number(atom_id):
					_signal_queue_atomic_number_changed.append(Vector2i(atom_id, atom_get_atomic_number(atom_id)))
			# NOTE: prev_atoms_cache.is_empty() means user just started tracking atoms
			# Track Bonds
			var all_new_bonds: PackedInt32Array = get_valid_bonds()
			# Update cache
			for bond_id: int in all_new_bonds:
				_bonds_cache[bond_id] = _get_bond_data(bond_id)
			var all_old_bonds: PackedInt32Array = prev_bonds_cache.keys()
			var was_bond_removed: Callable = func (old_bond_id: int) -> bool:
				return not (old_bond_id in all_new_bonds)
			var was_bond_added: Callable = func(new_bond_id: int) -> bool:
				return not (new_bond_id in all_old_bonds)
			_signal_queue_bonds_created = Array(all_new_bonds).filter(was_bond_added)
			_signal_queue_bonds_removed = Array(all_old_bonds).filter(was_bond_removed)
			# reset is being edited
			_is_being_edited = true
			super.end_edit()
		else:
			var prev_atoms_cache: Dictionary[int, AtomData] = _atoms_cache.duplicate()
			var prev_bonds_cache: Dictionary[int, Vector3i] = _bonds_cache.duplicate()
			_atoms_count_cache = -1
			_atoms_ids_cache = []
			_atoms_cache = {}
			_bonds_count_cache = -1
			_bonds_ids_cache = []
			_bonds_cache = {}
			_signal_queue_atoms_removed = prev_atoms_cache.keys()
			_signal_queue_bonds_removed = prev_bonds_cache.keys()
			super.end_edit()
		if _last_n != _chiral_index_n or _last_m != _chiral_index_m:
			chiral_indices_changed.emit(_chiral_index_n, _chiral_index_m)
		emit_changed()
	else:
		_is_being_edited = false


func is_tracking_atoms() -> bool:
	return _track_atoms


func set_force_track_atoms(in_force_track: bool) -> void:
	# NOTE: This is used exclusively for when converting Object to a group
	if in_force_track:
		if _track_atoms:
			return
		_track_atoms = true
		start_edit()
		_signal_queue_path_changed = true
		end_edit()
	else:
		_atom_to_atom_spring_ids.clear()
		_atoms_to_related_springs.clear()
		var should_track: bool = get_representation_settings().get_nanotube_representation() == NanotubeRepresentation.ATOMS_AND_BONDS
		if should_track == _track_atoms:
			return
		_track_atoms = should_track
		start_edit()
		_signal_queue_path_changed = true
		end_edit()
#region: Edit tracking


#region: Atoms and Bonds
func get_valid_atoms_count() -> int:
	if _atoms_count_cache == -1:
		_atoms_count_cache = get_valid_atoms().size()
	return _atoms_count_cache


func is_atom_valid(in_atom_id: int, check_trimmed: bool = true) -> bool:
	if _track_atoms == false:
		return false
	var unpacked := UnpackedAtomId.new(in_atom_id)
	assert(_template)
	if unpacked.sub_atom_id >= _template.basis.size():
		return false
	if unpacked.repetition_idx >= get_repetition_count():
		return false
	if unpacked.repetition_idx == get_repetition_count() - 1:
		var atom: CarbonTubuleBasis.AtomCoordinate = _template.basis[unpacked.sub_atom_id]
		var z_pos: float = _template.fractional_to_cartesian_position(atom.position).z
		z_pos += _basis.get_translational_vector_length() * unpacked.repetition_idx
		var tube_len_sqrd: float = _position_begin.distance_squared_to(_position_end)
		if z_pos ** 2 > tube_len_sqrd:
			return false
	if check_trimmed and _trim_invalid_valence_carbons and \
			_should_trim_unpacked_atom(unpacked.repetition_idx, unpacked.sub_atom_id):
		return false
	return true


func get_valid_atoms() -> PackedInt32Array:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	
	if not _track_atoms:
		return []
	
	if _atoms_ids_cache.is_empty():
		assert(_template != null)
		# Update cache
		var template_atom_count: int = _template.basis.size()
		var tube_length: float = _position_begin.distance_to(_position_end)
		var cell_length: float = _basis.get_translational_vector_length()
		var repeat_count: int = ceili(tube_length / cell_length)
		
		var atom_exceeds_tube_len: Callable = func(repetition_idx: int, sub_atom_id: int) -> bool:
			if repetition_idx < (repeat_count - 1):
				return false
			var repetition_offset: float = repetition_idx * cell_length
			var z_pos: float = _template.basis[sub_atom_id].position.z * cell_length
			return repetition_offset + z_pos > tube_length
		for repetition_idx: int in repeat_count:
			for sub_atom_id: int in template_atom_count:
				if atom_exceeds_tube_len.call(repetition_idx, sub_atom_id):
					continue
				if _should_trim_unpacked_atom(repetition_idx, sub_atom_id):
					continue
				assert(not _get_atom_id(repetition_idx, sub_atom_id) in _atoms_ids_cache, "Math failed and there are repeated atom ids!")
				_atoms_ids_cache.append(_get_atom_id(repetition_idx, sub_atom_id))
	return _atoms_ids_cache.duplicate()


func _should_trim_atom(in_atom_id: int) -> bool:
	if _trim_invalid_valence_carbons == false:
		return false
	var unpacked_id: UnpackedAtomId = _unpack_atom_id(in_atom_id)
	return _should_trim_unpacked_atom(unpacked_id.repetition_idx, unpacked_id.sub_atom_id)


func _should_trim_unpacked_atom(repetition_idx: int, sub_atom_id: int) -> bool:
	if _trim_invalid_valence_carbons == false:
		return false
	if repetition_idx == 0:
		# first repetition, count non glue bond 
		var bond_count: int = 0
		for bond: CarbonTubuleBasis.Bond in _template.bonds:
			if bond.is_glue: continue
			if not sub_atom_id in [bond.from_coordinate, bond.to_coordinate]: continue
			bond_count += 1
		return bond_count <= 1
	if repetition_idx >= (get_repetition_count() - 1):
		# last repetition, count bonds targeting valid atoms
		var bond_count: int = 0
		for bond: CarbonTubuleBasis.Bond in _template.bonds:
			if not sub_atom_id in [bond.from_coordinate, bond.to_coordinate]: continue
			var other_sub_atom_id: int
			var other_repetition_idx: int
			match sub_atom_id:
				bond.from_coordinate when bond.is_glue:
					other_sub_atom_id = bond.to_coordinate
					other_repetition_idx = repetition_idx - 1
				bond.to_coordinate when bond.is_glue:
					other_sub_atom_id = bond.from_coordinate
					other_repetition_idx = repetition_idx + 1
				bond.from_coordinate when not bond.is_glue:
					other_sub_atom_id = bond.to_coordinate
					other_repetition_idx = repetition_idx
				bond.to_coordinate when not bond.is_glue:
					other_sub_atom_id = bond.from_coordinate
					other_repetition_idx = repetition_idx
			if is_atom_valid(_get_atom_id(other_repetition_idx, other_sub_atom_id), false):
				bond_count += 1
		return bond_count <= 1
	return false


func atom_get_atomic_number(in_atom_id: int) -> int:
	if _track_atoms == false:
		return PeriodicTable.INVALID_ATOMIC_NUMBER
	return _get_atom_data(in_atom_id).atomic_number


## Calculate the [url=https://en.wikipedia.org/wiki/Formal_charge]formal charge[/url] of a given atom
func atom_get_formal_charge(_in_atom_id: int) -> int:
	# TODO: for now assume 0
	return 0


func atom_get_position(in_atom_id: int) -> Vector3:
	if _track_atoms == false:
		return Vector3.ONE * NAN
	return _get_atom_data(in_atom_id).position


func atom_get_bonds(in_atom_id: int) -> PackedInt32Array:
	var unpacked_id: UnpackedAtomId = _unpack_atom_id(in_atom_id)
	var atom_bonds: PackedInt32Array = []
	for i: int in _template.bonds.size():
		var bond: CarbonTubuleBasis.Bond = _template.bonds[i]
		if (bond.from_coordinate == unpacked_id.sub_atom_id or bond.to_coordinate == unpacked_id.sub_atom_id):
			var repetition_idx: int = unpacked_id.repetition_idx
			if bond.is_glue and bond.to_coordinate == unpacked_id.sub_atom_id:
				repetition_idx += 1
			if is_bond_valid(_get_bond_id(repetition_idx, i)):
				atom_bonds.append(_get_bond_id(repetition_idx, i))
	return atom_bonds


func atom_get_bond_target(in_atom_id: int, in_bond_id: int) -> int:
	var unpacked_atom_id: UnpackedAtomId = _unpack_atom_id(in_atom_id)
	var unpacked_bond_id: UnpackedBondId = _unpack_bond_id(in_bond_id)
	var bond: CarbonTubuleBasis.Bond = _template.bonds[unpacked_bond_id.sub_bond_id]
	var other_atom_sub_id: int = -1
	var other_atom_repetition_idx: int = unpacked_atom_id.repetition_idx
	if bond.from_coordinate == unpacked_atom_id.sub_atom_id:
		other_atom_sub_id = bond.to_coordinate
		if bond.is_glue: # bonded to the previous repetition
			other_atom_repetition_idx -= 1
	elif bond.from_coordinate == unpacked_atom_id.sub_atom_id:
		other_atom_sub_id = bond.from_coordinate
		if bond.is_glue: # bonded to the next repetition
			other_atom_repetition_idx += 1
	else:
		assert(false, "Bond id doesn't match atom id!")
		return INVALID_ATOM_ID
	return _get_atom_id(other_atom_repetition_idx, other_atom_sub_id)


func atom_find_bond_between(in_atom_id_a: int, in_atom_id_b: int) -> int:
	assert(in_atom_id_a != in_atom_id_b)
	var unpacked_a: UnpackedAtomId = _unpack_atom_id(in_atom_id_a)
	var unpacked_b: UnpackedAtomId = _unpack_atom_id(in_atom_id_b)
	match abs(unpacked_a.repetition_idx - unpacked_b.repetition_idx):
		0: # Same repetition index, not a glue bond
			var pair: PackedInt32Array = [unpacked_a.sub_atom_id, unpacked_b.sub_atom_id]
			for i: int in _template.bonds.size():
				var bond: CarbonTubuleBasis.Bond = _template.bonds[i]
				if bond.is_glue:
					continue
				if bond.from_coordinate in pair and bond.to_coordinate in pair:
					return _get_bond_id(unpacked_a.repetition_idx, i)
			return INVALID_BOND_ID
		1: # Glue bond, connecting 2 neighbor crystals
			var rep_a: int = unpacked_a.repetition_idx
			var rep_b: int = unpacked_b.repetition_idx
			var from: int = unpacked_a.sub_atom_id if rep_a > rep_b else unpacked_b.sub_atom_id
			var to: int = unpacked_a.sub_atom_id if rep_a < rep_b else unpacked_b.sub_atom_id
			for i: int in _template.bonds.size():
				var bond: CarbonTubuleBasis.Bond = _template.bonds[i]
				if bond.is_glue == false:
					continue
				if bond.from_coordinate == from and bond.to_coordinate == to:
					var rep_idx: int = maxi(rep_a, rep_b)
					return _get_bond_id(rep_idx, i)
			return INVALID_BOND_ID
		_: # Not neighbor crystals, cannot exists bond
			return INVALID_BOND_ID


func atoms_count_visible_by_type(types_to_count: PackedInt32Array) -> int:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	if not _track_atoms:
		return 0
	var count: int = 0
	for atom_id: int in get_valid_atoms():
		var atom: AtomData = _get_atom_data(atom_id)
		if atom.atomic_number in types_to_count and is_atom_visible(atom_id):
			count += 1
	return count


## Returns wether or not a bond has been removed from the structure
func is_bond_valid(in_bond_id: int) -> bool:
	var unpacked: UnpackedBondId = _unpack_bond_id(in_bond_id)
	if unpacked.repetition_idx >= get_repetition_count():
		return false
	if unpacked.sub_bond_id >= _template.bonds.size():
		return false
	elif unpacked.repetition_idx < get_repetition_count() - 2 and unpacked.repetition_idx >= 2:
		return unpacked.sub_bond_id < _template.bonds.size()
	var bond: CarbonTubuleBasis.Bond = _template.bonds[unpacked.sub_bond_id]
	if bond.is_glue and unpacked.repetition_idx == 0:
		# First repetition doesn't have glue bonds
		return false
	var from_id: int = _get_atom_id(unpacked.repetition_idx, bond.from_coordinate)
	var to_id: int = _get_atom_id(unpacked.repetition_idx - (1 if bond.is_glue else 0), bond.to_coordinate)
	return is_atom_valid(from_id) and is_atom_valid(to_id)


func get_valid_bonds() -> PackedInt32Array:
	if _track_atoms == false:
		return []
	if _bonds_ids_cache.is_empty():
		for repetition_idx: int in get_repetition_count():
			for i: int in _template.bonds.size():
				if is_bond_valid(_get_bond_id(repetition_idx, i)):
					_bonds_ids_cache.append(_get_bond_id(repetition_idx, i))
	return _bonds_ids_cache.duplicate()


## Returns the list with all existing bonds ids
func get_bonds_ids() -> PackedInt32Array:
	return get_valid_bonds()


## Returns bond information in form of Vector3i
## x component: ID of the first atom participating in bond
## y component: ID of the second atom participating in bond
## z component: bond order
func get_bond(in_bond_id: int) -> Vector3i:
	return _get_bond_data(in_bond_id)


## Returns number of bonds that has been created in this NanoStructure
## and have not been removed.
func get_valid_bonds_count() -> int:
	assert(not _is_being_edited, "I'm being edited, performing operations on atoms in this state is unrecommended")
	
	if not _track_atoms:
		return 0
	
	if _bonds_count_cache == -1:
		var glue_bonds: Array[CarbonTubuleBasis.Bond] = _template.bonds.filter(
			func(bond: CarbonTubuleBasis.Bond) -> bool: return bond.is_glue
		)
		var non_glue_count: int = _template.bonds.size() - glue_bonds.size()
		var glue_count: int = glue_bonds.size()
		var total_count: int = 0
		# all non glue bonds except last repetition
		total_count += non_glue_count * get_repetition_count() - 1
		# all glue bonds except last repetition, firest repetition doesn't have glue bonds
		total_count += glue_count * maxi(get_repetition_count() - 2, 0)
		# bonds of the last repetition
		var repetition_idx: int = get_repetition_count() - 1
		for i in _template.bonds.size():
			var bond: CarbonTubuleBasis.Bond = _template.bonds[i]
			if bond.is_glue and repetition_idx == 0:
				# First repetition doesn't have glue bonds
				continue
			var from_id: int = _get_atom_id(repetition_idx, bond.from_coordinate)
			var to_id: int = _get_atom_id(repetition_idx - (1 if bond.is_glue else 0), bond.to_coordinate)
			if is_atom_valid(from_id) and is_atom_valid(to_id):
				total_count += 1
		_bonds_count_cache = total_count
	return _bonds_count_cache


func _get_atom_data(in_atom_id: int) -> AtomData:
	assert(is_atom_valid(in_atom_id), "This atom does not belong to the structure")
	if not _atoms_cache.has(in_atom_id):
		_atoms_cache[in_atom_id] = AtomData.new(_unpack_atom_id(in_atom_id), self)
	return _atoms_cache[in_atom_id]


func _get_bond_data(in_bond_id: int) -> Vector3i:
	if not in_bond_id in _bonds_cache:
		var unpacked: UnpackedBondId = _unpack_bond_id(in_bond_id)
		assert(unpacked.sub_bond_id < _template.bonds.size(), "Invalid bond id")
		var bond: CarbonTubuleBasis.Bond = _template.bonds[unpacked.sub_bond_id]
		var from_id: int = _get_atom_id(unpacked.repetition_idx, bond.from_coordinate)
		var to_id: int = _get_atom_id(unpacked.repetition_idx - (1 if bond.is_glue else 0), bond.to_coordinate)
		const BOND_ORDER_ONE = 1
		_bonds_cache[in_bond_id] = Vector3i(from_id, to_id, BOND_ORDER_ONE)
	return _bonds_cache[in_bond_id]

static func _unpack_atom_id(in_atom_id: int) -> UnpackedAtomId:
	if not _unpacked_atom_ids.has(in_atom_id):
		_unpacked_atom_ids[in_atom_id] = UnpackedAtomId.new(in_atom_id)
	return _unpacked_atom_ids[in_atom_id]


static func _get_atom_id(repetition_idx: int, sub_atom_id: int) -> int:
	return repetition_idx * 100000 + sub_atom_id


static func _unpack_bond_id(in_bond_id: int) -> UnpackedBondId:
	if not _unpacked_bond_ids.has(in_bond_id):
		_unpacked_bond_ids[in_bond_id] = UnpackedBondId.new(in_bond_id)
	return _unpacked_bond_ids[in_bond_id]


static func _get_bond_id(repetition_idx: int, sub_bond_id: int) -> int:
	return repetition_idx * 100000 + sub_bond_id
#endregion: Atoms and Bonds


#region: Anchors and Springs
func spring_create(_in_anchor_id: int, _in_atom_id: int, _in_spring_constant_force: float,
			_is_equilibrium_length_automatic: bool, _in_equilibrium_manual_length: float) -> int:
	assert(false, "Unsupported")
	return INVALID_SPRING_ID


func spring_create_between_atoms(_in_atom_id_1: int, _in_atom_id_2: int, _in_spring_constant_force: float,
			_is_equilibrium_length_automatic: bool, _in_equilibrium_manual_length: float) -> int:
	assert(false, "Unsupported")
	return INVALID_SPRING_ID


func spring_is_atom_to_atom(_in_spring_id: int) -> bool:
	assert(false, "Unsupported")
	return false


func spring_has(_in_spring_id: int) -> bool:
	return false


func spring_invalidate(_in_spring_id: int) -> void:
	assert(false, "Unsupported")
	return


func spring_get_atom_id(_in_spring_id: int) -> int:
	assert(false, "Unsupported")
	return INVALID_ATOM_ID


func spring_get_second_atom_id(_in_spring_id: int) -> int:
	assert(false, "Unsupported")
	return INVALID_ATOM_ID


func spring_get_atom_position(_in_spring_id: int) -> Vector3:
	assert(false, "Unsupported")
	return Vector3.ONE * NAN


func spring_get_anchor_id(_in_spring_id: int) -> int:
	assert(false, "Unsupported")
	return Workspace.INVALID_OBJECT_INDEX


func get_related_anchors() -> PackedInt32Array:
	return []


func spring_get_target_position(_in_spring_id: int, _in_parent_context: StructureContext) -> Vector3:
	assert(false, "Unsupported")
	return Vector3.ONE * NAN


func spring_get_equilibrium_length_is_auto(_in_spring_id: int) -> bool:
	return false


func spring_set_equilibrium_lenght_is_auto(_in_spring_id: int, _in_is_auto: bool) -> void:
	assert(false, "Unsupported")
	return


func spring_set_equilibrium_manual_length(_in_spring_id: int, _new_equilibrium_manual_length: float) -> void:
	assert(false, "Unsupported")
	return


func spring_get_equilibrium_manual_length(_in_spring_id: int) -> float:
	assert(false, "Unsupported")
	return 0


func spring_calculate_equilibrium_auto_length(_in_spring_id: int, _in_parent_context: StructureContext) -> float:
	assert(false, "Unsupported")
	return 0


func spring_get_constant_force(_in_spring_id: int) -> float:
	assert(false, "Unsupported")
	return 0


func spring_set_constant_force(_in_spring_id: int, _new_force: float) -> void:
	assert(false, "Unsupported")
	return


func springs_get_all() -> PackedInt32Array:
	return PackedInt32Array()


func springs_get_valid() -> PackedInt32Array:
	assert(false, "Unsupported")
	return PackedInt32Array()


func springs_count() -> int:
	assert(false, "Unsupported")
	return 0


func atom_get_springs(_in_atom_id: int) -> PackedInt32Array:
	assert(false, "Unsupported")
	return PackedInt32Array()
#endregion: Anchors and Springs


#region: Virtual Motors
func _set_connected_motor(_in_motor_id: int) -> void:
	return


func motor_link_get_motor_id(_in_atom_id: int) -> int:
	assert(false, "Unsupported")
	return Workspace.INVALID_OBJECT_INDEX

func motor_link_get_motor_position(_in_atom_id: int, _in_parent_context: StructureContext) -> Vector3:
	assert(false, "Unsupported")
	return Vector3.ONE * NAN


func motor_links_count() -> int:
	return 0


func motor_links_get_all() -> Dictionary: # { atom_id<int> = motor_id<int> }
	return {}


func atom_set_motor_link(_in_atom_id: int, _out_motor_context: StructureContext) -> void:
	assert(false, "Unsupported")
	return


func atom_clear_motor_link(_in_atom_id: int) -> void:
	assert(false, "Unsupported")
	return


func atom_has_motor_link(_in_atom_id: int) -> bool:
	return false
#endregion: Virtual Motors


func get_type() -> StringName:
	return &"CarbonNanotubeStructure"


func get_readable_type() -> String:
	return "Carbon Nanotube"


func get_tooltip_text() -> String:
	var length: float = _position_begin.distance_to(_position_end)
	var diameter: float = _basis.get_estimated_diameter()
	return tr(&"Length: %.3f nm, Diameter: %.3f nm") %[length, diameter]


func get_icon() -> Texture2D:
	return null


func get_aabb(_in_bounds_type := AABB_BoundsType.AtomsPositions) -> AABB:
	if _aabb_cache == AABB():
		var dir_basis: Basis = get_repetition_transform(0).basis
		var up: Vector3 = dir_basis.y
		var fwd: Vector3 = dir_basis.z
		var aabb := AABB(_position_begin, Vector3())
		for angle: float in range(0.0, 2 * PI, PI / 2.0):
			var offset: Vector3 = up.rotated(fwd, angle)
			aabb = aabb.expand(_position_begin + offset)
			aabb = aabb.expand(_position_end + offset)
		_aabb_cache = aabb
	return _aabb_cache


#region: UndoRedo

func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = super.create_state_snapshot()

	state_snapshot["script.resource_path"] = get_script().resource_path
	state_snapshot["_basis"] = _basis
	state_snapshot["_template"] = _template
	state_snapshot["_track_atoms"] = _track_atoms
	state_snapshot["_chiral_index_n"] = _chiral_index_n
	state_snapshot["_chiral_index_m"] = _chiral_index_m
	state_snapshot["_position_begin"] = _position_begin
	state_snapshot["_position_end"] = _position_end
	state_snapshot["_tube_direction"] = _tube_direction
	state_snapshot["_atoms_count_cache"] = _atoms_count_cache
	state_snapshot["_atoms_ids_cache"] = _atoms_ids_cache.duplicate()
	var atom_cache_state: Dictionary = {}
	for id: int in _atoms_cache.keys():
		atom_cache_state[id] = AtomData.to_state(_atoms_cache[id])
	state_snapshot["_atoms_cache"] = atom_cache_state
	state_snapshot["_bonds_count_cache"] = _bonds_count_cache
	state_snapshot["_bonds_ids_cache"] = _bonds_ids_cache.duplicate()
	state_snapshot["_bonds_cache"] = _bonds_cache.duplicate()
	state_snapshot["_aabb_cache"] = _aabb_cache
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_basis = in_state_snapshot["_basis"]
	_template = in_state_snapshot["_template"]
	_track_atoms = in_state_snapshot["_track_atoms"]
	_chiral_index_n = in_state_snapshot["_chiral_index_n"]
	_chiral_index_m = in_state_snapshot["_chiral_index_m"]
	_position_begin = in_state_snapshot["_position_begin"]
	_position_end = in_state_snapshot["_position_end"]
	_tube_direction = in_state_snapshot["_tube_direction"]
	_atoms_count_cache = in_state_snapshot["_atoms_count_cache"]
	_atoms_ids_cache = in_state_snapshot["_atoms_ids_cache"].duplicate()
	_atoms_cache = {}
	for id: int in in_state_snapshot["_atoms_cache"].keys():
		_atoms_cache[id] = AtomData.from_state(in_state_snapshot["_atoms_cache"][id])
	_bonds_count_cache = in_state_snapshot["_bonds_count_cache"]
	_bonds_ids_cache = in_state_snapshot["_bonds_ids_cache"].duplicate()
	_bonds_cache = in_state_snapshot["_bonds_cache"].duplicate()
	_aabb_cache = in_state_snapshot["_aabb_cache"]
	
	super.apply_state_snapshot(in_state_snapshot)
#endregion: UndoRedo


class UnpackedAtomId:
	var original_id: int = 0
	var repetition_idx: int = 0
	var sub_atom_id: int = 0
	var _read_only: bool = false
	func _init(atom_id: int) -> void:
		original_id = atom_id
		repetition_idx = floori(atom_id / 100000.0)
		atom_id -= repetition_idx * 100000
		sub_atom_id = atom_id
		assert(CarbonNanotubeStructure._get_atom_id(repetition_idx, sub_atom_id) == original_id,
			"Failed to unpack atom id %d" % original_id)
		_read_only = true
	func _set(property: StringName, _value: Variant) -> bool:
		if _read_only and property in [&"original_id", &"repetition_idx", &"sub_atom_id"]:
			if OS.is_debug_build():
				assert(false, "Attempted to change value '%s' in read only DnaStructure.UnpackedAtomId object" % property)
				pass
			else:
				push_error("Attempted to change value '%s' in read only DnaStructure.UnpackedAtomId object" % property)
			return true
		return false


class UnpackedBondId:
	var original_id: int = 0
	var repetition_idx: int = 0
	var sub_bond_id: int = 0
	var _read_only: bool = false
	func _init(bond_id: int) -> void:
		original_id = bond_id
		repetition_idx = floori(bond_id / 100000.0)
		bond_id -= repetition_idx * 100000
		sub_bond_id = bond_id
		assert(CarbonNanotubeStructure._get_bond_id(repetition_idx, sub_bond_id) == original_id,
			"Failed to unpack atom id %d" % original_id)
		_read_only = true
	func _set(property: StringName, _value: Variant) -> bool:
		if _read_only and property in [&"original_id", &"repetition_idx", &"sub_bond_id"]:
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
	
	func _init(id_data: UnpackedAtomId, owner: CarbonNanotubeStructure) -> void:
		if id_data == null and owner == null:
			# Assume reconstructing cache
			return
		var basis_template: CarbonTubuleBasis.CrystalCell = owner._template
		assert(id_data.sub_atom_id < basis_template.basis.size(),
			"Invalid atom ID %d (sub_atom_id = %d)" % [id_data.original_id, id_data.sub_atom_id])
		
		atomic_number = basis_template.basis[id_data.sub_atom_id].element
		var fractional_position: Vector3 = basis_template.basis[id_data.sub_atom_id].position
		var cartesian: Vector3 = (
			basis_template.av[0] * fractional_position.x +
			basis_template.av[1] * fractional_position.y +
			basis_template.av[2] * fractional_position.z
		)
		
		# The cell centers the tube at (a/2, b/2) in XY by design.
		# Extract that offset from the cell basis vectors so we can remove it.
		cartesian -= basis_template.xy_center
		var xform: Transform3D = owner.get_repetition_transform(id_data.repetition_idx)
		position = xform * cartesian
	
	
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
