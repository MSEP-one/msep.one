@tool
class_name NanoSphereMesh extends SphereMesh

const FULL_CIRCLE_RADIANS: float = PI * 2.0

func get_shape_name() -> StringName:
	return &"Sphere"


func get_cover_atoms_positions(in_minimum_distance_between_atoms: float, _in_fill_whole_shape: bool) -> PackedVector3Array:
	return _get_cover_atoms_positions(in_minimum_distance_between_atoms, radius, height)


func _get_cover_atoms_positions(in_minimum_distance_between_atoms: float, in_radius: float, in_height: float) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var atoms_in_semi_circle_perimeter: int = \
		NanoMeshUtils.get_atoms_in_semi_circle_perimeter(in_minimum_distance_between_atoms, in_height)
	var vertical_rotation_increment: float = \
		(FULL_CIRCLE_RADIANS * 0.5) / max((atoms_in_semi_circle_perimeter - 1), 1)
	var atom_marker_position: Vector3 = Vector3.ZERO
	var atoms_outer_positions: Array[Vector3] = []
	for atom_semi_circle_perimeter_idx: int in atoms_in_semi_circle_perimeter:
		atom_marker_position = \
			(Vector3.UP * in_radius) \
			* Quaternion(Vector3.FORWARD, atom_semi_circle_perimeter_idx * vertical_rotation_increment)
		atoms_outer_positions.push_back(atom_marker_position)
	for outer_position_atom_idx: int in atoms_outer_positions.size():
		var current_outter_position: Vector3 = atoms_outer_positions[outer_position_atom_idx]
		var current_max_radius: float = abs(atoms_outer_positions[outer_position_atom_idx].x)
		var atoms_in_circle_perimeter: int = \
			max(NanoMeshUtils.get_atoms_in_circle_perimeter(in_minimum_distance_between_atoms, current_max_radius * 2.0), 1)
		var rotation_increment: float = FULL_CIRCLE_RADIANS / atoms_in_circle_perimeter
		for atom_circle_perimeter_idx: int in atoms_in_circle_perimeter:
			result.append(
				current_outter_position 
				* Quaternion(Vector3.UP, atom_circle_perimeter_idx * rotation_increment)
			)
	return result

func get_fill_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var radius_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, radius) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var atoms_in_radius: int = floori(radius / radius_distance_between_atoms) + 1
	for radius_atom_idx: int in atoms_in_radius:
		result.append_array(
			_get_cover_atoms_positions(
				in_minimum_distance_between_atoms, 
				radius_distance_between_atoms * radius_atom_idx, 
				radius_distance_between_atoms * radius_atom_idx * 2.0
			)
		)
	return result
