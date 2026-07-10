class_name MultiStructureHitResult extends RefCounted

enum HitType {
	HIT_NOTHING,
	HIT_ATOM,
	HIT_BOND,
	HIT_SHAPE,
	HIT_MOTOR,
	HIT_EMITTER,
	HIT_ANCHOR,
	HIT_SPRING,
	HIT_DNA_PATH,
	HIT_DNA_CONTROL_POINT,
	HIT_NANOTUBE_PATH,
	HIT_NANOTUBE_CONTROL_POINT,
}

var closest_hit_structure_context: StructureContext
var closest_hit_atom_id: int
var closest_hit_bond_id: int
var closest_hit_spring_id: int
var closest_hit_path_control_point_id: int
var closest_hit_path_progress: float
var closest_hit_path_pos: Vector3

var hit_type: HitType

var _representation_settings: RepresentationSettings
var _is_simulating: bool

func _init(in_camera: Camera3D, in_screen_position: Vector2, in_query_structures: Array[StructureContext]) -> void:
	if in_query_structures.size():
		_representation_settings = in_query_structures[0].workspace_context.workspace.representation_settings
		_is_simulating = in_query_structures[0].workspace_context.is_simulating()
	closest_hit_structure_context = null
	closest_hit_atom_id = AtomicStructure.INVALID_ATOM_ID
	closest_hit_bond_id = AtomicStructure.INVALID_BOND_ID
	closest_hit_spring_id = AtomicStructure.INVALID_SPRING_ID
	hit_type = HitType.HIT_NOTHING
	var camera_pos: Vector3 = in_camera.global_transform.origin
	var atom_sqr_dst_candidate: float = INF
	var bond_sqr_dst_candidate: float = INF
	var shape_sqr_dst_candidate: float = INF
	var dna_sqrd_distance_candidate: float = INF
	var nanotube_sqrd_distance_candidate: float = INF
	var spring_sqr_dst_candidate: float = INF
	var virtual_object_sqr_dst_candidate: float = INF
	var closest_atom_context: StructureContext = null
	var closest_bond_context: StructureContext = null
	var closest_spring_context: StructureContext = null
	var closest_shape_context: StructureContext = null
	var closest_dna_context: StructureContext = null
	var closest_dna_cast_result: Dictionary
	var closest_nanotube_context: StructureContext = null
	var closest_nanotube_cast_result: Dictionary
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
		
		# dna
		var dna_path_cast_result: Dictionary = _calculate_dna_path_sqrd_distance_to_camera(in_camera, in_screen_position, context)
		var distance_sqrd_to_closest_point: float = dna_path_cast_result.distance_sqrd_to_closest_point
		var distance_sqrd_to_closest_control_point: float = dna_path_cast_result.distance_sqrd_to_closest_control_point
		var min_distance_sqrd_to_dna_path: float = min(distance_sqrd_to_closest_control_point, distance_sqrd_to_closest_point)
		if min_distance_sqrd_to_dna_path < dna_sqrd_distance_candidate:
			dna_sqrd_distance_candidate = min_distance_sqrd_to_dna_path
			closest_dna_context = context
			closest_dna_cast_result = dna_path_cast_result
		
		# nanotube
		var nanotube_path_cast_result: Dictionary = _calculate_nanotube_path_sqrd_distance_to_camera(in_camera, in_screen_position, context)
		distance_sqrd_to_closest_point = nanotube_path_cast_result.distance_sqrd_to_closest_point
		distance_sqrd_to_closest_control_point = nanotube_path_cast_result.distance_sqrd_to_closest_control_point
		var min_distance_sqrd_to_nanotube_path: float = min(distance_sqrd_to_closest_control_point, distance_sqrd_to_closest_point)
		if min_distance_sqrd_to_nanotube_path < nanotube_sqrd_distance_candidate:
			nanotube_sqrd_distance_candidate = min_distance_sqrd_to_nanotube_path
			closest_nanotube_context = context
			closest_nanotube_cast_result = nanotube_path_cast_result
		
		
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
	var is_atom_the_closest: bool = atom_sqr_dst_candidate < min(spring_sqr_dst_candidate, bond_sqr_dst_candidate, shape_sqr_dst_candidate, virtual_object_sqr_dst_candidate, dna_sqrd_distance_candidate, nanotube_sqrd_distance_candidate)
	var is_bond_the_closest: bool = bond_sqr_dst_candidate < min(spring_sqr_dst_candidate, atom_sqr_dst_candidate, shape_sqr_dst_candidate, virtual_object_sqr_dst_candidate, dna_sqrd_distance_candidate, nanotube_sqrd_distance_candidate)
	var is_spring_the_closest: bool = spring_sqr_dst_candidate < min(atom_sqr_dst_candidate, bond_sqr_dst_candidate, shape_sqr_dst_candidate, virtual_object_sqr_dst_candidate, dna_sqrd_distance_candidate, nanotube_sqrd_distance_candidate)
	var is_shape_the_closest: bool = shape_sqr_dst_candidate < min(atom_sqr_dst_candidate, bond_sqr_dst_candidate, virtual_object_sqr_dst_candidate, dna_sqrd_distance_candidate, nanotube_sqrd_distance_candidate)
	var is_virtual_object_the_closest: bool = virtual_object_sqr_dst_candidate < min(atom_sqr_dst_candidate, bond_sqr_dst_candidate, shape_sqr_dst_candidate, dna_sqrd_distance_candidate, nanotube_sqrd_distance_candidate)
	var is_dna_the_closest: bool = dna_sqrd_distance_candidate < min(atom_sqr_dst_candidate, bond_sqr_dst_candidate, spring_sqr_dst_candidate, shape_sqr_dst_candidate, virtual_object_sqr_dst_candidate, nanotube_sqrd_distance_candidate)
	var is_nanotube_the_closest: bool = nanotube_sqrd_distance_candidate < min(atom_sqr_dst_candidate, bond_sqr_dst_candidate, spring_sqr_dst_candidate, shape_sqr_dst_candidate, virtual_object_sqr_dst_candidate, dna_sqrd_distance_candidate)
	var are_undetermined := atom_sqr_dst_candidate == INF and bond_sqr_dst_candidate == INF and \
			shape_sqr_dst_candidate == INF and virtual_object_sqr_dst_candidate == INF and \
			spring_sqr_dst_candidate == INF and dna_sqrd_distance_candidate == INF and nanotube_sqrd_distance_candidate == INF
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
	if is_dna_the_closest:
		closest_hit_structure_context = closest_dna_context
		if closest_dna_cast_result.closest_control_point != -1:
			hit_type = HitType.HIT_DNA_CONTROL_POINT
			closest_hit_path_control_point_id = closest_dna_cast_result.closest_control_point
			closest_hit_path_pos = closest_dna_context.nano_structure.get_control_point_position(closest_hit_path_control_point_id)
		else:
			hit_type = HitType.HIT_DNA_PATH
			closest_hit_path_progress = closest_dna_cast_result.path_progress
			closest_hit_path_pos = closest_dna_cast_result.path_pos
	if is_nanotube_the_closest:
		closest_hit_structure_context = closest_nanotube_context
		if closest_nanotube_cast_result.closest_control_point != -1:
			hit_type = HitType.HIT_NANOTUBE_CONTROL_POINT
			closest_hit_path_control_point_id = closest_nanotube_cast_result.closest_control_point
			closest_hit_path_pos = closest_nanotube_context.nano_structure.get_control_point_position(closest_hit_path_control_point_id)
		else:
			hit_type = HitType.HIT_NANOTUBE_PATH
			closest_hit_path_progress = closest_nanotube_cast_result.path_progress
			closest_hit_path_pos = closest_nanotube_cast_result.path_pos
	if is_virtual_object_the_closest:
		if closest_virtual_object_context.nano_structure is NanoVirtualMotor:
			hit_type = HitType.HIT_MOTOR
		elif closest_virtual_object_context.nano_structure is NanoParticleEmitter:
			hit_type = HitType.HIT_EMITTER
		elif closest_virtual_object_context.nano_structure is NanoVirtualAnchor:
			hit_type = HitType.HIT_ANCHOR
		else:
			assert(false, "Untracked hit type!")
			pass
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
	if _is_simulating and _representation_settings.get_should_hide_virtual_object_during_simulation(NanoVirtualAnchor):
		return INF
	var nano_structure: NanoStructure = in_struct_context.nano_structure
	var atom_pos: Vector3 = nano_structure.spring_get_atom_position(in_spring_id)
	var target_pos: Vector3 = nano_structure.spring_get_target_position(in_spring_id, in_struct_context)
	var spring_center_pos: Vector3 = (atom_pos + target_pos) / 2.0
	return in_camera_pos.distance_squared_to(spring_center_pos)


func _calculate_dna_path_sqrd_distance_to_camera(in_camera: Camera3D, in_screen_pos: Vector2,
			in_context: StructureContext) -> Dictionary:
	const MAX_DISTANCE_IN_PIXELS_SQRD_TO_CONTROL_POINT: float = 10*10
	const MAX_DISTANCE_IN_PIXELS_SQRD_TO_PATH: float = 5*5
	var result: Dictionary = {
		path_progress = 0.0,
		path_pos = Vector3(),
		distance_sqrd_to_closest_point = INF,
		closest_control_point = -1,
		distance_sqrd_to_closest_control_point = INF,
	}
	if _is_simulating and _representation_settings.get_should_hide_virtual_object_during_simulation(DnaStructure):
		# path cannot be querried during simulation
		return result
	var dna_structure: DnaStructure = in_context.nano_structure as DnaStructure
	if dna_structure == null:
		# not a dna structure
		return result
	var path: PackedVector3Array = dna_structure.get_baked_path()
	var ray_from: Vector3 = in_camera.project_position(in_screen_pos, in_camera.near)
	var ray_to: Vector3 = in_camera.project_position(in_screen_pos, in_camera.far)
	var accum_path_progress: float = 0
	for p in range(1, path.size()):
		var p0: Vector3 = path[p-1]
		var p1: Vector3 = path[p]
		var closest_segment: PackedVector3Array = Geometry3D.get_closest_points_between_segments(p0, p1, ray_from, ray_to)
		var r0: Vector3 = closest_segment[0]
		var r1: Vector3 = closest_segment[1]
		var screen_path_point: Vector2 = in_camera.unproject_position(r0)
		if screen_path_point.distance_squared_to(in_screen_pos) > MAX_DISTANCE_IN_PIXELS_SQRD_TO_PATH:
			accum_path_progress += p0.distance_to(p1)
			continue
		var dist_squared: float = r0.distance_squared_to(r1)
		if dist_squared < result.distance_sqrd_to_closest_point:
			result.distance_sqrd_to_closest_point = dist_squared
			result.path_progress = accum_path_progress + p0.distance_to(r0)
			result.path_pos = r0
		accum_path_progress += p0.distance_to(p1)
	for p in dna_structure.get_control_point_count():
		var point: Vector3 = dna_structure.get_control_point_position(p)
		var screen_control_point: Vector2 = in_camera.unproject_position(point)
		if screen_control_point.distance_squared_to(in_screen_pos) > MAX_DISTANCE_IN_PIXELS_SQRD_TO_CONTROL_POINT:
			continue
		var closest_point_to_ray: Vector3 = Geometry3D.get_closest_point_to_segment(point, ray_from,ray_to)
		var dist_squared: float = point.distance_squared_to(closest_point_to_ray)
		if dist_squared < result.distance_sqrd_to_closest_control_point:
			result.distance_sqrd_to_closest_control_point = dist_squared
			result.closest_control_point = p
	return result


func _calculate_nanotube_path_sqrd_distance_to_camera(in_camera: Camera3D, in_screen_pos: Vector2,
			in_context: StructureContext) -> Dictionary:
	const MAX_DISTANCE_IN_PIXELS_SQRD_TO_CONTROL_POINT: float = 10*10
	const MAX_DISTANCE_IN_PIXELS_SQRD_TO_PATH: float = 5*5
	var result: Dictionary = {
		path_progress = 0.0,
		path_pos = Vector3(),
		distance_sqrd_to_closest_point = INF,
		closest_control_point = -1,
		distance_sqrd_to_closest_control_point = INF,
	}
	if _is_simulating and _representation_settings.get_should_hide_virtual_object_during_simulation(CarbonNanotubeStructure):
		# path cannot be querried during simulation
		return result
	var nanotube_structure: CarbonNanotubeStructure = in_context.nano_structure as CarbonNanotubeStructure
	if nanotube_structure == null:
		# not a nanotube
		return result
	var ray_from: Vector3 = in_camera.project_position(in_screen_pos, in_camera.near)
	var ray_to: Vector3 = in_camera.project_position(in_screen_pos, in_camera.far)
	var p0: Vector3 = nanotube_structure.get_control_point_position(0)
	var p1: Vector3 = nanotube_structure.get_control_point_position(1)
	var closest_segment: PackedVector3Array = Geometry3D.get_closest_points_between_segments(p0, p1, ray_from, ray_to)
	var r0: Vector3 = closest_segment[0]
	var r1: Vector3 = closest_segment[1]
	var screen_path_point: Vector2 = in_camera.unproject_position(r0)
	if screen_path_point.distance_squared_to(in_screen_pos) <= MAX_DISTANCE_IN_PIXELS_SQRD_TO_PATH:
		var dist_squared: float = r0.distance_squared_to(r1)
		if dist_squared < result.distance_sqrd_to_closest_point:
			result.distance_sqrd_to_closest_point = dist_squared
			result.path_progress = p0.distance_to(r0)
			result.path_pos = r0
	for p in 2:
		var point: Vector3 = nanotube_structure.get_control_point_position(p)
		var screen_control_point: Vector2 = in_camera.unproject_position(point)
		if screen_control_point.distance_squared_to(in_screen_pos) > MAX_DISTANCE_IN_PIXELS_SQRD_TO_CONTROL_POINT:
			continue
		var closest_point_to_ray: Vector3 = Geometry3D.get_closest_point_to_segment(point, ray_from,ray_to)
		var dist_squared: float = point.distance_squared_to(closest_point_to_ray)
		if dist_squared < result.distance_sqrd_to_closest_control_point:
			result.distance_sqrd_to_closest_control_point = dist_squared
			result.closest_control_point = p
	return result


func _calculate_shape_sqr_distance_to_camera(in_camera: Camera3D, in_screen_pos: Vector2,
			in_context: StructureContext) -> float:
	if _is_simulating and _representation_settings.get_should_hide_virtual_object_during_simulation(NanoShape):
		return INF
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



