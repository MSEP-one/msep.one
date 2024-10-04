class_name RelaxRequest extends RefCounted

signal retrying(retry_request: RelaxRequest)
signal retry_discarded()

var id: int: get = _get_simulation_id
var temperature_in_kelvins: float: get = _get_temperature_in_kelvins, set = _set_read_only
var selection_only: bool:          get = _get_selection_only,         set = _set_read_only
var include_springs: bool:         get = _get_include_springs,        set = _set_read_only
var lock_atoms: bool:              get = _get_lock_atoms,             set = _set_read_only
var passivate_molecules: bool:     get = _get_passivate_molecules,    set = _set_read_only
var bad_tetrahedral_bonds_detected: bool = false
var retried: bool = false
var promise := Promise.new()
var original_payload: OpenMMPayload = null
var _temperature_in_kelvins: float
var _selection_only: bool = false
var _include_springs: bool = false
var _lock_atoms: bool = false
var _passivate_molecules: bool = false
var _has_error: bool = false



func _init(in_temperature_in_kelvins: float, in_selection_only: bool, in_include_springs: bool, in_lock_atoms: bool, in_passivate_molecules: bool) -> void:
	_temperature_in_kelvins = in_temperature_in_kelvins
	_selection_only = in_selection_only
	_include_springs = in_include_springs
	_lock_atoms = in_lock_atoms
	_passivate_molecules = in_passivate_molecules


func cancel() -> void:
	if promise.is_fulfilled():
		push_warning("Attempted to cancel already fulfilled relax request #", id)
	_has_error = true
	promise.fail("Cancelled", OpenMMClass.RelaxResult.new(original_payload,original_payload.initial_positions))


func _get_temperature_in_kelvins() -> float:
	return _temperature_in_kelvins

func _get_selection_only() -> bool:
	return _selection_only

func _get_include_springs() -> bool:
	return _include_springs

func _get_lock_atoms() -> bool:
	return _lock_atoms

func _get_passivate_molecules() -> bool:
	return _passivate_molecules

func _set_read_only(_v: Variant) -> void:
	push_error("This property is read only")
	pass


func _get_simulation_id() -> int:
	return get_instance_id()
