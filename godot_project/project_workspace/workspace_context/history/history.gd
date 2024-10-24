class_name History extends Node

## emitted every time the history has been changed in any way (snapshot has been created/applied)
signal changed

## emitted every time the snapshot has been applied
signal snapshot_applied

signal snapshot_created(snapshot_name: String)
signal previous_snapshot_applied(undone_snapshot_name: String)
signal next_snapshot_applied(redone_snapshot_name: String)

const ACTION_WHITELIST_DURING_SIMULATION: Dictionary = {
	"Change Edited Group" : true,
	"Change Selection" : true,
	"Box Selection" : true,
	"Box Deselection" : true,
	"Select Atom" : true,
	"Select Bond" : true,
	"Select Shape" : true,
	"Select Motor" : true,
	"Select Anchor" : true,
	"Select Spring" : true,
	"Deselect Atom" : true,
	"Deselect Bond" : true,
	"Deselect Shape" : true,
	"Deselect Motor" : true,
	"Deselect Anchor" : true,
	"Deselect Spring" : true,
	"Clear Selection" : true,
	"Select All" : true,
	"Deselect All" : true,
	"Select Connected Atoms" : true,
	"Grow Selection" : true,
	"Shrink Selection" : true,
	"Disable hydrogen visibility" : true,
	"Enable hydrogen visibility" : true,
	"Show Bonds" : true,
	"Hide Bonds" : true,
	"Show Atom Labels" : true,
	"Hide Atom Labels" : true,
	"Hide Selected Objects" : true,
	"Show Hidden Objects" : true,
	"Set Color Override" : true,
	"Reset Color Override" : true,
}

const REDUNDANT_ACTION_WHITELIST := {
	"Apply Simulation State": true,
}

var _workspace_context: WorkspaceContext
var _snapshotable_systems: Array[Object]
var _snapshot_stack: Array[Dictionary]
var _name_stack: Array[String] = []
var _stack_pointer: int = -1
var _version: int
var _last_snapshot_taken_at_frame: int = Engine.get_frames_drawn() - 1
var _last_snapshot_name: String = ""


func initialize(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context


func register_snapshotable(in_system: Object) -> void:
	assert(in_system.has_method("create_state_snapshot"))
	assert(in_system.has_method("apply_state_snapshot"))
	assert(_snapshotable_systems.find(in_system) == -1)
	_snapshotable_systems.append(in_system)


func create_snapshot(in_snapshot_name: String) -> Dictionary:
	_monitor_redundant_snapshots(in_snapshot_name)
	var snapshot: Dictionary = {
		#"name" : _next_snapshot_name
	}
	
	for snapshotable: Object in _snapshotable_systems:
		snapshot[snapshotable] = snapshotable.create_state_snapshot()
	
	_add_snapshot_to_stack(snapshot, in_snapshot_name)
	return snapshot


func push_and_apply_snapshot(in_snapshot: Dictionary, in_snapshot_name: String) -> void:
	assert(_validate_extern_snapshot(in_snapshot), "Invalid snapshot data provided")
	_add_snapshot_to_stack(in_snapshot, in_snapshot_name)
	_stack_pointer -= 1
	apply_next_snapshot()


func _add_snapshot_to_stack(in_snapshot: Dictionary, in_snapshot_name: String) -> void:
	var need_to_drop_stack: bool = _stack_pointer != (_snapshot_stack.size() - 1)
	if need_to_drop_stack:
		_snapshot_stack.resize(_stack_pointer + 1)
		_name_stack.resize(_stack_pointer + 1)
	
	_snapshot_stack.append(in_snapshot)
	_name_stack.append(in_snapshot_name)
	_stack_pointer = _snapshot_stack.size() - 1
	
	var max_undo_count: int = MolecularEditorContext.msep_editor_settings.editor_max_undo_count
	while _snapshot_stack.size() > max_undo_count:
		_snapshot_stack.pop_front()
		_stack_pointer -= 1
	
	_version += 1
	_last_snapshot_taken_at_frame = Engine.get_frames_drawn()
	_last_snapshot_name = in_snapshot_name
	changed.emit()
	snapshot_created.emit(in_snapshot_name)


func apply_previous_snapshot() -> void:
	if _stack_pointer < 1:
		return
	if _snapshot_stack.is_empty():
		return
	var undone_snapshot_name: String = _name_stack[_stack_pointer]
	_stack_pointer -= 1
	_apply_snapshot(_stack_pointer)
	_version -= 1
	changed.emit()
	snapshot_applied.emit()
	previous_snapshot_applied.emit(undone_snapshot_name)


func apply_next_snapshot() -> void:
	var cannot_move_forward: bool = _stack_pointer >= (_snapshot_stack.size() - 1)
	if cannot_move_forward:
		return
	_stack_pointer += 1
	_apply_snapshot(_stack_pointer)
	var snapshot_name: String = _name_stack[_stack_pointer]
	_version += 1
	changed.emit()
	snapshot_applied.emit()
	next_snapshot_applied.emit(snapshot_name)


func _apply_snapshot(in_stack_index: int) -> void:
	var snapshot_to_apply: Dictionary = _snapshot_stack[in_stack_index]
	for snapshotable: Object in snapshot_to_apply:
		snapshotable.apply_state_snapshot(snapshot_to_apply[snapshotable])


func can_redo() -> bool:
	var is_pointer_at_the_end_of_stack: bool = _stack_pointer == (_snapshot_stack.size() - 1)
	if is_pointer_at_the_end_of_stack:
		return false
	var has_any_snapshot: bool = not _snapshot_stack.is_empty()
	return has_any_snapshot


func can_undo() -> bool:
	if _stack_pointer < 1:
		return false
	if _snapshot_stack.is_empty():
		return false
	return true


func get_undo_name() -> String:
	if _name_stack.is_empty():
		return ""
	return _name_stack[_stack_pointer]


func get_redo_name() -> String:
	var redo_idx: int = _stack_pointer + 1
	if redo_idx >= _name_stack.size():
		return ""
	return _name_stack[redo_idx]


func get_version() -> int:
	return _version


func _validate_extern_snapshot(in_snapshot: Dictionary) -> bool:
	for key: Variant in in_snapshot.keys():
		if not key in _snapshotable_systems:
			return false
		if not typeof(in_snapshot[key]) == TYPE_DICTIONARY:
			return false
	return true


## Detects if create_snapshot is called multiple times in a single frame
## External snapshots pushed by `push_and_apply_snapshot(in_snapshot, in_snapshot_name)`
## are not considered by this check
func _monitor_redundant_snapshots(in_snapshot_name: String) -> void:
	if _last_snapshot_taken_at_frame != Engine.get_frames_drawn():
		return
	var is_redundant_action_whitelisted: bool = \
			REDUNDANT_ACTION_WHITELIST.has(in_snapshot_name) or \
			REDUNDANT_ACTION_WHITELIST.has(_last_snapshot_name)
	if is_redundant_action_whitelisted and in_snapshot_name != _last_snapshot_name:
		return
	push_error("Possibly redundant snapshot detected. previous: ", _last_snapshot_name,
				" , current: ", in_snapshot_name)


static func create_signal_snapshot_for_object(in_object: Object) -> Dictionary:
	var snapshot: Dictionary = {}
	var signal_snapshots: Array[Dictionary] = []
	var signal_list: Array = in_object.get_signal_list()
	for signal_data: Dictionary in signal_list:
		var signal_name: String = signal_data["name"]
		var signal_instance: Signal = in_object.get(signal_name) as Signal
		signal_snapshots.append({
			"signal" : signal_instance.get_name(),
			"snapshot" : create_signal_snapshot(signal_instance)
		})
	snapshot["signal_snapshots"] = signal_snapshots
	return snapshot


static func apply_signal_snapshot_to_object(out_object: Object, in_snapshot: Dictionary) -> void:
	var signal_list: Array = out_object.get_signal_list()
	for signal_data: Dictionary in signal_list:
		var signal_name: String = signal_data["name"]
		var signal_instance: Signal = out_object.get(signal_name) as Signal
		_clear_signal(signal_instance)
	
	var signal_snapshots: Array[Dictionary] = in_snapshot["signal_snapshots"]
	for signal_snapshot: Dictionary in signal_snapshots:
		var signal_name: String = signal_snapshot["signal"]
		var snapshot: Dictionary = signal_snapshot["snapshot"]
		apply_signal_snapshot(out_object, signal_name, snapshot)


static func _clear_signal(out_signal: Signal) -> void:
	var connections: Array = out_signal.get_connections()
	for connection: Dictionary in connections:
		var callable: Callable = connection["callable"]
		if out_signal.is_connected(callable):
			out_signal.disconnect(callable)


static func create_signal_snapshot(in_signal: Signal) -> Dictionary:
	var snapshot: Dictionary = {}
	var callables: Array[Dictionary] = []
	var connections: Array = in_signal.get_connections()
	for connection: Dictionary in connections:
		var callable: Callable = connection["callable"]
		var callable_dict: Dictionary = {}
		callable_dict["signal_name"] = in_signal.get_name()
		if callable.get_object() is Node:
			callable_dict["path"] = callable.get_object().get_path()
		else:
			callable_dict["object_wref"] = weakref(callable.get_object())
		callable_dict["callable_copy"] = Callable(callable)
		callable_dict["method"] = callable.get_method()
		callable_dict["args"] = callable.get_bound_arguments()
		callable_dict["flags"] = connection["flags"]
		callables.append(callable_dict)
	snapshot["callables"] = callables
	return snapshot


static func apply_signal_snapshot(in_signal_origin: Object, in_signal_name: String, in_snapshot: Dictionary) -> void:
	var callables: Array[Dictionary] = in_snapshot["callables"]
	for idx in callables.size():
		var callable_dict: Dictionary = callables[idx]
		var signal_name: String = callable_dict["signal_name"]
		var flags: int = callable_dict["flags"]
		var method: String = callable_dict["method"]
		var args: Array = callable_dict["args"]
		var target_obj: Object = MolecularEditorContext.get_node_or_null(callable_dict["path"]) if callable_dict.has("path") else callable_dict["object_wref"].get_ref()
		var callable: Callable = callable_dict["callable_copy"]
		if is_instance_valid(target_obj):
			if not in_signal_origin.is_connected(signal_name,callable):
				in_signal_origin.connect(signal_name, Callable(target_obj, method).bindv(args), flags)


static func pack_signal(in_signal: Signal, in_target_object: Object) -> Dictionary:
	var output: Dictionary = {}
	var connections: Array = in_signal.get_connections()
	for connection: Dictionary in connections:
		var callable: Callable = connection["callable"]
		if in_target_object == callable.get_object():
			output[callable.get_method()] = callable.get_bound_arguments()
	return output


static func apply_signal_pack(in_pack: Dictionary, in_signal: Signal, in_target_object: Object) -> void:
	for method_name: StringName in in_pack:
		var args: Array = in_pack[method_name]
		var target_callable := Callable(in_target_object, method_name)
		if not in_signal.is_connected(target_callable):
			in_signal.connect(target_callable.bindv(args))


static func is_operation_whitelisted_during_simulation(in_operation_name: String) -> bool:
	return ACTION_WHITELIST_DURING_SIMULATION.has(in_operation_name)
