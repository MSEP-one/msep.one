@tool
class_name NanoPrismMesh extends PrismMesh


func get_shape_name() -> StringName:
	return &"Prism"


func get_cover_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var height: float = size.y
	var atoms_in_height: int = floori(height / in_minimum_distance_between_atoms) + 1
	var vertical_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, height) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var depth: float = size.z
	var atoms_in_depth: int = floori(depth / in_minimum_distance_between_atoms) + 1
	var longitudinal_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, depth) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var width: float = size.x
	var left_side_base_length: float = width * left_to_right
	var right_side_base_lenth: float = width - left_side_base_length
	var prism_base: Vector3 = Vector3(width * (left_to_right - 0.5), -height * 0.5, -depth * 0.5)
	var delta_initial_position: Vector3 = Vector3.ZERO
	if not in_fill_whole_shape:
		delta_initial_position.y = \
			(height - (atoms_in_height - 1) * in_minimum_distance_between_atoms) * 0.5
		delta_initial_position.z = \
			(depth - (atoms_in_depth - 1) * in_minimum_distance_between_atoms) * 0.5
	for vertical_atom_idx in atoms_in_height:
		for longitudinal_atom_idx in atoms_in_depth:
			# x = r - (r/h * y)
			var current_height: float = delta_initial_position.y + vertical_atom_idx * vertical_distance_between_atoms
			var distance_to_left_side: float = \
				left_side_base_length - (left_side_base_length/height * current_height)
			# x = r - (r/h * y)
			var distance_to_right_side: float = \
				right_side_base_lenth - (right_side_base_lenth/height * current_height)
			var total_horizontal_length: float = \
				distance_to_left_side + distance_to_right_side
			var atoms_in_total_horizontal_length: float = \
				floori(total_horizontal_length / in_minimum_distance_between_atoms) + 1
			var horizontal_distance_between_atoms: float = \
				NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, total_horizontal_length) \
				if in_fill_whole_shape else in_minimum_distance_between_atoms
			if not in_fill_whole_shape:
				delta_initial_position.x = \
					(total_horizontal_length - (atoms_in_total_horizontal_length - 1) * in_minimum_distance_between_atoms) * 0.5
			for horizontal_atom_idx: int in atoms_in_total_horizontal_length:
				if vertical_atom_idx == 0 \
					or (longitudinal_atom_idx == 0 or longitudinal_atom_idx == atoms_in_depth -1) \
					or (horizontal_atom_idx == 0) \
					or (horizontal_atom_idx == atoms_in_total_horizontal_length - 1):
					result.append(
						prism_base  
						+ delta_initial_position
						- Vector3(distance_to_left_side, 0.0, 0.0)
						+ Vector3(
							horizontal_atom_idx * horizontal_distance_between_atoms,
							vertical_atom_idx * vertical_distance_between_atoms,
							longitudinal_atom_idx * longitudinal_distance_between_atoms
						)
					)
	return result


func get_fill_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var height: float = size.y
	var atoms_in_height: int = floori(height / in_minimum_distance_between_atoms) + 1
	var vertical_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, height) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var depth: float = size.z
	var atoms_in_depth: int = floori(depth / in_minimum_distance_between_atoms) + 1
	var longitudinal_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, depth) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var width: float = size.x
	var left_side_base_length: float = width * left_to_right
	var right_side_base_lenth: float = width - left_side_base_length
	var prism_base: Vector3 = Vector3(width * (left_to_right - 0.5), -height * 0.5, -depth * 0.5)
	var delta_initial_position: Vector3 = Vector3.ZERO
	if not in_fill_whole_shape:
		delta_initial_position.y = \
			(height - (atoms_in_height - 1) * in_minimum_distance_between_atoms) * 0.5
		delta_initial_position.z = \
			(depth - (atoms_in_depth - 1) * in_minimum_distance_between_atoms) * 0.5
	for vertical_atom_idx in atoms_in_height:
		for longitudinal_atom_idx in atoms_in_depth:
			# x = r - (r/h * y)
			var current_height: float = delta_initial_position.y + vertical_atom_idx * vertical_distance_between_atoms
			var distance_to_left_side: float = \
				left_side_base_length - (left_side_base_length/height * current_height)
			# x = r - (r/h * y)
			var distance_to_right_side: float = \
				right_side_base_lenth - (right_side_base_lenth/height * current_height)
			var total_horizontal_length: float = \
				distance_to_left_side + distance_to_right_side
			var atoms_in_total_horizontal_length: float = \
				floori(total_horizontal_length / in_minimum_distance_between_atoms) + 1
			var horizontal_distance_between_atoms: float = \
				NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, total_horizontal_length) \
				if in_fill_whole_shape else in_minimum_distance_between_atoms
			if not in_fill_whole_shape:
				delta_initial_position.x = \
					(total_horizontal_length - (atoms_in_total_horizontal_length - 1) * in_minimum_distance_between_atoms) * 0.5
			for horizontal_atom_idx: int in atoms_in_total_horizontal_length:
				result.append(
					prism_base
					+ delta_initial_position
					- Vector3(distance_to_left_side, 0.0, 0.0)
					+ Vector3(
						horizontal_atom_idx * horizontal_distance_between_atoms,
						vertical_atom_idx * vertical_distance_between_atoms,
						longitudinal_atom_idx * longitudinal_distance_between_atoms
					)
				)
	return result
