@tool
class_name NanoCapsuleMesh extends CapsuleMesh

const FULL_CIRCLE_RADIANS: float = PI * 2.0

func get_shape_name() -> StringName:
	return &"Capsule"


func get_cover_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var cylinder_height: float = height - 2.0 * radius
	var cylinder_height_adjusted_for_semisphere_caps: float = cylinder_height - in_minimum_distance_between_atoms
	var atoms_in_adjusted_cylinder_height: int = \
		max(floori(cylinder_height_adjusted_for_semisphere_caps / in_minimum_distance_between_atoms) + 1, 1)
	var cylinder_vertical_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(
			in_minimum_distance_between_atoms, cylinder_height_adjusted_for_semisphere_caps
		) if in_fill_whole_shape else in_minimum_distance_between_atoms
	var atoms_in_radius: int = floori(radius / in_minimum_distance_between_atoms) + 1
	var radius_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, radius) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var cylinder_base: Vector3 = Vector3(0.0, -cylinder_height_adjusted_for_semisphere_caps * 0.5, 0.0)
	var delta_initial_position: Vector3 = Vector3.ZERO if in_fill_whole_shape else \
		Vector3.UP * (cylinder_height_adjusted_for_semisphere_caps - ((atoms_in_adjusted_cylinder_height - 1) * in_minimum_distance_between_atoms)) * 0.5
	# Cylinder
	var current_radius: float = radius_distance_between_atoms * (atoms_in_radius - 1)
	var atoms_in_circle_perimeter: int = \
		max(NanoMeshUtils.get_atoms_in_circle_perimeter(in_minimum_distance_between_atoms, current_radius * 2.0), 1)
	var rotation_increment: float = FULL_CIRCLE_RADIANS / atoms_in_circle_perimeter
	for vertical_atom_idx: int in atoms_in_adjusted_cylinder_height:
		for rotation_idx: int in atoms_in_circle_perimeter:
			result.append(
				cylinder_base + delta_initial_position +
				Vector3.UP * (vertical_atom_idx * cylinder_vertical_distance_between_atoms) +
				((Vector3.FORWARD * radius)
					* Quaternion(Vector3.UP, rotation_idx * rotation_increment))
			)
	# SemiSpheres
	result.append_array(
		_get_cover_caps_atom_positions(in_minimum_distance_between_atoms, radius, cylinder_height, delta_initial_position.y)
	)
	return result

func _get_cover_caps_atom_positions(
	in_minimum_distance_between_atoms: float,
	in_radius: float,
	in_cylinder_height: float,
	in_delta_initial_position: float) -> PackedVector3Array:
	var result: PackedVector3Array = []
	if in_radius * 2.0 < in_minimum_distance_between_atoms:
		return result
	var atoms_in_semi_circle_perimeter: int = \
		max(NanoMeshUtils.get_atoms_in_semi_circle_perimeter(in_minimum_distance_between_atoms, in_radius * 2.0), 1)
	atoms_in_semi_circle_perimeter += \
		0 if atoms_in_semi_circle_perimeter % 2 == 0 else 1
	var vertical_rotation_increment: float = \
		(FULL_CIRCLE_RADIANS * 0.5) / (atoms_in_semi_circle_perimeter - 1)
	var atom_marker_position: Vector3 = Vector3.ZERO
	var atoms_outer_positions: Array[Vector3] = []
	for atom_semi_circle_perimeter_idx: int in atoms_in_semi_circle_perimeter:
		atom_marker_position = \
			((Vector3.UP * in_radius) * Quaternion(Vector3.FORWARD, atom_semi_circle_perimeter_idx * vertical_rotation_increment))
		atoms_outer_positions.push_back(atom_marker_position)
	for outer_position_atom_idx: int in atoms_outer_positions.size():
		var current_outter_position: Vector3 = atoms_outer_positions[outer_position_atom_idx]
		current_outter_position.y += \
			(0.5 * in_cylinder_height) * signf(current_outter_position.y)
		current_outter_position.y -= \
			in_delta_initial_position * signf(current_outter_position.y)
		var current_max_radius: float = abs(atoms_outer_positions[outer_position_atom_idx].x)
		var atoms_in_circle_perimeter: int = \
			max(NanoMeshUtils.get_atoms_in_circle_perimeter(in_minimum_distance_between_atoms, current_max_radius * 2.0), 1)
		var rotation_increment: float = FULL_CIRCLE_RADIANS / atoms_in_circle_perimeter
		for atom_circle_perimeter_idx: int in atoms_in_circle_perimeter:
			result.append(
				current_outter_position * Quaternion(Vector3.UP, atom_circle_perimeter_idx * rotation_increment)
			)
	return result


func get_fill_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var cylinder_height: float = height - 2.0 * radius
	var cylinder_height_adjusted_for_semisphere_caps: float = cylinder_height - in_minimum_distance_between_atoms
	var atoms_in_adjusted_cylinder_height: int = \
		max(floori(cylinder_height_adjusted_for_semisphere_caps / in_minimum_distance_between_atoms) + 1, 1)
	var cylinder_vertical_inter_atom_distance: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(
			in_minimum_distance_between_atoms, cylinder_height_adjusted_for_semisphere_caps
		) if in_fill_whole_shape else in_minimum_distance_between_atoms
	var atoms_in_radius: int = floori(radius / in_minimum_distance_between_atoms) + 1
	var radius_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, radius) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var cylinder_base: Vector3 = Vector3(0.0, -cylinder_height_adjusted_for_semisphere_caps * 0.5, 0.0)
	var delta_initial_position: Vector3 = Vector3.ZERO if in_fill_whole_shape else \
		Vector3.UP * (cylinder_height_adjusted_for_semisphere_caps - ((atoms_in_adjusted_cylinder_height - 1) * in_minimum_distance_between_atoms)) * 0.5
	# Cylinder
	for atom_ring_idx: int in atoms_in_radius:
		var current_radius: float = radius_distance_between_atoms * atom_ring_idx
		var atoms_in_circle_perimeter: int = \
			max(NanoMeshUtils.get_atoms_in_circle_perimeter(in_minimum_distance_between_atoms, current_radius * 2.0), 1)
		var rotation_increment: float = FULL_CIRCLE_RADIANS / atoms_in_circle_perimeter
		for vertical_atom_idx: int in atoms_in_adjusted_cylinder_height:
			for rotation_idx: int in atoms_in_circle_perimeter:
				result.append(
					cylinder_base + delta_initial_position +
					Vector3.UP * (vertical_atom_idx * cylinder_vertical_inter_atom_distance) +
					((Vector3.FORWARD * (atom_ring_idx * radius_distance_between_atoms))
						* Quaternion(Vector3.UP, rotation_idx * rotation_increment))
				)
	# SemiSpheres
	for radius_atom_idx: int in atoms_in_radius:
		result.append_array(
			_get_cover_caps_atom_positions(
				in_minimum_distance_between_atoms, 
				radius_distance_between_atoms * radius_atom_idx, 
				cylinder_height,
				delta_initial_position.y
			)
		)
	return result
