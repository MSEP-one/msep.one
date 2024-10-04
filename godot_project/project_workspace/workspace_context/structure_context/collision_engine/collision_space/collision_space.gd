class_name CollisionSpace extends Node


const DEFAULT_COLLISION_LAYER: int = 1
const INVALID_OBJECT_ID: int = -1

var _space_rid: RID


var _id_to_collision_rid: Dictionary = {
	#nano_structure_object_id<int> : collision_area_rid<RID>
}

var _collision_rid_to_id: Dictionary = {
	#collision_area_rid<RID>: nano_structure_object_id<int>
}


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_space_rid = PhysicsServer3D.space_create()
		assert(INVALID_OBJECT_ID == AtomicStructure.INVALID_ATOM_ID and INVALID_OBJECT_ID == AtomicStructure.INVALID_BOND_ID)
	if what == NOTIFICATION_PREDELETE:
		PhysicsServer3D.free_rid(_space_rid)


func is_external_id_known(in_object_id: int) -> bool:
	return _id_to_collision_rid.has(in_object_id)


func get_shape_rid(in_object_id: int) -> RID:
	return PhysicsServer3D.area_get_shape(_id_to_collision_rid[in_object_id], 0)


func get_all_ids() -> PackedInt32Array:
	return PackedInt32Array(_id_to_collision_rid.keys())


func get_nmb_of_objects() -> int:
	return _id_to_collision_rid.size()


# TODO: check in 4.2 if Dictionary/Array types are supported correctly for this case, 
# (possibly create an issue for this case if it's already possible to define typed Arrays/Dicts)
func free_colliders_and_get_shapes() -> Array: #returns Array[RID]
	var result: Dictionary = {}
	if _space_rid.is_valid():
		var collision_rids: Array = _collision_rid_to_id.keys()
		for area_rid: RID in collision_rids:
			var nmb_of_shapes_in_area: int = PhysicsServer3D.area_get_shape_count(area_rid)
			for shape_idx in nmb_of_shapes_in_area:
				var shape_rid: RID = PhysicsServer3D.area_get_shape(area_rid, shape_idx)
				result[shape_rid] = true
			PhysicsServer3D.free_rid(area_rid)
		PhysicsServer3D.free_rid(_space_rid)
	_id_to_collision_rid.clear()
	_collision_rid_to_id.clear()
	_space_rid = PhysicsServer3D.space_create()
	return result.keys()


func add_collider(in_object_id: int, in_shape_id: RID, in_transform: Transform3D, in_collision_layer: int = DEFAULT_COLLISION_LAYER) -> RID:
	var area_id: RID = PhysicsServer3D.area_create()
	PhysicsServer3D.area_add_shape(area_id, in_shape_id)
	PhysicsServer3D.area_set_space(area_id, _space_rid)
	PhysicsServer3D.area_set_transform(area_id, in_transform)
	PhysicsServer3D.area_set_collision_layer(area_id, in_collision_layer)
	PhysicsServer3D.area_set_collision_mask(area_id, 0)
	PhysicsServer3D.area_set_monitorable(area_id, false)
	_id_to_collision_rid[in_object_id] = area_id
	_collision_rid_to_id[area_id] = in_object_id
	return area_id


func free_collider_and_get_related_shape(in_object_id: int) -> RID:
	var area_rid: RID = _id_to_collision_rid[in_object_id]
	var out_shape_rid: RID = PhysicsServer3D.area_get_shape(area_rid, 0)
	PhysicsServer3D.free_rid(area_rid)
	_collision_rid_to_id.erase(area_rid)
	_id_to_collision_rid.erase(in_object_id)
	return out_shape_rid


func set_collider_enabled(in_object_id: int, in_enabled: bool) -> void:
	var area_rid: RID = _id_to_collision_rid[in_object_id]
	PhysicsServer3D.area_set_shape_disabled(area_rid, 0, not in_enabled)


## Replaces the shape for given object, old shape is still in PhysicServer memory, clear it manually
## if necessary
func replace_shape_keep_old(in_object_id: int, new_shape: RID) -> void:
	var area_rid: RID = _id_to_collision_rid[in_object_id]
	PhysicsServer3D.area_remove_shape(area_rid, 0)
	PhysicsServer3D.area_add_shape(area_rid, new_shape)


func update_collider_transform(in_object_id: int, in_transform: Transform3D) -> void:
	PhysicsServer3D.area_set_transform(_id_to_collision_rid[in_object_id], in_transform)


func change_collision_layer(in_object_id: int, in_collision_layer: int) -> void:
	var area_rid: RID = _id_to_collision_rid[in_object_id]
	PhysicsServer3D.area_set_collision_layer(area_rid, in_collision_layer)


func raycast(in_from: Vector3, in_direction: Vector3, in_collision_mask: int = DEFAULT_COLLISION_LAYER) -> int:
	var physics_direct_state: PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(_space_rid)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = in_collision_mask
	query.from = in_from
	query.to = (query.from + in_direction * 1000 * CollisionEngine.PHYSIC_SPACE_SIZE_FACTOR)
	var result: Dictionary = physics_direct_state.intersect_ray(query)
	if result.is_empty():
		return INVALID_OBJECT_ID
	
	return _collision_rid_to_id[result.rid]


func frustrum_intersection(in_camera: Camera3D, in_rectangle: Rect2i,
			in_collision_mask: int = DEFAULT_COLLISION_LAYER,
			in_max_nmb_of_results: int = _id_to_collision_rid.keys().size()) -> PackedInt32Array:
	
	var physics_direct_state: PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(_space_rid)
	var box_shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	box_shape_query.collide_with_areas = true
	box_shape_query.collide_with_bodies = false
	box_shape_query.collision_mask = in_collision_mask
	
	var convex_shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	var corner_1: Vector2i = in_rectangle.position
	var corner_2: Vector2i = Vector2i(in_rectangle.end.x, in_rectangle.position.y)
	var corner_3: Vector2i = Vector2i(in_rectangle.position.x, in_rectangle.end.y)
	var corner_4: Vector2i = in_rectangle.end
	
	var font_plate_corner_1: Vector3 = in_camera.project_position(corner_1, 1) * CollisionEngine.PHYSIC_SPACE_SIZE_FACTOR
	var font_plate_corner_2: Vector3 = in_camera.project_position(corner_2, 1) * CollisionEngine.PHYSIC_SPACE_SIZE_FACTOR
	var font_plate_corner_3: Vector3 = in_camera.project_position(corner_3, 1) * CollisionEngine.PHYSIC_SPACE_SIZE_FACTOR
	var font_plate_corner_4: Vector3 = in_camera.project_position(corner_4, 1) * CollisionEngine.PHYSIC_SPACE_SIZE_FACTOR
	
	var back_plate_corner_1: Vector3 = in_camera.project_position(corner_1, 1000) * CollisionEngine.PHYSIC_SPACE_SIZE_FACTOR
	var back_plate_corner_2: Vector3 = in_camera.project_position(corner_2, 1000) * CollisionEngine.PHYSIC_SPACE_SIZE_FACTOR
	var back_plate_corner_3: Vector3 = in_camera.project_position(corner_3, 1000) * CollisionEngine.PHYSIC_SPACE_SIZE_FACTOR
	var back_plate_corner_4: Vector3 = in_camera.project_position(corner_4, 1000) * CollisionEngine.PHYSIC_SPACE_SIZE_FACTOR
	
	var center_pos: Vector3 = (font_plate_corner_1 + font_plate_corner_2 + font_plate_corner_3 + \
			font_plate_corner_4 + back_plate_corner_1 + back_plate_corner_2 + back_plate_corner_3 + \
			back_plate_corner_4) / 8.0
	
	var points: PackedVector3Array = PackedVector3Array()
	points.append(font_plate_corner_1 - center_pos)
	points.append(font_plate_corner_2 - center_pos)
	points.append(font_plate_corner_3 - center_pos)
	points.append(font_plate_corner_4 - center_pos)
	points.append(back_plate_corner_1 - center_pos)
	points.append(back_plate_corner_2 - center_pos)
	points.append(back_plate_corner_3 - center_pos)
	points.append(back_plate_corner_4 - center_pos)
	convex_shape.points = points
	
	box_shape_query.shape = convex_shape
	box_shape_query.transform = Transform3D(Basis(), center_pos)
	
	var collisions: Array[Dictionary] = physics_direct_state.intersect_shape(box_shape_query, in_max_nmb_of_results)
	var result: PackedInt32Array = PackedInt32Array()
	for collision in collisions:
		result.append(_collision_rid_to_id[collision.rid])
	
	return result
