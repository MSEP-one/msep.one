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
static func get_distance_to_shape_surface_under_mouse(in_workspace_context: WorkspaceContext) -> float:
	var camera: Camera3D = in_workspace_context.get_editor_viewport().get_camera_3d()
	var camera_plane: Plane = Plane(-camera.global_basis.z, camera.position)
	var mouse_position: Vector2 = camera.get_viewport().get_mouse_position()
	var visible_structures: Array[StructureContext] = in_workspace_context.get_visible_structure_contexts()
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


static func is_snap_to_shape_surface_enabled(in_workspace_context: WorkspaceContext) -> bool:
	var snap_to_surface_enabled: bool = in_workspace_context.create_object_parameters.get_snap_to_shape_surface()
	# Holding Ctrl inverts the setting
	if Input.is_key_pressed(KEY_CTRL):
		return not snap_to_surface_enabled
	else:
		return snap_to_surface_enabled


func update_preview_position() -> void:
	if BusyIndicator.visible:
		_set_preview_position_to_distance(10000.0)
		return
	
	if is_snap_to_shape_surface_enabled(get_workspace_context()):
		var distance_to_shape_surface: float = get_distance_to_shape_surface_under_mouse(get_workspace_context())
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


static func calculate_preview_position(in_workspace_context: WorkspaceContext) -> Vector3:
	var main_view: WorkspaceMainView = in_workspace_context.workspace_main_view
	var working_area: Control = main_view.get_working_area_rect_control()
	var screen_center: Vector2 = working_area.get_global_rect().get_center()
	if BusyIndicator.is_active():
		return _get_preview_position_to_distance(in_workspace_context, 10000.0, screen_center)
		
	
	if is_snap_to_shape_surface_enabled(in_workspace_context):
		var distance_to_shape_surface: float = get_distance_to_shape_surface_under_mouse(in_workspace_context)
		if not is_nan(distance_to_shape_surface):
			return _get_preview_position_to_distance(in_workspace_context, distance_to_shape_surface, screen_center)
			
	
	var method: CreateObjectParameters.CreateDistanceMethod = \
		in_workspace_context.create_object_parameters.get_create_distance_method()
	match method:
		CreateObjectParameters.CreateDistanceMethod.CLOSEST_OBJECT_TO_POINTER:
			var pos: Vector3 = _try_get_preview_position_to_closest_object(in_workspace_context, screen_center)
			if is_nan(pos.x):
				pos = _get_preview_position_to_distance(
					in_workspace_context,
					in_workspace_context.create_object_parameters.drop_distance,
					screen_center
				)
			return pos
		CreateObjectParameters.CreateDistanceMethod.CENTER_OF_SELECTION:
			var pos := Vector3(NAN, NAN, NAN)
			if in_workspace_context.has_transformable_selection():
				var selection_aabb: AABB = in_workspace_context.get_selection_aabb()
				var center_of_selection: Vector3 = selection_aabb.get_center()
				pos = _try_get_preview_position_to_center_of_selection(
					in_workspace_context,
					center_of_selection,
					screen_center
				)
			if is_nan(pos.x):
				pos = _get_preview_position_to_distance(
					in_workspace_context,
					in_workspace_context.create_object_parameters.drop_distance,
					screen_center
				)
			return pos
		CreateObjectParameters.CreateDistanceMethod.FIXED_DISTANCE_TO_CAMERA:
			return _get_preview_position_to_distance(
				in_workspace_context,
				in_workspace_context.create_object_parameters.drop_distance,
				screen_center
			)
	assert(false, "Should never happen")
	return Vector3()


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
	var pos: Vector3 = _try_get_preview_position_to_closest_object(
		get_workspace_context(),
		get_workspace_context().get_editor_viewport().get_mouse_position()
	)
	if is_nan(pos.x):
		return false
	set_preview_position(pos)
	return true


static func _try_get_preview_position_to_closest_object(in_workspace_context: WorkspaceContext, in_screen_position: Vector2) -> Vector3:
	var camera: Camera3D = in_workspace_context.get_editor_viewport().get_camera_3d()
	var mouse_position: Vector2 = camera.get_viewport().get_mouse_position()
	var visible_structures: Array[StructureContext] = in_workspace_context.get_visible_structure_contexts()
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
		return _get_preview_position_to_distance(
			in_workspace_context,
			abs(closest_obj_plane.distance_to(camera.global_position)),
			in_screen_position
		)
	return Vector3(NAN, NAN, NAN)


func _try_set_preview_position_to_center_of_selection() -> bool:
	if _last_center_of_selection != INVALID_CENTER_OF_SELECTION:
		var pos: Vector3 = _try_get_preview_position_to_center_of_selection(
			get_workspace_context(),
			_last_center_of_selection,
			get_workspace_context().get_editor_viewport().get_mouse_position()
		)
		if is_nan(pos.x):
			return false
		set_preview_position(pos)
		return true
	return false


static func _try_get_preview_position_to_center_of_selection(
		in_workspace_context: WorkspaceContext,
		in_center_of_selection: Vector3,
		in_screen_position: Vector2) -> Vector3:
	var camera: Camera3D = in_workspace_context.get_editor_viewport().get_camera_3d()
	var selection_center_plane: Plane = Plane(camera.basis.z, in_center_of_selection)
	var distance_to_camera: float = selection_center_plane.distance_to(camera.global_position)
	if distance_to_camera >= 0.0:
		# Preview position will keep using center of selection even if it is outside
		# of the camera, *except* when the center of selection is behind the camera.
		# In that case it will fall back to "fixed distance".
		return _get_preview_position_to_distance(in_workspace_context, distance_to_camera, in_screen_position)
	return Vector3(NAN, NAN, NAN)


func _set_preview_position_to_distance(in_distance: float) -> void:
	set_preview_position(
		_get_preview_position_to_distance(
			get_workspace_context(),
			in_distance,
			get_workspace_context().get_editor_viewport().get_mouse_position()
		)
	)


static func _get_preview_position_to_distance(
		in_workspace_context: WorkspaceContext,
		in_distance: float,
		in_screen_pos: Vector2) -> Vector3:
	var camera: Camera3D = in_workspace_context.get_editor_viewport().get_camera_3d()
	var new_pos3d: Vector3 = camera.project_position(in_screen_pos, in_distance)
	return new_pos3d


