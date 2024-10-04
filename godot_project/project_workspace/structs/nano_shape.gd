class_name NanoShape extends NanoStructure

signal transform_changed(new_transform: Transform3D)
signal shape_changed(new_shape: PrimitiveMesh)
signal shape_properties_changed()

const _SELECT_SHAPE_MINIMUM_PIXEL_DISTANCE_SQUARED: float = 8 * 8

@export var _transform: Transform3D
@export var _shape: PrimitiveMesh

var is_ghost: bool = false
var _shape_data_tool: MeshDataTool = null


func _on_shape_changed_signal_emited() -> void:
	# Clear the ArrayMesh cache used for mouse hover operations
	_shape_data_tool = null
	shape_properties_changed.emit()

## Structure types needs to return a valid type name to be considered valid
func get_type() -> StringName:
	if _shape == null:
		return StringName()
	if _shape.has_method(&"get_shape_name"):
		return _shape.get_shape_name()
	return StringName(_shape.get_class().replace("Mesh", ""))


func get_readable_type() -> String:
	return str(get_type())


func get_transform() -> Transform3D:
	return _transform


func set_transform(new_transform: Transform3D) -> void:
	if new_transform == _transform:
		return
	_transform = new_transform
	transform_changed.emit(new_transform)


func set_position(new_position: Vector3) -> void:
	if _transform.origin == new_position:
		return
	_transform.origin = new_position
	transform_changed.emit(_transform)


func get_position() -> Vector3:
	return _transform.origin


func get_shape() -> PrimitiveMesh:
	return _shape


func set_shape(in_shape: PrimitiveMesh) -> void:
	if in_shape == _shape:
		return
	if _shape != null:
		_shape.changed.disconnect(_on_shape_changed_signal_emited)
	_shape = in_shape
	if in_shape != null:
		in_shape.changed.connect(_on_shape_changed_signal_emited)
	_on_shape_changed_signal_emited()
	shape_changed.emit(in_shape)


## Returns a texture to represent the structure in the UI, it can be a predefined
## icon or a thumbnail of the actual structure
func get_icon() -> Texture2D:
	return null


func get_aabb() -> AABB:
	return get_shape_aabb()


func get_shape_aabb() -> AABB:
	var aabb := AABB()
	if _shape != null:
		if _shape_data_tool == null:
			var mesh_arrays: Array = _shape.get_mesh_arrays()
			var array_mesh := ArrayMesh.new()
			array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
			_shape_data_tool = MeshDataTool.new()
			_shape_data_tool.create_from_surface(array_mesh, 0)
		var vertex_count: int = _shape_data_tool.get_vertex_count()
		if vertex_count > 0:
			aabb.position = _transform * _shape_data_tool.get_vertex(0)
			for i in range(vertex_count):
				var vertex: Vector3 = _transform * _shape_data_tool.get_vertex(i)
				aabb = aabb.expand(vertex)
	return aabb.abs()

## Returns a PackedVector3Array with all hits that the ray projected from screen point
func intersect_shape_with_screen_point(in_screen_position: Vector2, in_camera: Camera3D, faces_only: bool = false) -> PackedVector3Array:
	var hits := PackedVector3Array()
	if not _visible:
		return hits
	
	var screen_pivot_position: Vector2 = in_camera.unproject_position(_transform.origin)
	var distance_to_hit_position_squared: float = in_screen_position.distance_squared_to(screen_pivot_position)
	if distance_to_hit_position_squared <= _SELECT_SHAPE_MINIMUM_PIXEL_DISTANCE_SQUARED:
		hits.push_back(_transform.origin)
	
	var camera_forward := in_camera.project_ray_normal(in_screen_position)
	var camera_ray_origin := in_camera.project_ray_origin(in_screen_position)
	var inspect_edges: Dictionary = {}
	if _shape != null:
		if _shape_data_tool == null:
			var mesh_arrays: Array = _shape.get_mesh_arrays()
			var array_mesh := ArrayMesh.new()
			array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
			_shape_data_tool = MeshDataTool.new()
			_shape_data_tool.create_from_surface(array_mesh, 0)
		for face_idx in _shape_data_tool.get_face_count():
			var face_normal: Vector3 = _shape_data_tool.get_face_normal(face_idx)
			face_normal *= Quaternion(_transform.inverse().basis)
			if face_normal.dot(camera_forward) < 0:
				# Back culling passes
				if faces_only:
					var polygon_3d: PackedVector3Array = []
					var polygon_2d: PackedVector2Array = []
					for i in 3:
						var vertex_id: int = _shape_data_tool.get_face_vertex(face_idx, i)
						var vertex: Vector3 = _shape_data_tool.get_vertex(vertex_id) * _transform.inverse()
						var vertex_2d: Vector2 = in_camera.unproject_position(vertex)
						polygon_2d.push_back(vertex_2d)
						polygon_3d.push_back(vertex)
					if Geometry2D.is_point_in_polygon(in_screen_position, polygon_2d):
						var plane: Plane = Plane(polygon_3d[0], polygon_3d[1], polygon_3d[2])
						var pos: Variant = plane.intersects_ray(camera_ray_origin, camera_forward)
						if pos != null:
							hits.push_back(pos)
				else:
					# add the 3 edges of the triangle to inspect_edges
					for face_edge_idx in 3:
						var edge_idx: int = _shape_data_tool.get_face_edge(face_idx, face_edge_idx)
						inspect_edges[edge_idx] = true

		for edge_idx: int in inspect_edges.keys():
			var vertex_id_a: int = _shape_data_tool.get_edge_vertex(edge_idx, 0)
			var vertex_id_b: int = _shape_data_tool.get_edge_vertex(edge_idx, 1)
			var vertex_a: Vector3 = _shape_data_tool.get_vertex(vertex_id_a) * _transform.inverse()
			var vertex_b: Vector3 = _shape_data_tool.get_vertex(vertex_id_b) * _transform.inverse()
			var vertex_a_2d: Vector2 = in_camera.unproject_position(vertex_a)
			var vertex_b_2d: Vector2 = in_camera.unproject_position(vertex_b)
			if vertex_a_2d.distance_squared_to(vertex_b_2d) <= 1:
				# Edge projection is less than 1 pixel long, just geometry step
				var distance_to_edge_squared: float = in_screen_position.distance_squared_to(vertex_a_2d)
				if distance_to_edge_squared < _SELECT_SHAPE_MINIMUM_PIXEL_DISTANCE_SQUARED:
					hits.append_array([vertex_a, vertex_b])
				continue
			var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(in_screen_position, vertex_a_2d, vertex_b_2d)
			var distance_to_edge_squared: float = in_screen_position.distance_squared_to(closest_point)
			if distance_to_edge_squared < _SELECT_SHAPE_MINIMUM_PIXEL_DISTANCE_SQUARED:
				var lerp_weight: float = (vertex_a_2d - closest_point).length() / (vertex_a_2d - vertex_b_2d).length()
				hits.push_back(lerp(vertex_a, vertex_b, lerp_weight))
	return hits

func is_shape_within_screen_rect(in_camera: Camera3D, screen_rect: Rect2i) -> bool:
	if not _visible:
		return false
	screen_rect = screen_rect.abs()
	if _shape != null:
		if _shape_data_tool == null:
			var mesh_arrays: Array = _shape.get_mesh_arrays()
			var array_mesh := ArrayMesh.new()
			array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
			_shape_data_tool = MeshDataTool.new()
			_shape_data_tool.create_from_surface(array_mesh, 0)
		for vertex_idx in range(_shape_data_tool.get_vertex_count()):
			var vertex_pos: Vector3 = _shape_data_tool.get_vertex(vertex_idx) * _transform.inverse()
			var vertex_screen_pos: Vector2 = in_camera.unproject_position(vertex_pos)
			if !screen_rect.has_point(vertex_screen_pos):
				return false
		return true
	return false


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.create_state_snapshot()
	snapshot["script.resource_path"] = get_script().resource_path
	snapshot["_transform"] = _transform
	snapshot["is_ghost"] = is_ghost
	snapshot["_shape"] = _shape.duplicate(true)
	return snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_state_snapshot)
	_transform = in_state_snapshot["_transform"]
	is_ghost = in_state_snapshot["is_ghost"]
	_shape = in_state_snapshot["_shape"].duplicate(true)
	# Because the _shape is a duplicate of the original we recreate its signal connection.
	_shape.changed.connect(_on_shape_changed_signal_emited)
	_shape_data_tool = null
