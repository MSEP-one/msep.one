@tool
class_name PyramidMesh extends PrimitiveMesh

@export_range(3, 4, 1, "or_greater") var sides: int = 4:
	set(v):
		sides = v
		request_update()
@export_range(0.0, 1000, 0.001, "or_greater") var base_size: float = 10:
	set(v):
		base_size = v
		request_update()
	get:
		return base_size
@export_range(0.0, 1000, 0.001, "or_greater") var height: float = 20:
	set(v):
		height = v
		request_update()
	get:
		return height
@export var cap_bottom: bool = true:
	set(v):
		cap_bottom = v
		request_update()
	get:
		return cap_bottom

func get_shape_name() -> StringName:
	return &"Pyramid"


func set_sides(in_sides: int) -> void:
	sides = in_sides


func get_sides() -> int:
	return sides


func set_base_size(in_base_size: float) -> void:
	base_size = in_base_size


func get_base_size() -> float:
	return base_size


func set_height(in_height: float) -> void:
	height = in_height


func get_height() -> float:
	return height


func request_update() -> void:
	_update()


func _create_mesh_array() -> Array:
	var vertexes := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var bone_weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	
	# Vertexes:
	vertexes.resize(sides + 1)
	vertexes[0] = Vector3(0, height, 0) # The tip of the piramid
	var dir := Vector3(0.0, 0.0 ,1.0)
	var delta_angle: float = (PI * 2.0) / sides
	for v in range(sides):
		vertexes[v+1] = dir * (base_size * 0.5)
		dir = dir.rotated(Vector3.UP, delta_angle)
	if cap_bottom:
		# Adding an extra vertex on the origin to close the shape
		vertexes.push_back(Vector3())
	
	# Normals
	normals.resize(vertexes.size())
	var shape_center := Vector3(0, 1.0, 0)
	for i in range(vertexes.size()):
		normals[i] = (vertexes[i] - shape_center).normalized()
	
	# Tangents
	tangents.resize(vertexes.size() * 4)
	# Top of the piramid
	tangents[0] = 1.0
	tangents[1] = 0.0
	tangents[2] = 0.0
	tangents[3] = 1.0
	for side: int in range(sides):
		var i: int = side * 4 + 4
		tangents[i + 0] = 0.0
		tangents[i + 1] = 1.0
		tangents[i + 2] = 0.0
		tangents[i + 3] = 1.0
	if cap_bottom:
		# Adding an extra vertex on the origin to close the shape
		var i: int = sides * 4 + 4
		tangents[i + 0] = 0.0
		tangents[i + 1] = 0.0
		tangents[i + 2] = 1.0
		tangents[i + 3] = 1.0
	
	# Colors
	colors.resize(vertexes.size())
	for i in range(vertexes.size()):
		colors[i] = Color.WHITE
	
	# UVs
	uvs.resize(sides + 1)
	uvs[0] = Vector2(0.5, 0.5) # The tip of the piramid takes the center of the texture
	var uv_corner := Vector2(0, 0.5)
	for v in range(sides):
		uvs[v+1] = Vector2(0.5, 0.5) + uv_corner
		uv_corner = uv_corner.rotated(delta_angle)
	if cap_bottom:
		uvs.push_back(Vector2(0.5, 0.5))
	
	# Bones:
	bones.resize(vertexes.size() * 4)
	bones.fill(0)
	bone_weights.resize(vertexes.size() * 4)
	bone_weights.fill(0)
	
	# Indices:
	indices.resize(sides * (6 if cap_bottom else 3))
	for side in range(sides):
		var i: int = side * (6 if cap_bottom else 3)
		# pyramid side
		indices[i + 0] = 0 # Always the tip
		indices[i + 1] = 1 + ((side + 1) % sides)
		indices[i + 2] = side + 1
		# bottom face
		if cap_bottom:
			i += 3
			indices[i + 0] = side + 1
			indices[i + 1] = 1 + ((side + 1) % sides)
			indices[i + 2] = vertexes.size()-1 # Always the origin
	
	var surface: Array = []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = vertexes
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_TANGENT] = tangents
	surface[Mesh.ARRAY_COLOR] = colors
	surface[Mesh.ARRAY_TEX_UV] = uvs
	surface[Mesh.ARRAY_TEX_UV2] = uvs
	surface[Mesh.ARRAY_CUSTOM0] = null
	surface[Mesh.ARRAY_CUSTOM1] = null
	surface[Mesh.ARRAY_CUSTOM2] = null
	surface[Mesh.ARRAY_CUSTOM3] = null
	surface[Mesh.ARRAY_BONES] = bones
	surface[Mesh.ARRAY_WEIGHTS] = bone_weights
	surface[Mesh.ARRAY_INDEX] = indices
	
	return surface

func get_cover_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var angular_increment: float = 2.0 * PI / float(sides)
	var atoms_in_height: int = floori(height / in_minimum_distance_between_atoms) + 1
	var vertical_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, height) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var initial_position: Vector3 = \
		Vector3.ZERO if in_fill_whole_shape else \
		Vector3.UP * (height - (atoms_in_height - 1) * vertical_distance_between_atoms) * 0.5
	# Calculate the minimum radius to fit one atom per radial segment without overlapping
	# (Radial segments go, for a given height, from the vertical axis of the pyramid to
	# one of the edges)
	var minimum_radius: float = \
		NanoMeshUtils.minimum_radius_for_atom_count_in_circle_perimeter(
			in_minimum_distance_between_atoms, sides
		)
	for vertical_atom_idx: int in atoms_in_height:
		var current_height: Vector3 = \
			initial_position + Vector3.UP * vertical_atom_idx * vertical_distance_between_atoms
		var current_max_radius: float = _get_radius(current_height.length())
		var current_apothema_length: float = _get_apothema_length(current_max_radius)
		var atoms_in_current_apothema: int = 0
		atoms_in_current_apothema = \
			floori(current_apothema_length / in_minimum_distance_between_atoms) + 1 \
			if current_apothema_length >= minimum_radius else 1
		if vertical_atom_idx == 0 or vertical_atom_idx == (atoms_in_height - 1):
			result.append(current_height)
		if atoms_in_current_apothema == 1:
			# There was room for only one atom, the one in the center
			# That atom position has just been added to the result
			continue
		var distance_between_atoms_in_apothema: float = \
			NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, current_apothema_length) \
			if in_fill_whole_shape else in_minimum_distance_between_atoms
		for side_idx: int in sides:
			for apothema_atom_idx: int in range(1, atoms_in_current_apothema):
				var distance_to_longitudinal_axis: float = \
					distance_between_atoms_in_apothema * apothema_atom_idx
				var apothema_ratio: float = distance_to_longitudinal_axis/current_apothema_length
				var apothema_segment: Vector3 = \
					_get_segment(distance_to_longitudinal_axis, angular_increment * (side_idx + 0.5))
				var current_radial_segment_length: float = current_max_radius * apothema_ratio
				# Calculate the distance from the apothema to the radial segment using Pithagora's theorem
				var current_base_length: float = \
					sqrt(current_radial_segment_length**2 - distance_to_longitudinal_axis**2) * 2.0
				var atoms_in_base: int = \
					floori(current_base_length / in_minimum_distance_between_atoms) + 1
				var distance_between_atoms_in_base: float = \
					NanoMeshUtils.get_inter_atom_distance_in_length(
						in_minimum_distance_between_atoms, current_base_length
					) if in_fill_whole_shape else in_minimum_distance_between_atoms
				var current_radial_segment: Vector3 = \
					_get_segment(current_radial_segment_length, angular_increment * side_idx)
				var current_base_direction: Vector3 = \
					(apothema_segment - current_radial_segment).normalized()
				for base_atom_idx: int in atoms_in_base:
					if vertical_atom_idx == 0 \
						or apothema_atom_idx == (atoms_in_current_apothema - 1):
						result.append(
							current_height + current_radial_segment
							+ current_base_direction * base_atom_idx * distance_between_atoms_in_base
						)
	return result


func _get_radius(in_current_height:float) -> float:
	var base_max_radius: float = base_size * 0.5
	# x = r - (r/h * y) For more information, see cone_mesh.gd
	return base_max_radius - (base_max_radius/height) * in_current_height


func _get_apothema_length(in_radius: float) -> float:
	return in_radius * cos(PI/float(sides))


func _get_segment(in_length: float, in_rotation: float) -> Vector3:
	return -(Vector3.FORWARD * in_length) * Quaternion(Vector3.UP, in_rotation)
	


func get_fill_atoms_positions(in_minimum_distance_between_atoms: float, in_fill_whole_shape: bool) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var angular_increment: float = 2.0 * PI / float(sides)
	var atoms_in_height: int = floori(height / in_minimum_distance_between_atoms) + 1
	var vertical_distance_between_atoms: float = \
		NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, height) \
		if in_fill_whole_shape else in_minimum_distance_between_atoms
	var initial_position: Vector3 = \
		Vector3.ZERO if in_fill_whole_shape else \
		Vector3.UP * (height - (atoms_in_height - 1) * vertical_distance_between_atoms) * 0.5
	# Calculate the minimum radius to fit one atom per radial segment without overlapping
	# (Radial segments go, for a given height, from the vertical axis of the pyramid to
	# one of the edges)
	var minimum_radius: float = \
		NanoMeshUtils.minimum_radius_for_atom_count_in_circle_perimeter(
			in_minimum_distance_between_atoms, sides
		)
	for vertical_atom_idx: int in atoms_in_height:
		var current_height: Vector3 = \
			initial_position + Vector3.UP * vertical_atom_idx * vertical_distance_between_atoms
		var current_max_radius: float = _get_radius(current_height.length())
		var current_apothema_length: float = _get_apothema_length(current_max_radius)
		var atoms_in_current_apothema: int = 0
		atoms_in_current_apothema = \
			floori(current_apothema_length / in_minimum_distance_between_atoms) + 1 \
			if current_apothema_length >= minimum_radius else 1
		result.append(current_height)
		if atoms_in_current_apothema == 1:
			# There was room for only one atom, the one in the center
			# That atom position has just been added to the result
			continue
		var distance_between_atoms_in_apothema: float = \
			NanoMeshUtils.get_inter_atom_distance_in_length(in_minimum_distance_between_atoms, current_apothema_length) \
			if in_fill_whole_shape else in_minimum_distance_between_atoms
		for side_idx: int in sides:
			for apothema_atom_idx: int in range(1, atoms_in_current_apothema):
				var distance_to_longitudinal_axis: float = \
					distance_between_atoms_in_apothema * apothema_atom_idx
				var apothema_ratio: float = distance_to_longitudinal_axis/current_apothema_length
				var apothema_segment: Vector3 = \
					_get_segment(distance_to_longitudinal_axis, angular_increment * (side_idx + 0.5))
				var current_radial_segment_length: float = current_max_radius * apothema_ratio
				# Calculate the distance from the apothema to the radial segment using Pithagora's theorem
				var current_base_length: float = \
					sqrt(current_radial_segment_length**2 - distance_to_longitudinal_axis**2) * 2.0
				var atoms_in_base: int = \
					floori(current_base_length / in_minimum_distance_between_atoms) + 1
				var distance_between_atoms_in_base: float = \
					NanoMeshUtils.get_inter_atom_distance_in_length(
						in_minimum_distance_between_atoms, current_base_length
					) if in_fill_whole_shape else in_minimum_distance_between_atoms
				var current_radial_segment: Vector3 = \
					_get_segment(current_radial_segment_length, angular_increment * side_idx)
				var current_base_direction: Vector3 = \
					(apothema_segment - current_radial_segment).normalized()
				for base_atom_idx: int in atoms_in_base:
					result.append(
						current_height + current_radial_segment
						+ current_base_direction * base_atom_idx * distance_between_atoms_in_base
					)
	return result
