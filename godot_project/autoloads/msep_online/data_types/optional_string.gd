class_name OptionalString

var is_set: bool
var value: String


static var _empty: OptionalString
static func empty() -> OptionalString:
	if _empty == null:
		_empty = OptionalString.new("")
		_empty.is_set = false
	return _empty


func _init(in_value: String) -> void:
	is_set = true
	value = in_value
