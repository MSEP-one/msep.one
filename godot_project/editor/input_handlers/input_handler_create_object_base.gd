class_name InputHandlerCreateObjectBase
extends InputHandlerBase

## Abstract class for input handlers that creates new elements in the 3D viewport
## Handles the common logic for preview positioning

const INVALID_CENTER_OF_SELECTION = Vector3.INF
const MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED = 20 * 20
var _last_center_of_selection: Vector3 = INVALID_CENTER_OF_SELECTION

# region: Virtual

## VIRTUAL: Tells the input handler where to place the preview model.
func set_preview_position(_position: Vector3) -> void:
	assert(false, "Override this function")


# region: Public


## Returns the distance between the mouse cursor and the surface of the shape below
## Returns NAN if the mouse cursor is not over a shape.
func get_distance_to_shape_surface_under_mouse() -> float:
	var workspace_context: WorkspaceContext = get_workspace_context()
	var camera: Camera3D = get_workspace_context().get_editor_viewport().get_camera_3d()
	var camera_plane: Plane = Plane(-camera.global_basis.z, camera.position)
	var mouse_position: Vector2 = camera.get_viewport().get_mouse_position()
	var visible_structures: Array[StructureContext] = workspace_context.get_visible_structure_contexts()
	var distance_to_shape_surface: float = NAN
	
	for context in visible_structures:
		var structure: NanoStructure = context.nano_structure
		if not structure is NanoShape:
			continue
		var hits: PackedVector3Array = structure.intersect_shape_with_screen_point(mouse_position, camera, true)
		if hits.is_empty():
			continue
		for hit: Vector3 in hits:
			var distance: float = camera_plane.distance_to(hit)
			if is_nan(distance_to_shape_surface) or distance < distance_to_shape_surface:
				distance_to_shape_surface = distance
	
	return distance_to_shape_surface


func is_snap_to_shape_surface_enabled() -> bool:
	var workspace_context: WorkspaceContext = get_workspace_context()
	var snap_to_surface_enabled: bool = workspace_context.create_object_parameters.get_snap_to_shape_surface()
	# Holding Ctrl inverts the setting
	if Input.is_key_pressed(KEY_CTRL):
		return not snap_to_surface_enabled
	else:
		return snap_to_surface_enabled


func update_preview_position() -> void:
	if BusyIndicator.visible:
		_set_preview_position_to_distance(10000.0)
		return
	
	if is_snap_to_shape_surface_enabled():
		var distance_to_shape_surface: float = get_distance_to_shape_surface_under_mouse()
		if not is_nan(distance_to_shape_surface):
			_set_preview_position_to_distance(distance_to_shape_surface)
			return
	
	var method: CreateObjectParameters.CreateDistanceMethod = \
		get_workspace_context().create_object_parameters.get_create_distance_method()
	match method:
		CreateObjectParameters.CreateDistanceMethod.CLOSEST_OBJECT_TO_POINTER:
			if not _try_set_preview_position_to_closest_object():
				_set_preview_position_to_distance(get_workspace_context().create_object_parameters.drop_distance)
		CreateObjectParameters.CreateDistanceMethod.CENTER_OF_SELECTION:
			if not _try_set_preview_position_to_center_of_selection():
				_set_preview_position_to_distance(get_workspace_context().create_object_parameters.drop_distance)
		CreateObjectParameters.CreateDistanceMethod.FIXED_DISTANCE_TO_CAMERA:
			_set_preview_position_to_distance(get_workspace_context().create_object_parameters.drop_distance)


# region: Private

func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	var workspace_context: WorkspaceContext = get_workspace_context()
	workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_changed)


func _on_workspace_context_selection_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	var workspace_context: WorkspaceContext = get_workspace_context()
	if not workspace_context.has_selection():
		return
	var selection_aabb: AABB = workspace_context.get_selection_aabb()
	_last_center_of_selection = selection_aabb.get_center()


func _try_set_preview_position_to_closest_object() -> bool:
	var workspace_context: WorkspaceContext = get_workspace_context()
	var camera: Camera3D = get_workspace_context().get_editor_viewport().get_camera_3d()
	var mouse_position: Vector2 = camera.get_viewport().get_mouse_position()
	var visible_structures: Array[StructureContext] = workspace_context.get_visible_structure_contexts()
	var closest_distance_squared_2d: float = NAN
	var closest_position_3d := Vector3.ZERO
	for context in visible_structures:
		var structure: NanoStructure = context.nano_structure
		var collision_engine: CollisionEngine = context.get_collision_engine()
		var closest_atom_id: int = collision_engine.get_closest_atom_to_screen_point(camera, mouse_position)
		if closest_atom_id != AtomicStructure.INVALID_ATOM_ID:
			var atom_pos_3d: Vector3 = structure.atom_get_position(closest_atom_id)
			var atom_pos_2d: Vector2 = camera.unproject_position(atom_pos_3d)
			if is_nan(closest_distance_squared_2d) or atom_pos_2d.distance_squared_to(mouse_position) < closest_distance_squared_2d:
				closest_distance_squared_2d = atom_pos_2d.distance_squared_to(mouse_position)
				closest_position_3d = atom_pos_3d
		if structure is NanoShape:
			var shape_pos_3d: Vector3 = structure.get_position()
			var shape_pos_2d: Vector2 = camera.unproject_position(shape_pos_3d)
			if is_nan(closest_distance_squared_2d) or shape_pos_2d.distance_squared_to(mouse_position) < closest_distance_squared_2d:
				closest_distance_squared_2d = shape_pos_2d.distance_squared_to(mouse_position)
				closest_position_3d = shape_pos_3d
	if not is_nan(closest_distance_squared_2d):
		var closest_obj_plane: Plane = Plane(camera.basis.z, closest_position_3d)
		_set_preview_position_to_distance(abs(closest_obj_plane.distance_to(camera.global_position)))
		return true
	return false


func _try_set_preview_position_to_center_of_selection() -> bool:
	var workspace_context: WorkspaceContext = get_workspace_context()
	if _last_center_of_selection != INVALID_CENTER_OF_SELECTION:
		var camera: Camera3D = workspace_context.get_editor_viewport().get_camera_3d()
		var selection_center_plane: Plane = Plane(camera.basis.z, _last_center_of_selection)
		var distance_to_camera: float = selection_center_plane.distance_to(camera.global_position)
		if distance_to_camera >= 0.0:
			# Preview position will keep using center of selection even if it is outside
			# of the camera, *except* when the center of selection is behind the camera.
			# In that case it will fall back to "fixed distance".
			_set_preview_position_to_distance(distance_to_camera)
			return true
	return false


func _set_preview_position_to_distance(in_distance: float) -> void:
	var mouse_position: Vector2 = get_workspace_context().get_editor_viewport().get_mouse_position()
	var camera: Camera3D = get_workspace_context().get_editor_viewport().get_camera_3d()
	var new_pos3d: Vector3 = camera.project_position(mouse_position, in_distance)
	set_preview_position(new_pos3d)


