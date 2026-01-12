class_name OptionalPackedStringArray

var is_set: bool
var value: PackedStringArray


static var _empty: OptionalPackedStringArray
static func empty() -> OptionalPackedStringArray:
	if _empty == null:
		_empty = OptionalPackedStringArray.new([])
		_empty.is_set = false
	return _empty


func _init(in_value: PackedStringArray) -> void:
	is_set = true
	value = in_value
