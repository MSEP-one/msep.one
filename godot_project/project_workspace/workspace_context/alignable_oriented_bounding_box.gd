class_name AlignableOBB
extends OBB


enum BoxFace {
	UNDEFINED = -1,
	FRONT_BACK = 0,
	TOP_BOTTOM = 1,
	LEFT_RIGHT = 2,
}


var selected_face := BoxFace.UNDEFINED
var align_to_face := BoxFace.FRONT_BACK
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
	var new_face: int = int(selected_face) + dir
	if new_face < BoxFace.UNDEFINED:
		new_face = BoxFace.LEFT_RIGHT
	if new_face > BoxFace.LEFT_RIGHT:
		new_face = BoxFace.UNDEFINED
	selected_face = new_face as BoxFace
	if not has_face(selected_face):
		# Face has no area, skip and continue to the next one
		advance_selected_face(dir)


func advance_align_to_face(dir: int) -> void:
	var new_face: int = int(align_to_face) + dir
	if new_face < BoxFace.FRONT_BACK:
		new_face = BoxFace.LEFT_RIGHT
	if new_face > BoxFace.LEFT_RIGHT:
		new_face = BoxFace.FRONT_BACK
	align_to_face = new_face as BoxFace
	if has_alignable_face() and not has_face(align_to_face):
		# Face has no area, skip and continue to the next one
		advance_align_to_face(dir)


func has_alignable_face() -> bool:
	return box.has_surface()


func has_face(box_face: BoxFace) -> bool:
	var area: float = 0
	match box_face:
		BoxFace.UNDEFINED:
			return true
		BoxFace.FRONT_BACK:
			area = box.size.x * box.size.y
		BoxFace.TOP_BOTTOM:
			area = box.size.x * box.size.z
		BoxFace.LEFT_RIGHT:
			area = box.size.y * box.size.z
	const MIN_AREA: float = 0.001
	return area > MIN_AREA


func get_face_basis(in_face: BoxFace) -> Basis:
	match in_face:
		BoxFace.FRONT_BACK:
			return transform.basis.orthonormalized()
		BoxFace.TOP_BOTTOM:
			return Basis(
				transform.basis[0],
				-transform.basis[2],
				transform.basis[1]
			).orthonormalized()
		BoxFace.LEFT_RIGHT:
			return Basis(
				-transform.basis[2],
				transform.basis[1],
				transform.basis[0]
			).orthonormalized()
	push_error("Invalid face %d" % in_face)
	return transform.basis


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
	var old_transform: Transform3D = transform
	
	var fwd := -in_basis.z                         # forward
	var right := fwd.cross(in_basis.y).normalized()    # right
	var up := right.cross(fwd).normalized()                 # up (reorthogonalized)
	
	var new_basis: Basis
	match selected_face:
		BoxFace.LEFT_RIGHT:
			new_basis = Basis(fwd,  up, -right)
		BoxFace.TOP_BOTTOM:
			new_basis = Basis(right,  fwd, -up)
		_:
			new_basis = Basis(right,  up, -fwd)
	
	if old_transform.basis == new_basis:
		return false
	var to_local: Transform3D = old_transform.inverse()
	var new_transform: Transform3D
	new_transform = Transform3D(new_basis, old_transform.origin)
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
			


func align_position_to(_in_box: AlignableOBB) -> void:
	if selected_face == BoxFace.UNDEFINED:
		return
	# TODO
