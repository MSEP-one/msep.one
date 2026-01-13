class_name OptionalArrayOfDictionaries

var is_set: bool
var value: Array[Dictionary]


static var _empty: OptionalArrayOfDictionaries
static func empty() -> OptionalArrayOfDictionaries:
	if _empty == null:
		_empty = OptionalArrayOfDictionaries.new([])
		_empty.is_set = false
	return _empty


func _init(in_value: Array[Dictionary]) -> void:
	is_set = true
	value = in_value
