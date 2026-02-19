class_name NanoRotaryMotorParameters extends NanoVirtualMotorParameters

enum Polarity {
	CLOCKWISE,
	COUNTER_CLOCKWISE
}


@export var top_revolutions_per_nanosecond: float = 30.0:
	set = _set_top_revolutions_per_nanosecond
@export var is_jerk_limited: bool = false:
	set = _set_is_jerk_limited
@export var jerk_limit: float = 50.0:
	set = _set_jerk_limit
@export var polarity: Polarity = Polarity.CLOCKWISE:
	set = _set_polarity


var _state_snapshot_dirty: bool = true
var _state_snapshot: Dictionary = {}


func _init() -> void:
	motor_type = Type.ROTARY
	changed.connect(_on_self_changed)


func _on_self_changed() -> void:
	_state_snapshot_dirty = true


func _set(property: StringName, value: Variant) -> bool:
	if property == &"top_speed_in_gigahertz":
		# This is entirely for backwards compatibility with existing .msep1 files
		# The property top_speed_in_gigahertz was renamed to top_revolutions_per_nanosecond
		# This code is meant to convert the values from old to new
		top_revolutions_per_nanosecond = float(value) * 1e9
		_state_snapshot_dirty = true
		return true
	return false


func get_tooltip_text() -> String:
	var tooltip: String = ""
	var polarity_name: StringName = NanoRotaryMotorParameters.Polarity.find_key(polarity)
	tooltip += tr("Top Speed: %.1f Rev/ps\n") % (top_revolutions_per_nanosecond / 1000.0)
	tooltip += tr(polarity_name.capitalize()) + "\n"
	var with_cycle: bool = cycle_type != NanoRotaryMotorParameters.CycleType.CONTINUOUS
	if with_cycle and cycle_swap_polarity:
		tooltip += tr("With Cycle alternating Polarity\n")
	elif with_cycle:
		tooltip += tr("With Cycle\n")
	if with_cycle and cycle_eventually_stops:
		tooltip += tr_n(
			"Stops after %d cycle\n",
			"Stops after %d cycles\n",
			cycle_stop_after_n_cycles
		) % cycle_stop_after_n_cycles
	return tooltip


func _get_motor_type() -> Type:
	return Type.ROTARY


func _set_top_revolutions_per_nanosecond(in_top_revolutions_per_nanosecond: float) -> void:
	if top_revolutions_per_nanosecond == in_top_revolutions_per_nanosecond:
		return
	top_revolutions_per_nanosecond = in_top_revolutions_per_nanosecond
	emit_changed()


func _set_is_jerk_limited(in_is_jerk_limited: bool) -> void:
	if is_jerk_limited == in_is_jerk_limited:
		return
	is_jerk_limited = in_is_jerk_limited
	emit_changed()


func _set_jerk_limit(in_jerk_limit: float) -> void:
	if jerk_limit == in_jerk_limit:
		return
	jerk_limit = in_jerk_limit
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
			"top_revolutions_per_nanosecond" = top_revolutions_per_nanosecond,
			"is_jerk_limited" = is_jerk_limited,
			"jerk_limit" = jerk_limit,
			"polarity" = polarity,
		}
		_state_snapshot_dirty = false
	return _state_snapshot.duplicate(true)

func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	# prevent `changed` and any other signal from being emited whil state snapshot is being applied
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
	top_revolutions_per_nanosecond = in_snapshot.top_revolutions_per_nanosecond
	is_jerk_limited = in_snapshot.is_jerk_limited
	jerk_limit = in_snapshot.jerk_limit
	polarity = in_snapshot.polarity
	set_block_signals(was_blocking_signals)
