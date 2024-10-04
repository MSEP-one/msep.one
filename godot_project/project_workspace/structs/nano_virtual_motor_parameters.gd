"@abstract_class"
class_name NanoVirtualMotorParameters extends Resource

enum Type {
	UNKNOWN,
	ROTARY,
	LINEAR
}


enum CycleType { ## How cycle works
	CONTINUOUS,  ## Start and never stop the motor
	TIMED,       ## In every cycle, motor will stop after a fixed amount of time has elapsed
	BY_DISTANCE, ## In every cycle, motor will stop after a fixed amount of distance was covered, This distance is in nanometers for linear motors and revolutions for rotary motors
}

var motor_type: Type = Type.UNKNOWN:
	get = _get_motor_type
@export var ramp_in_time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(150, TimeSpanPicker.Unit.NANOSECOND):
	set = _set_ramp_in_time_in_nanoseconds
@export var ramp_out_time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(150, TimeSpanPicker.Unit.NANOSECOND):
	set = _set_ramp_out_time_in_nanoseconds
@export_group("Cycle", "cycle_")
## Reffer to 
@export var cycle_type: CycleType = CycleType.CONTINUOUS:
	set = _set_cycle_type
## [code]cycle_time_limit_in_femtoseconds[/code] is used when
## [code]cycle_type == CycleType.TIMED[/code].[br]
@export var cycle_time_limit_in_femtoseconds: float = 500.0:
	set = _set_cycle_time_limit_in_femtoseconds
## [code]cycle_distance_limit[/code] is used when
## [code]cycle_type == CycleType.BY_DISTANCE[/code].[br]
## Unit of this member is [code]nanometers[/code] for linear motors,
## or [code]revolutions[/code] for rotary motors
@export var cycle_distance_limit: float = 1.0:
	set = _set_cycle_distance_limit
## After every cycle wait during [code]cycle_pause_time_in_femtoseconds[/code]
## before starting the motor again. Set this value to 0 to immediately start the motor.
## This value is ignored when [code]cycle_type == CycleType.CONTINUOUS[/code]
@export var cycle_pause_time_in_femtoseconds: float = 200.0:
	set = _set_cycle_pause_time_in_femtoseconds
## When set to true, polarity of the motor will swap every new cycle
@export var cycle_swap_polarity: bool = false:
	set = _set_cycle_swap_polarity
@export var cycle_eventually_stops: bool = false:
	set = _set_cycle_eventually_stops
@export var cycle_stop_after_n_cycles: int = 0:
	set = _set_cycle_stop_after_n_cycles

func _get_motor_type() -> Type:
	assert(false, "Implement in subclass")
	return Type.UNKNOWN


func _set_ramp_in_time_in_nanoseconds(in_ramp_in_time_in_nanoseconds: float) -> void:
	if ramp_in_time_in_nanoseconds == in_ramp_in_time_in_nanoseconds:
		return
	ramp_in_time_in_nanoseconds = in_ramp_in_time_in_nanoseconds
	emit_changed()


func _set_ramp_out_time_in_nanoseconds(in_ramp_out_time_in_nanoseconds: float) -> void:
	if ramp_out_time_in_nanoseconds == in_ramp_out_time_in_nanoseconds:
		return
	ramp_out_time_in_nanoseconds = in_ramp_out_time_in_nanoseconds
	emit_changed()


func _set_cycle_type(in_cycle_type: CycleType) -> void:
	if cycle_type == in_cycle_type:
		return
	cycle_type = in_cycle_type
	emit_changed()


func _set_cycle_time_limit_in_femtoseconds(in_cycle_time_limit_in_femtoseconds: float) -> void:
	if cycle_time_limit_in_femtoseconds == in_cycle_time_limit_in_femtoseconds:
		return
	cycle_time_limit_in_femtoseconds = in_cycle_time_limit_in_femtoseconds
	emit_changed()


func _set_cycle_distance_limit(in_cycle_distance_limit: float) -> void:
	if cycle_distance_limit == in_cycle_distance_limit:
		return
	cycle_distance_limit = in_cycle_distance_limit
	emit_changed()


func _set_cycle_pause_time_in_femtoseconds(in_cycle_pause_time_in_femtoseconds: float) -> void:
	if cycle_pause_time_in_femtoseconds == in_cycle_pause_time_in_femtoseconds:
		return
	cycle_pause_time_in_femtoseconds = in_cycle_pause_time_in_femtoseconds
	emit_changed()


func _set_cycle_swap_polarity(in_cycle_swap_polarity: bool) -> void:
	if cycle_swap_polarity == in_cycle_swap_polarity:
		return
	cycle_swap_polarity = in_cycle_swap_polarity
	emit_changed()


func _set_cycle_eventually_stops(in_cycle_eventually_stops: bool) -> void:
	if cycle_eventually_stops == in_cycle_eventually_stops:
		return
	cycle_eventually_stops = in_cycle_eventually_stops
	emit_changed()


func _set_cycle_stop_after_n_cycles(in_cycle_stop_after_n_cycles: int) -> void:
	if cycle_stop_after_n_cycles == in_cycle_stop_after_n_cycles:
		return
	cycle_stop_after_n_cycles = in_cycle_stop_after_n_cycles
	emit_changed()


func create_state_snapshot() -> Dictionary:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return {}


func apply_state_snapshot(_in_snapshot: Dictionary) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return

