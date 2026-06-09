class_name AlignableOBB
extends OBB


enum BoxFace {
	UNDEFINED = -1,
	FRONT  = 0,
	BACK   = 1,
	TOP    = 2,
	BOTTOM = 3,
	LEFT   = 4,
	RIGHT  = 5,
}


var selected_face := BoxFace.UNDEFINED
var align_to_face := BoxFace.FRONT
var offset_ratio_h: float = 0.0
var offset_ratio_v: float = 0.0
var description: String:
	set(v):
		assert(_initialized == false, "Value cannot be changed upon creation")
		description = v


static func from_obb(obb: OBB, in_description: String) -> AlignableOBB:
	return AlignableOBB.new(in_description, obb.box.size, obb.transform, obb.point_cloud_source)


func _init(in_description: String, in_size: Vector3, in_transform: Transform3D, in_source: Dictionary[StructureContext, PackedInt32Array]) -> void:
	description = in_description
	super._init(in_size, in_transform,in_source)
	if not has_face(align_to_face):
		advance_align_to_face(1)
	_initialized = true


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
			return [BoxFace.FRONT, BoxFace.BACK]
		2:
			# A straight line, likely 2 atoms, this would make 2 faces valid, but we only send one
			match non_zero_len_axes[0]: # The only axis with size
				Vector3.AXIS_X:
					return [BoxFace.FRONT, BoxFace.BACK]
				Vector3.AXIS_Y:
					return [BoxFace.FRONT, BoxFace.BACK]
				Vector3.AXIS_Z:
					return [BoxFace.TOP, BoxFace.BOTTOM]
		1:
			match non_zero_len_axes: # size is 2
				[Vector3.AXIS_X, Vector3.AXIS_Y]:
					return [BoxFace.FRONT, BoxFace.BACK]
				[Vector3.AXIS_X, Vector3.AXIS_Z]:
					return [BoxFace.TOP, BoxFace.BOTTOM]
				[Vector3.AXIS_Y, Vector3.AXIS_Z]:
					return [BoxFace.LEFT, BoxFace.RIGHT]
		_:
			pass # default
	return [BoxFace.FRONT, BoxFace.BACK, BoxFace.TOP, BoxFace.BOTTOM, BoxFace.LEFT, BoxFace.RIGHT]

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
		BoxFace.FRONT:
			return transform.basis
		BoxFace.BACK:
			var basis: Basis = transform.basis.orthonormalized()
			return Basis(
				-basis[0],
				basis[1],
				-basis[2],
			)
		BoxFace.TOP:
			var basis: Basis = transform.basis.orthonormalized()
			return Basis(
				basis[0],
				-basis[2],
				basis[1],
			)
		BoxFace.BOTTOM:
			var basis: Basis = transform.basis.orthonormalized()
			return Basis(
				basis[0],
				basis[2],
				-basis[1],
			)
		BoxFace.LEFT:
			var basis: Basis = transform.basis.orthonormalized()
			return Basis(
				-basis[2],
				basis[1],
				basis[0],
			)
		BoxFace.RIGHT:
			var basis: Basis = transform.basis.orthonormalized()
			return Basis(
				basis[2],
				basis[1],
				-basis[0],
			)
	push_error("Invalid face %d" % in_face)
	return transform.basis


## Returns the width and heigth of the face as X and Y components, and the depth of the box in the Z
func get_face_size(in_face: BoxFace) -> Vector3:
	match in_face:
		BoxFace.FRONT, BoxFace.BACK:
			return Vector3(box.size.x, box.size.y, box.size.z)
		BoxFace.TOP, BoxFace.BOTTOM:
			return Vector3(box.size.x, box.size.z, box.size.y)
		BoxFace.LEFT, BoxFace.RIGHT:
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
	var to_local: Transform3D = old_transform.inverse()
	var new_transform: Transform3D
	new_transform = Transform3D(in_basis, old_transform.origin)
	for context: StructureContext in point_cloud_source.keys():
		var nano_structure: NanoStructure = context.nano_structure
		var atoms_to_move: PackedInt32Array = point_cloud_source[context]
		var previous_positions: PackedVector3Array = []
		var target_positions: PackedVector3Array = []
		var nmb_of_moved_atoms: int = 0
		for atom_id: int in point_cloud_source[context]:
			var old_pos: Vector3 = nano_structure.atom_get_position(atom_id)
			var new_pos: Vector3 = new_transform * (to_local * old_pos)
			target_positions.push_back(new_pos)
			previous_positions.push_back(old_pos)
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
				nano_structure.set_transform(new_transform)
				something_changed = true
	return something_changed


func align_position_to(reference_obb: AlignableOBB) -> bool:
	if reference_obb == self or selected_face == BoxFace.UNDEFINED or point_cloud_source.size() == 0:
		return false
	var something_changed: bool = false
	
	const HALF_BOX_SIZE: float = 0.5
	var ref_face_basis: Basis = reference_obb.get_face_basis(reference_obb.align_to_face)
	var ref_face_size: Vector3 = reference_obb.get_face_size(reference_obb.align_to_face)
	var reference_point := Vector3() # in local space, relative to plane
	reference_point += ref_face_basis.x * ref_face_size.x * reference_obb.offset_ratio_h
	reference_point += ref_face_basis.y * ref_face_size.y * reference_obb.offset_ratio_v
	reference_point += ref_face_basis.z * ref_face_size.z * HALF_BOX_SIZE
	
	var align_origin: Vector3 = reference_obb.transform.origin
	align_origin += reference_point
	var align_transform := Transform3D(ref_face_basis, align_origin)
	
	
	var obj_face_basis: Basis = self.get_face_basis(self.selected_face)
	var obj_face_size: Vector3 = self.get_face_size(self.selected_face)
	var obj_reference_pos := Vector3()
	obj_reference_pos += obj_face_basis.x * obj_face_size.x * self.offset_ratio_h
	obj_reference_pos += obj_face_basis.y * obj_face_size.y * self.offset_ratio_v
	obj_reference_pos += obj_face_basis.z * obj_face_size.z * HALF_BOX_SIZE
	var old_transform: Transform3D = transform
	
	var global_obj_reference_pos: Vector3 = transform.origin
	global_obj_reference_pos += obj_reference_pos
	
	var local_to_align_origin: Vector3 = align_transform.inverse() * global_obj_reference_pos
	
	var world_offset := -Vector3(local_to_align_origin.x, local_to_align_origin.y, 0)
	world_offset = ref_face_basis.inverse() * world_offset
	
	var new_transform: Transform3D = old_transform.translated(world_offset)
	var to_local: Transform3D = old_transform.inverse()
	var delta_transform: Transform3D = (to_local * new_transform).orthonormalized()
	
	for context: StructureContext in point_cloud_source.keys():
		var nano_structure: NanoStructure = context.nano_structure
		var atoms_to_move: PackedInt32Array = []
		var previous_positions: PackedVector3Array = []
		var target_positions: PackedVector3Array = []
		var nmb_of_moved_atoms: int = 0
		for atom_id: int in point_cloud_source[context]:
			var old_pos: Vector3 = nano_structure.atom_get_position(atom_id)
			var new_pos: Vector3 = new_transform * (to_local * old_pos)
			atoms_to_move.push_back(atom_id)
			target_positions.push_back(new_pos)
			previous_positions.push_back(old_pos)
			nmb_of_moved_atoms += 1
		
		var atoms_changed: bool = nmb_of_moved_atoms > 0
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
				nano_structure.set_transform(nano_structure.get_transform()* delta_transform)
			if position_moved:
				var t := Transform3D(Basis(), nano_structure.get_position()) * delta_transform
				nano_structure.set_position(t.origin)
			
			something_changed = true
	
	return something_changed
