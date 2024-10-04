@tool
class_name NanoBoxMesh extends BoxMesh

func get_shape_name() -> StringName:
	return &"Box"


func get_cover_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var atoms_per_axis: Vector3i = NanoMeshUtils.get_atoms_per_axis(in_minimum_distance_between_atoms, size)
	var distance_between_atoms: Vector3 = \
		NanoMeshUtils.get_inter_atom_distance(in_minimum_distance_between_atoms, size) \
		if in_fill_whole_shape else (Vector3.ONE * in_minimum_distance_between_atoms)
	var delta_initial_position: Vector3 = Vector3.ZERO if in_fill_whole_shape else \
		(size - ((atoms_per_axis - Vector3i.ONE) * in_minimum_distance_between_atoms)) * 0.5
	var new_atoms_initial_position: Vector3 = (-size * 0.5) + delta_initial_position
	for x_count: int in atoms_per_axis.x:
		for y_count: int in atoms_per_axis.y:
			for z_count: int in atoms_per_axis.z:
				if x_count == 0 or x_count == atoms_per_axis.x - 1 \
					or y_count == 0 or y_count == atoms_per_axis.y - 1 \
					or z_count == 0 or z_count == atoms_per_axis.z - 1:
					var atom_pos: Vector3 = new_atoms_initial_position + \
						Vector3(
							distance_between_atoms.x * x_count,
							distance_between_atoms.y * y_count,
							distance_between_atoms.z * z_count
						)
					result.append(atom_pos)
	return result

func get_fill_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var atoms_per_axis: Vector3i = NanoMeshUtils.get_atoms_per_axis(in_minimum_distance_between_atoms, size)
	var distance_between_atoms: Vector3 = \
		NanoMeshUtils.get_inter_atom_distance(in_minimum_distance_between_atoms, size) \
		if in_fill_whole_shape else (Vector3.ONE * in_minimum_distance_between_atoms)
	var delta_initial_position: Vector3 = Vector3.ZERO if in_fill_whole_shape else \
		(size - ((atoms_per_axis - Vector3i.ONE) * in_minimum_distance_between_atoms)) * 0.5
	var new_atoms_initial_position: Vector3 = (-size * 0.5) + delta_initial_position
	for x_count: int in atoms_per_axis.x:
		for y_count: int in atoms_per_axis.y:
			for z_count: int in atoms_per_axis.z:
				var atom_pos: Vector3 = new_atoms_initial_position + \
					Vector3(
						distance_between_atoms.x * x_count,
						distance_between_atoms.y * y_count,
						distance_between_atoms.z * z_count
					)
				result.append(atom_pos)
	return result
