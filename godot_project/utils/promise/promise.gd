class_name Promise extends RefCounted
# # # #
## Simple Promise implementation. 
## Sample usage:
## var promise: Promise = async_compute_value()
## await(promise.wait_for_fulfill()
## assert(promise.is_correct(), promise.get_error())
## var computed_value: float = promise.get_result() as float

signal _fulfilled


var _error: String = ""
var _result: Variant = null
var _is_fulfilled: bool = false


func is_pending() -> bool:
	return not _is_fulfilled


func is_fulfilled() -> bool:
	return _is_fulfilled


func is_correct() -> bool:
	return not has_error()


func get_result() -> Variant:
	return _result


func has_error() -> bool:
	return not _error.is_empty()


func get_error() -> String:
	return _error


func fail(in_error: String, in_result: Variant = null) -> void:
	_error = in_error
	fulfill(in_result)


func fulfill(in_result: Variant) -> void:
	assert(not _is_fulfilled, "Promise object can be used only once")
	_is_fulfilled = true
	_result = in_result
	_fulfill_emit()


func wait_for_fulfill() -> void:
	if not _is_fulfilled:
		await(_fulfilled)


func _fulfill_emit() -> void:
	_fulfilled.emit()
	for connection: Dictionary in _fulfilled.get_connections():
		_fulfilled.disconnect(connection["callable"])
