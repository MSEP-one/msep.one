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


func get_face_corners(face_normal: Vector3) -> PackedVector3Array:
	const C := [
		Vector3(-1, 1, -1), # 0 Top Front Left
		Vector3(1, 1, -1), # 1 Top Front right
		Vector3(1, 1, 1), # 2 Top Back Right
		Vector3(-1, 1, 1), # 3 Top Back Left
		Vector3(-1, -1, -1), # 4 Bottom Front Left
		Vector3(1, -1, -1), # 5 Bottom Front Right
		Vector3(1, -1, 1), # 6 Bottom Back Right
		Vector3(-1, -1, 1), # 7 Bottom Back Left
	]
	var corners: Array[Vector3]
	match face_normal:
		Vector3.UP:
			corners = [C[0], C[1], C[2], C[3]]
		Vector3.DOWN:
			corners = [C[4], C[5], C[6], C[7]]
		Vector3.FORWARD:
			corners = [C[0], C[1], C[5], C[4]]
		Vector3.BACK:
			corners = [C[3], C[2], C[6], C[7]]
		Vector3.LEFT:
			corners = [C[0], C[3], C[7], C[4]]
		Vector3.RIGHT:
			corners = [C[1], C[2], C[6], C[5]]
	
	var result := PackedVector3Array()
	var half_size: Vector3 = box.size * .5
	for local_point in corners:
		result.push_back(transform * (local_point * half_size))
	
	return result
