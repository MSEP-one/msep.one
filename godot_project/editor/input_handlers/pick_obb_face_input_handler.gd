extends InputHandlerBase


const BoxFace = AlignSelectionParameters.BoxFace

var _parameters: AlignSelectionParameters
var _space: CollisionSpace
var _box_rid: RID
var _picking_obb: bool = false


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	_parameters = in_context.align_selection_parameters
	assert(_parameters)
	_parameters.pick_specific_obb_requested.connect(_on_pick_specific_obb_requested)


func _on_pick_specific_obb_requested() -> void:
	_picking_obb = true
	const COLLISION_SPACE_SCENE = preload("uid://b8ahf120j3w87")
	_space = COLLISION_SPACE_SCENE.instantiate()
	_box_rid = PhysicsServer3D.box_shape_create()
	const BOX_EXTENTS: Vector3 = Vector3.ONE * 0.5
	PhysicsServer3D.shape_set_data(_box_rid, BOX_EXTENTS)
	const FACE_SIZE_MULTIPLIER: Dictionary[BoxFace, Vector3] = {
		BoxFace.FRONT_BACK : Vector3(0.95, 0.95, 1),
		BoxFace.TOP_BOTTOM : Vector3(0.95, 1, 0.95),
		BoxFace.LEFT_RIGHT : Vector3(1, 0.95, 0.95),
	}
	for context: StructureContext in _parameters.get_alignable_structure_contexts():
		var obb: OBB = context.get_selection_obb()
		var id: int = context.get_int_guid() * 10
		for face: BoxFace in [BoxFace.FRONT_BACK, BoxFace.TOP_BOTTOM, BoxFace.LEFT_RIGHT]:
			var t: Transform3D = obb.transform.scaled_local(obb.box.size * FACE_SIZE_MULTIPLIER[face])
			_space.add_collider(id + int(face), _box_rid, t)


func get_priority() -> int:
	return BuiltinInputHandlerPriorities.PICK_OBB_FACE_HANDLER_PRIORITY


func handles_empty_selection() -> bool:
	return _picking_obb


func handles_structure_context(_in_structure_context: StructureContext) -> bool:
	return _picking_obb


func is_exclusive_input_consumer() -> bool:
	return _picking_obb


func forward_input(in_input_event: InputEvent, in_camera: Camera3D, _in_context: StructureContext) -> bool:
	if in_input_event.is_action_pressed(&"ui_cancel"):
		PhysicsServer3D.free_rid(_box_rid)
		_space.queue_free()
		_parameters.set_specific_obb_and_face(null, AlignSelectionParameters.BoxFace.UNDEFINED)
		_picking_obb = false
		return true
	if in_input_event is InputEventMouseMotion:
		var ray_from: Vector3 = in_camera.project_ray_origin(in_input_event.position)
		var ray_dir: Vector3 = in_camera.project_ray_normal(in_input_event.position)
		var collided_id: int = _space.raycast(ray_from, ray_dir)
		if collided_id == Workspace.INVALID_OBJECT_INDEX:
			_parameters.set_specific_obb_and_face(null, AlignSelectionParameters.BoxFace.UNDEFINED)
		else:
			var int_guid: int = int(collided_id * 0.1)
			var face: BoxFace = (collided_id - int_guid * 10) as BoxFace
			_parameters.set_specific_obb_and_face(
				get_workspace_context().get_nano_structure_context_from_id(int_guid),
				face
			)
	if in_input_event is InputEventMouseButton and in_input_event.is_pressed():
		PhysicsServer3D.free_rid(_box_rid)
		_space.queue_free()
		_picking_obb = false
	return true

