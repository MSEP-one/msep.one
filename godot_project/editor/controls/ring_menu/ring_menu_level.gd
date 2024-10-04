class_name RingMenuLevel extends RefCounted


var _actions: Array[RingMenuAction] = []
var _title: String = ""
var _description: String = ""

func _init(in_actions: Array[RingMenuAction] = [], in_title: String = "", in_description: String = "") -> void:
	_title = in_title
	_description = in_description
	for action: RingMenuAction in in_actions:
		add_action(action as RingMenuAction)


func add_action(action: RingMenuAction) -> void:
	if is_instance_valid(action):
		_actions.push_back(action)


func get_actions() -> Array[RingMenuAction]:
	return _actions


func get_title() -> String:
	return _title


func get_description() -> String:
	return _description


func clear() -> void:
	_actions.clear()
