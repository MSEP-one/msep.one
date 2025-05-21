class_name NanoParticleEmitterParameters extends Resource


enum LimitType {
	NEVER,
	INSTANCE_COUNT,
	TIME
}


@export var _molecule: AtomicStructure
@export var _initial_delay_in_nanoseconds: float = 0.0
@export_range(1, 5, 1, "or_greater") var _molecules_per_instance: int = 1
@export var _instance_rate_time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(50, TimeSpanPicker.Unit.NANOSECOND)
@export var _limit_type := LimitType.NEVER
@export_range(1, 100, 1, "or_greater") var _stop_emitting_after_count: int = 1
@export var _stop_emitting_after_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(150, TimeSpanPicker.Unit.NANOSECOND)
@export var _instance_speed_nanometers_per_picosecond: float = 0.5
@export_range(0, 180, 0.1) var _spread_angle: float = 0


func set_molecule_template(out_molecule: AtomicStructure) -> void:
	assert(out_molecule.int_guid == Workspace.INVALID_STRUCTURE_ID,
		"Should not assign a structure directly from workspace, create a duplicate instead")
	if not out_molecule.get_aabb().get_center().is_equal_approx(Vector3.ZERO):
		push_warning("Molecule Template is not roughtly centered in the origin")
	_molecule = out_molecule
	emit_changed()


func get_molecule_template() -> AtomicStructure:
	return _molecule


func set_initial_delay_in_nanoseconds(in_initial_delay_in_nanoseconds: float) -> void:
	_initial_delay_in_nanoseconds = in_initial_delay_in_nanoseconds
	emit_changed()


func get_initial_delay_in_nanoseconds() -> float:
	return _initial_delay_in_nanoseconds


func set_molecules_per_instance(in_molecules_per_instance: int) -> void:
	_molecules_per_instance = in_molecules_per_instance
	emit_changed()


func get_molecules_per_instance() -> int:
	return _molecules_per_instance


func set_instance_rate_time_in_nanoseconds(in_instance_rate_time_in_nanoseconds: float) -> void:
	_instance_rate_time_in_nanoseconds = in_instance_rate_time_in_nanoseconds
	emit_changed()


func get_instance_rate_time_in_nanoseconds() -> float:
	return _instance_rate_time_in_nanoseconds


func set_limit_type(in_limit_type: LimitType) -> void:
	_limit_type = in_limit_type
	emit_changed()


func get_limit_type() -> LimitType:
	return _limit_type


func set_stop_emitting_after_count(in_stop_emitting_after_count: int) -> void:
	_stop_emitting_after_count = in_stop_emitting_after_count
	emit_changed()


func get_stop_emitting_after_count() -> int:
	return _stop_emitting_after_count


func set_stop_emitting_after_nanoseconds(in_stop_emitting_after_nanoseconds: float) -> void:
	_stop_emitting_after_nanoseconds = in_stop_emitting_after_nanoseconds
	emit_changed()


func get_stop_emitting_after_nanoseconds() -> float:
	return _stop_emitting_after_nanoseconds


func set_instance_speed_nanometers_per_picosecond(in_instance_speed_nanometers_per_picosecond: float) -> void:
	_instance_speed_nanometers_per_picosecond = in_instance_speed_nanometers_per_picosecond
	emit_changed()


func get_instance_speed_nanometers_per_picosecond() ->  float:
	return _instance_speed_nanometers_per_picosecond


func set_spread_angle(in_spread_angle: float) -> void:
	_spread_angle = in_spread_angle
	emit_changed()


func get_spread_angle() -> float:
	return _spread_angle

