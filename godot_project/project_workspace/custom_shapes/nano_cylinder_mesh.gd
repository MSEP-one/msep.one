@tool
class_name NanoCylinderMesh extends CylinderMesh

const FULL_CIRCLE_RADIANS: float = PI * 2.0

func get_shape_name() -> StringName:
	return &"Cylinder"


func get_cover_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	assert(bottom_radius == top_radius, "Bottom radius and top radius do not match")
	var result: PackedVector3Array = []
	var cylinder_size: Vector3 = Vector3(bottom_radius * 2.0, height, bottom_radius * 2.0)
	var atoms_per_axis: Vector3i = \
		NanoMeshUtils.get_atoms_per_axis(in_minimum_distance_between_atoms, cylinder_size)
	var atoms_in_radius: int = floori(bottom_radius / in_minimum_distance_between_atoms) + 1
	var atoms_in_height: int = atoms_per_axis.y
	var distance_between_atoms: Vector3 = \
		NanoMeshUtils.get_inter_atom_distance(in_minimum_distance_between_atoms, cylinder_size) \
		if in_fill_whole_shape else (Vector3.ONE * in_minimum_distance_between_atoms)
	var cylinder_base: Vector3 = Vector3(0.0, -height * 0.5, 0.0)
	var delta_initial_position: Vector3 = Vector3.ZERO if in_fill_whole_shape else \
		Vector3.UP * (height - ((atoms_in_height - 1) * in_minimum_distance_between_atoms)) * 0.5
	var longitudinal_axis: Vector3 = Vector3.UP
	for atom_ring_idx: int in atoms_in_radius:
		var radius: float = distance_between_atoms.x * atom_ring_idx
		var atoms_in_circle_perimeter: int = \
			NanoMeshUtils.get_atoms_in_circle_perimeter(in_minimum_distance_between_atoms, radius * 2.0)
		var rotation_increment: float = FULL_CIRCLE_RADIANS / atoms_in_circle_perimeter
		for vertical_atom_idx: int in atoms_in_height:
			for rotation_idx: int in atoms_in_circle_perimeter:
				if vertical_atom_idx == 0 or atom_ring_idx == atoms_in_radius - 1 \
					or vertical_atom_idx == atoms_in_height - 1:
					result.append(
						cylinder_base + delta_initial_position +
						longitudinal_axis * (vertical_atom_idx * distance_between_atoms.y) +
						((Vector3.FORWARD * radius)
							* Quaternion(longitudinal_axis, rotation_idx * rotation_increment))
					)
	return result


func get_fill_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	assert(bottom_radius == top_radius, "Bottom radius and top radius do not match")
	var result: PackedVector3Array = []
	var cylinder_size: Vector3 = Vector3(bottom_radius * 2.0, height, bottom_radius * 2.0)
	var atoms_per_axis: Vector3i = \
		NanoMeshUtils.get_atoms_per_axis(in_minimum_distance_between_atoms, cylinder_size)
	var atoms_in_radius: int = floori(bottom_radius / in_minimum_distance_between_atoms) + 1
	var atoms_in_height: int = atoms_per_axis.y
	var distance_between_atoms: Vector3 = \
		NanoMeshUtils.get_inter_atom_distance(in_minimum_distance_between_atoms, cylinder_size) \
		if in_fill_whole_shape else (Vector3.ONE * in_minimum_distance_between_atoms)
	var cylinder_base: Vector3 = Vector3(0.0, -height * 0.5, 0.0)
	var delta_initial_position: Vector3 = Vector3.ZERO if in_fill_whole_shape else \
		Vector3.UP * (height - ((atoms_in_height - 1) * in_minimum_distance_between_atoms)) * 0.5
	var longitudinal_axis: Vector3 = Vector3.UP
	for atom_ring_idx: int in atoms_in_radius:
		var radius: float = distance_between_atoms.x * atom_ring_idx
		var atoms_in_circle_perimeter: int = \
			NanoMeshUtils.get_atoms_in_circle_perimeter(in_minimum_distance_between_atoms, radius * 2.0)
		var rotation_increment: float = FULL_CIRCLE_RADIANS / atoms_in_circle_perimeter
		for vertical_atom_idx: int in atoms_in_height:
			for rotation_idx: int in atoms_in_circle_perimeter:
				result.append(
					cylinder_base + delta_initial_position +
					longitudinal_axis * (vertical_atom_idx * distance_between_atoms.y) +
					((Vector3.FORWARD * radius)
						* Quaternion(longitudinal_axis, rotation_idx * rotation_increment))
				)
	return result
