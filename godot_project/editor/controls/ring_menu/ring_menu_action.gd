class_name RingMenuAction extends RefCounted

var _title: String = ""
var _description: String = ""
var _action: Callable = Callable()
var _validation_callback := Callable()


func _init(in_title: String, in_action: Callable, in_description: String) -> void:
	_title = in_title
	_description = in_description
	_action = in_action


func get_icon() -> RingMenuIcon:
	assert(false, "Method needs to be implemented")
	return null


func with_validation(in_validation_callback: Callable) -> RingMenuAction:
	_validation_callback = in_validation_callback
	return self


func get_validation_problem_description() -> String:
	# Override this method when needed
	return ""


func can_execute() -> bool:
	if _validation_callback.is_valid():
		var validation_result: bool = _validation_callback.call() as bool
		return validation_result
	return true


func execute() -> void:
	if _action.is_valid():
		_action.call()


func get_title() -> String:
	return _title


func get_description() -> String:
	return _description
