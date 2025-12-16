class_name DnaStructure extends NanoStructure

signal bases_count_changed(new_count: int)
signal sequence_changed(new_sequence: String)
signal path_changed()
signal parameters_changed(read_only_parameters: DnaStructureParameters)


enum Strand {
	A = 1,
	B = 2,
}
const StrandPolicy = DnaStructureParameters.StrandPolicy
const INVALID_CONTROL_POINT_IDX: int = -1

@export var _curve: Curve3D
@export var _twists_offset_radians: float
@export var _sequence: String
@export var _parameters: DnaStructureParameters

var _base_transform_cache: Dictionary[int, Transform3D]
var _atoms_count_cache: int = -1

var _is_being_edited: bool = false
var _last_sequence: String = ""
var _last_bases_cout: int = 0
var _signal_queue_path_changed: bool = false
var _signal_queue_parameters_changed: bool = false
var _baked_path: PackedVector3Array = []

static func create(out_parameters: DnaStructureParameters, in_sequence: String = "") -> DnaStructure:
	var instance := DnaStructure.new()
	instance._parameters = out_parameters.duplicate(true)
	instance._sequence = in_sequence
	return instance


func _init() -> void:
	if _curve == null:
		# Newly created object
		_curve = Curve3D.new()
		_curve.bake_interval = 0.02
	if _parameters == null:
		_parameters = DnaStructureParameters.new()
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
	return


func is_being_edited() -> bool:
	return _is_being_edited


func end_edit() -> void:
	assert(_is_being_edited, "I'm not being edited currently, make sure start_edit() is called first")
	_is_being_edited = false
	_atoms_count_cache = -1
	
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
			_baked_path.clear()
			sequence_changed.emit(_sequence)
		if _signal_queue_parameters_changed:
			_baked_path.clear()
			_parameters.set_read_only(true)
			parameters_changed.emit(_parameters)
			_parameters.set_read_only(false)
			_signal_queue_parameters_changed = false
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
	var cache_index: int = in_base_index * (-1 if in_strand == Strand.B else 1)
	if not cache_index in _base_transform_cache:
		var at_pos: float = in_base_index * _parameters.rise_nanometers
		var y_dir := Vector3.ZERO
		var z_dir := Vector3.ZERO
		var path_pos: Vector3
		var points: PackedVector3Array
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
			while advance < at_pos:
				advance += points[point_idx].distance_to(points[point_idx + 1])
				point_idx += 1
			# TODO: Adjust path pos interpolating points[point_idx - 1] to points[point_idx]
			path_pos = points[point_idx - 1]
			z_dir = points[point_idx - 1].direction_to(points[point_idx])
			y_dir = _curve.get_baked_up_vectors()[point_idx]
		y_dir = y_dir.rotated(z_dir, get_base_twist_rad(in_strand, in_base_index))
		var x_dir: Vector3 = y_dir.cross(z_dir)
		var basis := Basis(x_dir, y_dir, z_dir)
		var offset_dir: Vector3 = x_dir * (-1 if in_strand == Strand.B else 1)
		var base_offset: float = _parameters.dna_radius_nanometers - DnaBuilder.DNA_BASES_OFFSET
		var final_pos: Vector3 = path_pos + offset_dir * base_offset
		_base_transform_cache[cache_index] = Transform3D(basis, final_pos)
	return _base_transform_cache[cache_index]


func get_backbone_transform(in_strand: Strand, in_base_index: int) -> Transform3D:
	var transform: Transform3D = get_base_transform(in_strand, in_base_index)
	var backbone_offset_dir: Vector3 = transform.basis.x
	if in_strand == Strand.B:
		backbone_offset_dir *= -1
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


#region: AtomicStructure API
func get_valid_atoms_count() -> int:
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
		for base in _sequence:
			_atoms_count_cache += base_count[base]
	return _atoms_count_cache
#endregion: AtomicStructure API


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = super.create_state_snapshot()
	state_snapshot["script.resource_path"] = get_script().resource_path
	state_snapshot["_curve"] = _create_curve_snapshot()
	state_snapshot["_twists_offset_radians"] = _twists_offset_radians
	state_snapshot["_sequence"] = _sequence
	state_snapshot["_parameters"] = _parameters.create_state_snapshot()
	state_snapshot["_base_transform_cache"] = _base_transform_cache.duplicate()
	state_snapshot["_baked_path"] = _baked_path.duplicate()
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_set_curve_snapshot(in_state_snapshot["_curve"])
	_twists_offset_radians = in_state_snapshot["_twists_offset_radians"]
	_sequence = in_state_snapshot["_sequence"]
	_parameters.apply_state_snapshot(in_state_snapshot["_parameters"])
	_base_transform_cache = in_state_snapshot["_base_transform_cache"].duplicate()
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
