extends RefCounted
class_name OBB


var box: AABB:
	set(v):
		assert(_initialized == false, "Value cannot be changed upon creation")
		box = v
var transform: Transform3D:
	set(v):
		assert(_initialized == false, "Value cannot be changed upon creation")
		transform = v


var _initialized: bool = false


func _init(in_size: Vector3, in_transform: Transform3D) -> void:
	box = AABB()
	box.position = -in_size / 2.0
	box.size = in_size
	transform = in_transform
	_initialized = true
