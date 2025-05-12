class_name SimulationBoundariesRepresentation extends MeshInstance3D

func _init() -> void:
	hide()

func setup(in_aabb: AABB) -> void:
	var box: BoxMesh = mesh as BoxMesh
	box.size = in_aabb.size
	global_position = in_aabb.get_center()
