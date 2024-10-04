class_name SimulationParameters extends Resource

enum PlaybackUnit {
	Femtoseconds = 0,
	Picoseconds   = 1,
	Nanoseconds   = 2,
	Steps         = 3,
	Frames        = 4,
}

@export var relax_before_start_simulation: bool = true:
	set = set_relax_before_start_simulation
@export var temperature_in_kelvins: float = 300:
	set = set_temperature_in_kelvins
@export var step_size_in_femtoseconds: float = 0.25:
	set = set_step_size_in_femtoseconds
@export var steps_per_report: int = 20:
	set = set_steps_per_report
@export var total_step_count: int = 4000:
	set = set_total_step_count
@export var playback_unit: PlaybackUnit = PlaybackUnit.Picoseconds:
	set = set_playback_unit


var _emit_changed_queued: bool = false
var _state_snapshot_dirty: bool = true
var _state_snapshot: Dictionary = {}


func _init() -> void:
	changed.connect(_on_self_changed)


func _on_self_changed() -> void:
	_state_snapshot_dirty = true


func set_relax_before_start_simulation(v: bool) -> void:
	if v != relax_before_start_simulation:
		_queue_emit_changed()
	relax_before_start_simulation = v


func set_temperature_in_kelvins(v: float) -> void:
	if v != temperature_in_kelvins:
		_queue_emit_changed()
	temperature_in_kelvins = v


func set_step_size_in_femtoseconds(v: float) -> void:
	if v != step_size_in_femtoseconds:
		_queue_emit_changed()
	step_size_in_femtoseconds = v


func set_steps_per_report(v: float) -> void:
	if v != steps_per_report:
		_queue_emit_changed()
	steps_per_report = int(v)


func set_total_step_count(v: float) -> void:
	if v != total_step_count:
		_queue_emit_changed()
	total_step_count = int(v)


func set_playback_unit(v: PlaybackUnit) -> void:
	if v != playback_unit:
		_queue_emit_changed()
	playback_unit = v


func to_byte_array() -> PackedByteArray:
	var array: PackedByteArray = []
	array.resize(8*2+4*2)
	array.encode_double(8*0, temperature_in_kelvins)
	array.encode_double(8*1, step_size_in_femtoseconds)
	array.encode_u32(8*2+4*0, steps_per_report)
	array.encode_u32(8*2+4*1, total_step_count)
	return array



func _queue_emit_changed() -> void:
	if not _emit_changed_queued:
		_state_snapshot_dirty = true
		_emit_changed_queued = true
		_on_emit_changed_deferred.call_deferred()


func _on_emit_changed_deferred() -> void:
	_emit_changed_queued = false
	emit_changed()


func create_state_snapshot() -> Dictionary:
	if _state_snapshot_dirty:
		_state_snapshot = {
			"relax_before_start_simulation" = relax_before_start_simulation,
			"temperature_in_kelvins" = temperature_in_kelvins,
			"step_size_in_femtoseconds" = step_size_in_femtoseconds,
			"steps_per_report" = steps_per_report,
			"total_step_count" = total_step_count,
			"playback_unit" = playback_unit,
		}
		_state_snapshot_dirty = false
	return _state_snapshot.duplicate(true)

func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	# Prevent changed signal from being queued by setting the `_emit_changed_queued`
	# member to true
	var emit_changed_was_queued: bool = _emit_changed_queued
	_emit_changed_queued = true
	relax_before_start_simulation = in_snapshot.relax_before_start_simulation
	temperature_in_kelvins = in_snapshot.temperature_in_kelvins
	step_size_in_femtoseconds = in_snapshot.step_size_in_femtoseconds
	steps_per_report = in_snapshot.steps_per_report
	total_step_count = in_snapshot.total_step_count
	playback_unit = in_snapshot.playback_unit
	_emit_changed_queued = emit_changed_was_queued
