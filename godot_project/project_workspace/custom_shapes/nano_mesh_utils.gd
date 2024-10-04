class_name NanoMeshUtils

static func get_atoms_per_axis(in_atom_diameter: float, in_size: Vector3) -> Vector3i:
	var atoms_per_axis: Vector3 = in_size / in_atom_diameter
	return Vector3i(atoms_per_axis.floor()) + Vector3i.ONE


static func get_inter_atom_distance_in_length(in_atom_diameter: float, in_length: float) -> float:
	var atoms_in_length: float = in_length / in_atom_diameter
	var inter_atom_distance: float = atoms_in_length - floor(atoms_in_length)
	atoms_in_length = floor(atoms_in_length) + 1.0
	return in_atom_diameter + (0.0 if atoms_in_length <= 1 else
		inter_atom_distance / float(atoms_in_length - 1) * in_atom_diameter)


static func calculate_distance_between_atoms(in_atom_diameter: float, in_length: float) -> float:
	var atoms_in_length: float = in_length / in_atom_diameter
	var distance_between_atoms: float = atoms_in_length - floor(atoms_in_length)
	atoms_in_length = floor(distance_between_atoms) + 1.0
	return in_atom_diameter + (0.0 if atoms_in_length <= 1 else
		distance_between_atoms / float(atoms_in_length - 1) * in_atom_diameter)



static func get_inter_atom_distance(in_atom_diameter: float, in_size: Vector3) -> Vector3:
	return Vector3(
		get_inter_atom_distance_in_length(in_atom_diameter, in_size.x),
		get_inter_atom_distance_in_length(in_atom_diameter, in_size.y),
		get_inter_atom_distance_in_length(in_atom_diameter, in_size.z)
	)


static func get_atoms_in_circle_perimeter(
	in_atom_diameter: float, 
	in_shape_diameter: float) -> int:
	if in_shape_diameter < in_atom_diameter:
		return 1
	var circle_perimeter: float = in_shape_diameter * PI
	var atoms_in_circle_perimeter: float = circle_perimeter / in_atom_diameter
	return floori(atoms_in_circle_perimeter)


static func get_atoms_in_semi_circle_perimeter(
	in_atom_diameter: float, 
	in_shape_diameter: float) -> int:
	return get_atoms_in_circle_perimeter(in_atom_diameter, in_shape_diameter * 0.5)


static func minimum_radius_for_atom_count_in_circle_perimeter(
	in_minimum_distance_between_atoms: float, 
	in_atom_count: int) -> float:
	return (in_atom_count * in_minimum_distance_between_atoms) / (2 * PI)
