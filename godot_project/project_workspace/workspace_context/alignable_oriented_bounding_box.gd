class_name AlignableOBB
extends OBB


## Each indices matches the plane's normal index (X -> 0, Y -> 1, Z -> 2)
enum BoxFace {
	UNDEFINED = -1,
	YZ = 0,
	XZ = 1,
	XY = 2,
}


var selected_face := BoxFace.UNDEFINED
var align_to_face := BoxFace.YZ
var align_to_center_of_mass: bool = true
var offset_ratio_h: float = 0.0
var offset_ratio_v: float = 0.0
var offset_ratio_d: float = 0.0
var world_center_of_mass: Vector3:
	set(v):
		assert(_initialized == false, "Value cannot be changed upon creation")
		world_center_of_mass = v
var description: String:
	set(v):
		assert(_initialized == false, "Value cannot be changed upon creation")
		description = v

var _local_center_of_mass: Vector3
var _params: AlignSelectionParameters


static func from_obb(obb: OBB, in_description: String, align_parameters: AlignSelectionParameters) -> AlignableOBB:
	return AlignableOBB.new(in_description, obb.box.size, obb.transform, obb.point_cloud_source, align_parameters)


func _init(
		in_description: String,
		in_size: Vector3,
		in_transform: Transform3D,
		in_source: Dictionary[StructureContext, PackedInt32Array],
		in_align_parameters: AlignSelectionParameters
	) -> void:
	description = in_description
	super._init(in_size, in_transform,in_source)
	_initialized = false
	world_center_of_mass = _calculate_center_of_mass_from_source()
	_local_center_of_mass = transform.affine_inverse() * world_center_of_mass
	_params = in_align_parameters
	if not has_face(align_to_face):
		advance_align_to_face(1)
	align_to_face = _get_squarest_face()
	selected_face = align_to_face
	_initialized = true


func _calculate_center_of_mass_from_source() -> Vector3:
	var center := Vector3()
	var total_mass: float = 0
	var atom_type_masses: Dictionary[int, float]
	for source: StructureContext in point_cloud_source:
		if source.nano_structure is AtomicStructure and not source.nano_structure is AtomicVirtualStructure:
			var atomic_structure := source.nano_structure as AtomicStructure
			for atom_id: int in point_cloud_source[source]:
				var atomic_number: int = atomic_structure.atom_get_atomic_number(atom_id)
				if not atomic_number in atom_type_masses:
					atom_type_masses[atomic_number] = PeriodicTable.get_by_atomic_number(atomic_number).mass
				center += atomic_structure.atom_get_position(atom_id) * atom_type_masses[atomic_number]
				total_mass += atom_type_masses[atomic_number]
	if is_zero_approx(total_mass):
		return transform.origin
	center /= total_mass
	return center


func advance_selected_face(dir: int) -> void:
	var selectable_faces :Array[BoxFace] = get_selectable_faces()
	assert(selectable_faces.size() > 0)
	var idx: int = selectable_faces.find(selected_face)
	if idx == -1:
		idx = 0
	else:
		idx = (idx + selectable_faces.size() + dir) % selectable_faces.size()
	selected_face = selectable_faces[idx] as BoxFace
	assert(has_face(selected_face))


func advance_align_to_face(dir: int) -> void:
	var alignable_faces :Array[BoxFace] = get_alignable_faces()
	assert(alignable_faces.size() > 0)
	var idx: int = alignable_faces.find(align_to_face)
	if idx == -1:
		idx = 0
	else:
		idx = (idx + alignable_faces.size() + dir) % alignable_faces.size()
	align_to_face = alignable_faces[idx]


func get_selectable_faces() -> Array[BoxFace]:
	var faces: Array[BoxFace] = [BoxFace.UNDEFINED]
	faces.append_array(get_alignable_faces())
	return faces


func get_alignable_faces() -> Array[BoxFace]:
	var zero_len_axes_count: int = 0
	var non_zero_len_axes: Array[int] = []
	for i: int in 3:
		if is_zero_approx(box.size[i]):
			zero_len_axes_count += 1
		else:
			non_zero_len_axes.append(i)
	match zero_len_axes_count:
		3:
			# Empty box, align to an arbitrary face (front)
			return [BoxFace.YZ]
		2:
			# A straight line, likely 2 atoms, this would make 2 faces valid, but we only send one
			match non_zero_len_axes[0]: # The only axis with size
				Vector3.AXIS_X:
					return [BoxFace.XY]
				Vector3.AXIS_Y:
					return [BoxFace.XY]
				Vector3.AXIS_Z:
					return [BoxFace.XZ]
		1:
			match non_zero_len_axes: # box is a plane, only 1 face is needed
				[Vector3.AXIS_X, Vector3.AXIS_Y]:
					return [BoxFace.XY]
				[Vector3.AXIS_X, Vector3.AXIS_Z]:
					return [BoxFace.XZ]
				[Vector3.AXIS_Y, Vector3.AXIS_Z]:
					return [BoxFace.YZ]
		_:
			pass # default

	return [BoxFace.XY, BoxFace.XZ, BoxFace.YZ]


func get_face_corners(face: BoxFace, depth_enabled: bool = false) -> PackedVector3Array:
	var corners: Array[Vector3]
	var offset: Vector3 = Vector3.ZERO
	match face:
		BoxFace.XZ:
			corners = [Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]
			offset = Vector3.UP
		BoxFace.XY:
			corners = [Vector3(-1, 1, 0), Vector3(1, 1, 0), Vector3(1, -1, 0), Vector3(-1, -1, 0)]
			offset = Vector3.BACK
		BoxFace.YZ:
			corners = [Vector3(0, 1, 1), Vector3(0, 1, -1), Vector3(0, -1, -1), Vector3(0, -1, 1)]
			offset = Vector3.RIGHT
	if align_to_center_of_mass:
		offset *= _local_center_of_mass
	elif depth_enabled:
		offset *= box.size * offset_ratio_d
	else:
		offset = Vector3.ZERO
	var result := PackedVector3Array()
	var half_size: Vector3 = box.size * .5
	for local_point in corners:
		result.push_back(transform * (local_point * half_size + offset))
	return result


## At least 2 of the 3 size dimensions needs to be greater than 0 for the
## box to have a valid surface.
func has_alignable_face() -> bool:
	var zero_length_count: int = 0
	for i in 3:
		if is_zero_approx(box.size[i]):
			zero_length_count += 1
	return zero_length_count <= 1


func has_face(box_face: BoxFace) -> bool:
	return box_face in get_selectable_faces()


func get_face_basis(in_face: BoxFace) -> Basis:
	match in_face:
		BoxFace.XY:
			return transform.basis.orthonormalized()
		BoxFace.XZ:
			var basis: Basis = transform.basis.orthonormalized()
			return Basis(
				basis[0],
				-basis[2],
				basis[1],
			)
		BoxFace.YZ:
			var basis: Basis = transform.basis.orthonormalized()
			return Basis(
				basis[2],
				basis[1],
				basis[0],
			)
	push_error("Invalid face %d" % in_face)
	return transform.basis


## Returns the width and heigth of the face as X and Y components, and the depth of the box in the Z
func get_face_size(in_face: BoxFace) -> Vector3:
	match in_face:
		BoxFace.XY:
			return Vector3(box.size.x, box.size.y, box.size.z)
		BoxFace.XZ:
			return Vector3(box.size.x, box.size.z, box.size.y)
		BoxFace.YZ:
			return Vector3(box.size.z, box.size.y, box.size.x)
	return Vector3()


func align_rotation_to_box(in_box: AlignableOBB) -> bool:
	if selected_face == BoxFace.UNDEFINED:
		return false
	if in_box == self:
		return false
	return align_rotation_to_basis(in_box.get_face_basis(in_box.align_to_face))


func align_rotation_to_basis(in_basis: Basis) -> bool:
	if selected_face == BoxFace.UNDEFINED:
		return false
	var something_changed: bool = false
	var old_transform: Transform3D = Transform3D(get_face_basis(selected_face), transform.origin)
	
	if old_transform.basis == in_basis:
		return false
	var relative_basis: Basis = in_basis * get_face_basis(selected_face).inverse()
	for context: StructureContext in point_cloud_source.keys():
		if context.nano_structure is CarbonNanotubeStructure or context.nano_structure is DnaStructure:
			context.nano_structure.start_edit()
			for p: int in context.nano_structure.get_control_point_count():
				var old_pos: Vector3 = context.nano_structure.get_control_point_position(p)
				var rel_pos: Vector3 = old_pos - transform.origin
				var new_pos: Vector3 = (relative_basis * rel_pos) + transform.origin
				context.nano_structure.set_control_point_position(p, new_pos)
			context.nano_structure.end_edit()
			something_changed = true
			continue
		var nano_structure: NanoStructure = context.nano_structure
		var atoms_to_move: PackedInt32Array = point_cloud_source[context]
		var target_positions: PackedVector3Array = []
		var nmb_of_moved_atoms: int = 0
		for atom_id: int in point_cloud_source[context]:
			var old_pos: Vector3 = nano_structure.atom_get_position(atom_id)
			var rel_pos: Vector3 = old_pos - transform.origin
			var new_pos: Vector3 = (relative_basis * rel_pos) + transform.origin
			target_positions.push_back(new_pos)
			nmb_of_moved_atoms += 1
		
		var atoms_changed: bool = nmb_of_moved_atoms > 0
		var object_moved: bool = context.is_shape_selected() or context.is_motor_selected() or context.is_particle_emitter_selected()
		if atoms_changed or object_moved:
			if atoms_changed:
				nano_structure.start_edit()
				nano_structure.atoms_set_positions(atoms_to_move, target_positions)
				nano_structure.end_edit()
				something_changed = true
			if object_moved:
				var t: Transform3D = nano_structure.get_transform()
				t.basis = relative_basis * t.basis
				nano_structure.set_transform(t)
				something_changed = true
	return something_changed


func align_position_to(reference_obb: AlignableOBB, in_align_depth: bool) -> bool:
	if reference_obb == self or selected_face == BoxFace.UNDEFINED or point_cloud_source.size() == 0:
		return false
	var something_changed: bool = false
	
	var align_origin: Vector3 = reference_obb._get_align_reference_point(reference_obb.align_to_face, in_align_depth)
	
	var global_obj_reference_pos: Vector3 = _get_align_reference_point(selected_face, in_align_depth)
	
	var offset := Vector3()
	if in_align_depth:
		offset = align_origin - global_obj_reference_pos
	else:
		var ref_face_basis: Basis = reference_obb.get_face_basis(reference_obb.align_to_face)
		var align_plane := Plane(ref_face_basis.z, align_origin)
		var ref_point_in_plane: Vector3 = align_plane.project(global_obj_reference_pos)
		offset = align_origin - ref_point_in_plane
	
	for context: StructureContext in point_cloud_source.keys():
		if context.nano_structure is CarbonNanotubeStructure or context.nano_structure is DnaStructure:
			context.nano_structure.start_edit()
			for p: int in context.nano_structure.get_control_point_count():
				var old_pos: Vector3 = context.nano_structure.get_control_point_position(p)
				var new_pos: Vector3 = old_pos + offset
				context.nano_structure.set_control_point_position(p, new_pos)
			context.nano_structure.end_edit()
			something_changed = true
			continue
		var nano_structure: NanoStructure = context.nano_structure
		var atoms_to_move: PackedInt32Array = []
		var target_positions: PackedVector3Array = []
		for atom_id: int in point_cloud_source[context]:
			var old_pos: Vector3 = nano_structure.atom_get_position(atom_id)
			var new_pos: Vector3 = old_pos + offset
			atoms_to_move.push_back(atom_id)
			target_positions.push_back(new_pos)
		
		var atoms_changed: bool = atoms_to_move.size() > 0
		var transform_moved: bool = false
		var position_moved: bool = false
		if context.nano_structure.is_virtual_object() and context.is_virtual_object_selected():
			if context.nano_structure.has_transform():
				transform_moved = true
			else:
				position_moved = true
		if atoms_changed or transform_moved or position_moved:
			if atoms_changed:
				nano_structure.start_edit()
				nano_structure.atoms_set_positions(atoms_to_move, target_positions)
				nano_structure.end_edit()
			if transform_moved:
				var t: Transform3D = nano_structure.get_transform()
				t.origin += offset
				nano_structure.set_transform(t)
			if position_moved:
				var pos: Vector3 = nano_structure.get_position()
				nano_structure.set_position(pos + offset)
			
			something_changed = true
	
	return something_changed


## Returns the alignment reference point in world coordinates
func _get_align_reference_point(reference_face: BoxFace, in_align_depth: bool) -> Vector3:
	if align_to_center_of_mass:
		return world_center_of_mass
	
	const DEFAULT_DEPTH_RATIO: float = 0.5
	var basis: Basis = get_face_basis(reference_face)
	var size: Vector3 = get_face_size(reference_face)
	var reference_point := Vector3() # in local space, relative to plane
	reference_point += basis.x * size.x * offset_ratio_h
	reference_point += basis.y * size.y * offset_ratio_v
	if in_align_depth:
		reference_point += basis.z * size.z * offset_ratio_d
	else:
		reference_point += basis.z * size.z * DEFAULT_DEPTH_RATIO
	
	return transform.origin + reference_point


## Returns the most square face (aspect ratio closest to 1.0) as it's the most
## likely face to align a rotary motor with.
## Returns BoxFace.UNDEFINED with the OBB has no valid surfaces.
func _get_squarest_face() -> BoxFace:
	var face: BoxFace = BoxFace.UNDEFINED
	var squarest_ratio: float = INF
	for idx in range(3):
		var face_size: Vector3 = get_face_size(idx)
		var smallest: float = min(face_size.x, face_size.y)
		var largest: float = max(face_size.x, face_size.y)
		if is_zero_approx(smallest):
			continue # Skip division by zero
		var ratio: float = largest / smallest
		if face == BoxFace.UNDEFINED or ratio < squarest_ratio:
			face = idx as BoxFace
			squarest_ratio = ratio
	return face
