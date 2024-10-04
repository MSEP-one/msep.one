@tool
class_name NanoTorusMesh extends TorusMesh


const FULL_CIRCLE_RADIANS: float = PI * 2.0


func get_shape_name() -> StringName:
	return &"Torus"


func get_cover_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var radius: float = (outer_radius - inner_radius) * 0.5
	var atoms_in_radius: int = \
		floori(radius / in_minimum_distance_between_atoms) + 1
	if not in_fill_whole_shape:
		radius = atoms_in_radius * in_minimum_distance_between_atoms
	return _get_cover_atoms_positions(in_minimum_distance_between_atoms, radius)


func _get_cover_atoms_positions(
	in_minimum_distance_between_atoms: float,  
	in_current_radius: float) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var height: float = in_current_radius * 2.0
	var delta_radius: float = (outer_radius - inner_radius) * 0.5 - in_current_radius
	var atoms_in_vertical_circle_perimeter: int = \
		NanoMeshUtils.get_atoms_in_circle_perimeter(in_minimum_distance_between_atoms, height)
	var vertical_rotation_increment: float = \
		FULL_CIRCLE_RADIANS / max((atoms_in_vertical_circle_perimeter - 1), 1)
	var atom_marker_position: Vector3 = Vector3.ZERO
	var atoms_outer_positions: Array[Vector3] = []
	for atom_idx: int in atoms_in_vertical_circle_perimeter:
		atom_marker_position = \
			((Vector3.UP * in_current_radius) * Quaternion(Vector3.FORWARD, atom_idx * vertical_rotation_increment))
		atoms_outer_positions.push_back(atom_marker_position)
	for current_outter_position: Vector3 in atoms_outer_positions:
		var current_radius: float = \
			in_current_radius - current_outter_position.x + inner_radius + delta_radius
		var atoms_in_horizontal_circle_perimeter: int = \
			NanoMeshUtils.get_atoms_in_circle_perimeter(in_minimum_distance_between_atoms, current_radius * 2.0)
		var horizontal_rotation_increment: float = \
			FULL_CIRCLE_RADIANS / float(atoms_in_horizontal_circle_perimeter)
		for rotation_idx: int in atoms_in_horizontal_circle_perimeter:
			result.append(
				Vector3.UP * current_outter_position.y + 
				((Vector3.FORWARD * current_radius)
					* Quaternion(Vector3.UP, rotation_idx * horizontal_rotation_increment))
			)
	return result


func get_fill_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var radius: float = (outer_radius - inner_radius) * 0.5
	var atoms_in_radius: int = \
		floori(radius / in_minimum_distance_between_atoms) + 1
	if not in_fill_whole_shape:
		radius = atoms_in_radius * in_minimum_distance_between_atoms
	var radius_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, radius) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	for atom_idx: int in atoms_in_radius:
		result.append_array(
			_get_cover_atoms_positions(
				in_minimum_distance_between_atoms,
				radius_distance_between_atoms * atom_idx
			)
		)
	return result
