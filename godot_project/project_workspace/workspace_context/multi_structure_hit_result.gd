class_name MultiStructureHitResult extends RefCounted

enum HitType {
	HIT_NOTHING,
	HIT_ATOM,
	HIT_BOND,
	HIT_SHAPE,
	HIT_MOTOR,
	HIT_ANCHOR,
	HIT_SPRING,
}

var closest_hit_structure_context: StructureContext
var closest_hit_atom_id: int
var closest_hit_bond_id: int
var closest_hit_spring_id: int
var hit_type: HitType


func _init(in_camera: Camera3D, in_screen_position: Vector2, in_query_structures: Array[StructureContext]) -> void:
	closest_hit_structure_context = null
	closest_hit_atom_id = AtomicStructure.INVALID_ATOM_ID
	closest_hit_bond_id = AtomicStructure.INVALID_BOND_ID
	closest_hit_spring_id = AtomicStructure.INVALID_SPRING_ID
	hit_type = HitType.HIT_NOTHING
	var camera_pos: Vector3 = in_camera.global_transform.origin
	var atom_sqr_dst_candidate: float = INF
	var bond_sqr_dst_candidate: float = INF
	var shape_sqr_dst_candidate: float = INF
	var spring_sqr_dst_candidate: float = INF
	var virtual_object_sqr_dst_candidate: float = INF
	var closest_atom_context: StructureContext = null
	var closest_bond_context: StructureContext = null
	var closest_spring_context: StructureContext = null
	var closest_shape_context: StructureContext = null
	var closest_virtual_object_context: StructureContext = null
	
	# collect candidates
	for context: StructureContext in in_query_structures:
		var nano_struct: NanoStructure = context.nano_structure
		var collision_result: CollisionEngine.RaycastResult = context.get_collision_engine().ray(in_screen_position, in_camera)
		
		# atom
		var current_atom_sqr_dst: float = _calculate_atom_sqr_distance_to_camera(nano_struct,
				collision_result.atom_id, camera_pos)
		if current_atom_sqr_dst < atom_sqr_dst_candidate:
			atom_sqr_dst_candidate = current_atom_sqr_dst
			closest_atom_context = context
			closest_hit_atom_id = collision_result.atom_id
		
		# bond
		var current_bond_sqr_dst: float = _calculate_bond_sqr_distance_to_camera(nano_struct,
				collision_result.bond_id, camera_pos)
		if current_bond_sqr_dst < bond_sqr_dst_candidate:
			bond_sqr_dst_candidate = current_bond_sqr_dst
			closest_bond_context = context
			closest_hit_bond_id = collision_result.bond_id
		
		# spring
		var current_spring_sqr_dst: float = _calculate_spring_sqr_distance_to_camera(context,
				collision_result.spring_id, camera_pos)
		if current_spring_sqr_dst < spring_sqr_dst_candidate:
			spring_sqr_dst_candidate = current_spring_sqr_dst
			closest_spring_context = context
			closest_hit_spring_id = collision_result.spring_id
		
		# shape
		var current_shape_sqr_dst: float = _calculate_shape_sqr_distance_to_camera(in_camera, in_screen_position, context)
		if current_shape_sqr_dst < shape_sqr_dst_candidate:
			shape_sqr_dst_candidate = current_shape_sqr_dst
			closest_shape_context = context
		
		# other virtual objects
		var current_virtual_object_sqr_dst: float = _calculate_virtual_object_sqr_distance_to_camera(in_camera, in_screen_position, context)
		if current_virtual_object_sqr_dst < virtual_object_sqr_dst_candidate:
			virtual_object_sqr_dst_candidate = current_virtual_object_sqr_dst
			closest_virtual_object_context = context
	
	# compare each candidate and promote a winner
	var is_atom_the_closest: bool = atom_sqr_dst_candidate < min(spring_sqr_dst_candidate, bond_sqr_dst_candidate, shape_sqr_dst_candidate, virtual_object_sqr_dst_candidate)
	var is_bond_the_closest: bool = bond_sqr_dst_candidate < min(spring_sqr_dst_candidate, atom_sqr_dst_candidate, shape_sqr_dst_candidate, virtual_object_sqr_dst_candidate)
	var is_spring_the_closest: bool = spring_sqr_dst_candidate < min(atom_sqr_dst_candidate, bond_sqr_dst_candidate, shape_sqr_dst_candidate, virtual_object_sqr_dst_candidate)
	var is_shape_the_closest: bool = shape_sqr_dst_candidate < min(atom_sqr_dst_candidate, bond_sqr_dst_candidate, virtual_object_sqr_dst_candidate)
	var is_virtual_object_the_closest: bool = virtual_object_sqr_dst_candidate < min(atom_sqr_dst_candidate, bond_sqr_dst_candidate, shape_sqr_dst_candidate)
	var are_undetermined := atom_sqr_dst_candidate == INF and bond_sqr_dst_candidate == INF and \
			shape_sqr_dst_candidate == INF and virtual_object_sqr_dst_candidate == INF and \
			spring_sqr_dst_candidate == INF
	if are_undetermined:
		hit_type = HitType.HIT_NOTHING
		return
	if is_atom_the_closest:
		hit_type = HitType.HIT_ATOM
		closest_hit_structure_context = closest_atom_context
	if is_bond_the_closest:
		hit_type = HitType.HIT_BOND
		closest_hit_structure_context = closest_bond_context
	if is_spring_the_closest: 
		hit_type = HitType.HIT_SPRING
		closest_hit_structure_context = closest_spring_context
	if is_shape_the_closest:
		hit_type = HitType.HIT_SHAPE
		closest_hit_structure_context = closest_shape_context
	if is_virtual_object_the_closest:
		if closest_virtual_object_context.nano_structure is NanoVirtualMotor:
			hit_type = HitType.HIT_MOTOR
		elif closest_virtual_object_context.nano_structure is NanoVirtualAnchor:
			hit_type = HitType.HIT_ANCHOR
		closest_hit_structure_context = closest_virtual_object_context


func _calculate_atom_sqr_distance_to_camera(in_nano_structure: NanoStructure, in_atom_id: int,
			in_camera_pos: Vector3) -> float:
	if in_atom_id == AtomicStructure.INVALID_ATOM_ID:
		return INF
	return in_nano_structure.atom_get_position(in_atom_id).distance_squared_to(in_camera_pos)


func _calculate_bond_sqr_distance_to_camera(in_nano_structure: NanoStructure, in_bond_id: int,
			in_camera_pos: Vector3) -> float:
	if in_bond_id == AtomicStructure.INVALID_BOND_ID:
		return INF
	var bond: Vector3i = in_nano_structure.get_bond(in_bond_id)
	var first_atom_pos: Vector3 = in_nano_structure.atom_get_position(bond.x)
	var second_atom_pos: Vector3 = in_nano_structure.atom_get_position(bond.y)
	var bond_pos: Vector3 = (first_atom_pos + second_atom_pos) / 2.0
	return in_camera_pos.distance_squared_to(bond_pos)


func _calculate_spring_sqr_distance_to_camera(in_struct_context: StructureContext, in_spring_id: int,
			in_camera_pos: Vector3) -> float:
	if in_spring_id == AtomicStructure.INVALID_SPRING_ID:
		return INF
	var nano_structure: NanoStructure = in_struct_context.nano_structure
	var atom_pos: Vector3 = nano_structure.spring_get_atom_position(in_spring_id)
	var anchor_pos: Vector3 = nano_structure.spring_get_anchor_position(in_spring_id, in_struct_context)
	var spring_center_pos: Vector3 = (atom_pos + anchor_pos) / 2.0
	return in_camera_pos.distance_squared_to(spring_center_pos)


func _calculate_shape_sqr_distance_to_camera(in_camera: Camera3D, in_screen_pos: Vector2,
			in_context: StructureContext) -> float:
	var shape_intersections: PackedVector3Array = _get_ray_hits_shape(in_camera, in_screen_pos, in_context)
	var is_shape_collision_detected: bool = not shape_intersections.is_empty()
	if not is_shape_collision_detected:
		return INF
	return in_camera.global_position.distance_squared_to(shape_intersections[0])


func _calculate_virtual_object_sqr_distance_to_camera(in_camera: Camera3D, in_screen_pos: Vector2,
			in_context: StructureContext) -> float:
	var structure: NanoStructure = in_context.nano_structure
	if not is_instance_valid(structure) or not structure.is_virtual_object():
		# structure was not a motor
		return INF
	var is_object_collision_detected: bool = in_context.get_collision_engine().ray_virtual_object(in_screen_pos, in_camera)
	if not is_object_collision_detected:
		return INF
	var position := Vector3()
	var collider_offset := Vector3()
	if structure.has_transform():
		position = structure.get_transform().origin
	else:
		position = structure.get_position()
	if structure is NanoVirtualMotor:
		const MOTOR_OFFSET: Vector3 = Vector3(-0.127, 0.025, 0)
		collider_offset = structure.get_transform().basis * MOTOR_OFFSET
	return in_camera.global_position.distance_squared_to(position + collider_offset)


# Returns a PackedVector3Array with all hits that the ray projected from screen point
#+sorted from the closer to the camera to the further to the camera
func _get_ray_hits_shape(in_camera: Camera3D, in_screen_position: Vector2, in_context: StructureContext) -> PackedVector3Array:
	var nano_shape: NanoShape = in_context.nano_structure as NanoShape
	if nano_shape == null:
		return PackedVector3Array()
	var create_mode_enabled: bool = in_context.workspace_context.create_object_parameters.get_create_mode_enabled()
	var hits: PackedVector3Array = nano_shape.intersect_shape_with_screen_point(in_screen_position, in_camera, create_mode_enabled)
	
	# Sort custom can only be performed in Array class
	var hits_as_array: Array = Array(hits)
	hits_as_array.sort_custom(
			func (a: Vector3, b: Vector3) -> bool:
				return in_camera.global_position.distance_squared_to(a) < in_camera.global_position.distance_squared_to(b)
	)
	hits = PackedVector3Array(hits_as_array)
	return hits


func did_hit() -> bool:
	return closest_hit_structure_context != null



