class_name NanoLinearMotorParameters extends NanoVirtualMotorParameters

enum Polarity {
	FORWARD,
	BACKWARDS
}

@export var top_speed_in_nanometers_by_nanoseconds: float = 0.1 * 1e+6:
	set = _set_top_speed_in_nanometers_by_nanoseconds
@export var polarity: Polarity = Polarity.FORWARD:
	set = _set_polarity

var _state_snapshot_dirty: bool = true
var _state_snapshot: Dictionary = {}

func _init() -> void:
	motor_type = Type.LINEAR
	changed.connect(_on_self_changed)

func _on_self_changed() -> void:
	_state_snapshot_dirty = true


func _get_motor_type() -> Type:
	return Type.LINEAR


func _set_top_speed_in_nanometers_by_nanoseconds(in_top_speed_in_nanometers_by_nanoseconds: float) -> void:
	if top_speed_in_nanometers_by_nanoseconds == in_top_speed_in_nanometers_by_nanoseconds:
		return
	top_speed_in_nanometers_by_nanoseconds = in_top_speed_in_nanometers_by_nanoseconds
	emit_changed()


func _set_polarity(in_polarity: Polarity) -> void:
	if polarity == in_polarity:
		return
	polarity = in_polarity
	emit_changed()



func create_state_snapshot() -> Dictionary:
	if _state_snapshot_dirty:
		_state_snapshot = {
			# Base properties
			"motor_type" = motor_type,
			"ramp_in_time_in_nanoseconds" = ramp_in_time_in_nanoseconds,
			"ramp_out_time_in_nanoseconds" = ramp_out_time_in_nanoseconds,
			"cycle_type" = cycle_type,
			"cycle_time_limit_in_femtoseconds" = cycle_time_limit_in_femtoseconds,
			"cycle_distance_limit" = cycle_distance_limit,
			"cycle_pause_time_in_femtoseconds" = cycle_pause_time_in_femtoseconds,
			"cycle_swap_polarity" = cycle_swap_polarity,
			"cycle_eventually_stops" = cycle_eventually_stops,
			"cycle_stop_after_n_cycles" = cycle_stop_after_n_cycles,
			# Rotary specific properties
			"top_speed_in_nanometers_by_nanoseconds" = top_speed_in_nanometers_by_nanoseconds,
			"polarity" = polarity,
		}
		_state_snapshot_dirty = false
	return _state_snapshot.duplicate(true)

func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	# prevent `changed` and any other signal from being emited while state snapshot is being applied
	# any component of the application should only react to `signal WorkspaceContext.history_snapshot_applied`
	var was_blocking_signals: bool = is_blocking_signals()
	set_block_signals(true)
	# Base properties
	motor_type = in_snapshot.motor_type
	ramp_in_time_in_nanoseconds = in_snapshot.ramp_in_time_in_nanoseconds
	ramp_out_time_in_nanoseconds = in_snapshot.ramp_out_time_in_nanoseconds
	cycle_type = in_snapshot.cycle_type
	cycle_time_limit_in_femtoseconds = in_snapshot.cycle_time_limit_in_femtoseconds
	cycle_distance_limit = in_snapshot.cycle_distance_limit
	cycle_pause_time_in_femtoseconds = in_snapshot.cycle_pause_time_in_femtoseconds
	cycle_swap_polarity = in_snapshot.cycle_swap_polarity
	cycle_eventually_stops = in_snapshot.cycle_eventually_stops
	cycle_stop_after_n_cycles = in_snapshot.cycle_stop_after_n_cycles
	# Rotary specific properties
	top_speed_in_nanometers_by_nanoseconds = in_snapshot.top_speed_in_nanometers_by_nanoseconds
	polarity = in_snapshot.polarity
	set_block_signals(was_blocking_signals)
