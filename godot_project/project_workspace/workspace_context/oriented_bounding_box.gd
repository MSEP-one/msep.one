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
var point_cloud_source: Dictionary[StructureContext, PackedInt32Array] = {
	# context : atom_ids
}


var _initialized: bool = false


func _init(in_size: Vector3, in_transform: Transform3D, in_source: Dictionary[StructureContext, PackedInt32Array]) -> void:
	box = AABB()
	box.position = -in_size / 2.0
	box.size = in_size
	point_cloud_source = in_source
	point_cloud_source.make_read_only()
	transform = in_transform
	_initialized = true
