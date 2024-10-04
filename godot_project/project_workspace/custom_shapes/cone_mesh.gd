@tool
class_name ConeMesh extends CylinderMesh

const FULL_CIRCLE_RADIANS: float = PI * 2.0

func _init() -> void:
	cap_top = false
	top_radius = 0


func get_shape_name() -> StringName:
	return &"Cone"


func get_cover_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var atoms_in_height: int = floori(height / in_minimum_distance_between_atoms) + 1
	var vertical_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, height) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var cone_base: Vector3 = Vector3(0.0, -height * 0.5, 0.0)
	var initial_position: Vector3 = \
		Vector3.ZERO if in_fill_whole_shape else \
		Vector3.UP * (height - (atoms_in_height - 1) * vertical_distance_between_atoms) * 0.5
	for height_atom_idx: int in atoms_in_height:
		var current_height: float = \
			initial_position.length() + height_atom_idx * vertical_distance_between_atoms
		# Current max radius:
		# The external border of the cone can be thought of as a linear function
		# represented by a function in the form y = m * x + b
		# Starting from the two known points
		# P1: x1 = 0 y1 = height
		# P2: x2 = bottom_radius y2 = 0
		# and having
		# m = (y2 - y1) / (x2 - x1)
		# b = y1 - m * x1
		# we can get to the function
		# y = -h/r * x + h
		# After clearing x, we get:
		# x = r - (r/h * y)
		var current_max_radius: float = bottom_radius - ((bottom_radius / height) * current_height)
		var radius_distance_between_atoms: float = \
			NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, current_max_radius) \
			if in_fill_whole_shape else in_minimum_distance_between_atoms
		var atoms_in_current_max_radius: int = floori(current_max_radius / radius_distance_between_atoms) + 1
		for radius_atom_idx: int in atoms_in_current_max_radius:
			var radius: float = radius_distance_between_atoms * radius_atom_idx
			var atoms_in_circle_perimeter: int = \
				max(NanoMeshUtils.get_atoms_in_circle_perimeter(in_minimum_distance_between_atoms, radius * 2.0), 1)
			var rotation_increment: float = FULL_CIRCLE_RADIANS / atoms_in_circle_perimeter
			for circle_perimeter_atom_idx: int in atoms_in_circle_perimeter:
				#if height_atom_idx == 0 or radius_atom_idx == 0:
				if height_atom_idx == 0 or radius_atom_idx == (atoms_in_current_max_radius - 1):
					result.append(
						cone_base + 
						Vector3.UP * current_height +
						((Vector3.FORWARD * radius)
							* Quaternion(Vector3.UP, circle_perimeter_atom_idx * rotation_increment))
					)
	return result


func get_fill_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var atoms_in_height: int = floori(height / in_minimum_distance_between_atoms) + 1
	var vertical_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, height) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var cone_base: Vector3 = Vector3(0.0, -height * 0.5, 0.0)
	var initial_position: Vector3 = \
		Vector3.ZERO if in_fill_whole_shape else \
		Vector3.UP * (height - (atoms_in_height - 1) * vertical_distance_between_atoms) * 0.5
	for height_atom_idx: int in atoms_in_height:
		var current_height: float = \
			initial_position.length() + height_atom_idx * vertical_distance_between_atoms
		# Current max radius:
		# The external border of the cone can be thought of as a linear function
		# represented by a function in the form y = m * x + b
		# Starting from the two known points
		# P1: x1 = 0 y1 = height
		# P2: x2 = bottom_radius y2 = 0
		# and having
		# m = (y2 - y1) / (x2 - x1)
		# b = y1 - m * x1
		# we can get to the function
		# y = -h/r * x + h
		# After clearing x, we get:
		# x = r - (r/h * y)
		var current_max_radius: float = bottom_radius - ((bottom_radius / height) * current_height)
		var radius_distance_between_atoms: float = \
			NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, current_max_radius) \
			if in_fill_whole_shape else in_minimum_distance_between_atoms
		var atoms_in_current_max_radius: int = floori(current_max_radius / radius_distance_between_atoms) + 1
		for radius_atom_idx: int in atoms_in_current_max_radius:
			var radius: float = radius_distance_between_atoms * radius_atom_idx
			var atoms_in_circle_perimeter: int = \
				max(NanoMeshUtils.get_atoms_in_circle_perimeter(in_minimum_distance_between_atoms, radius * 2.0), 1)
			var rotation_increment: float = FULL_CIRCLE_RADIANS / atoms_in_circle_perimeter
			for circle_perimeter_atom_idx: int in atoms_in_circle_perimeter:
					result.append(
						cone_base + 
						Vector3.UP * current_height +
						((Vector3.FORWARD * radius)
							* Quaternion(Vector3.UP, circle_perimeter_atom_idx * rotation_increment))
					)
	return result
