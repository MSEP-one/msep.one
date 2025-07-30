extends AcceptDialog


class SetCameraTransformHelper:
	var _camera: Camera3D
	
	func _init(in_camera: Camera3D) -> void:
		_camera = in_camera
	
	func get_global_position() -> Vector3:
		return _camera.global_position
	
	func set_global_position(in_position: Vector3) -> void:
		_camera.global_position = in_position
	
	func get_quaternion() -> Quaternion:
		return _camera.quaternion
	
	func set_quaternion(in_rotation: Quaternion) -> void:
		_camera.set_quaternion(in_rotation)

	func store_undo_snapshot() -> void:
		# InspectorControlVector3 expects this function to exist, but we don't
		# want to create a new snapshot on each spinbox change, so this does nothing.
		pass 

var _camera_position: InspectorControlVector3
var _camera_direction: InspectorControlDirection
var _helper: SetCameraTransformHelper


func _init() -> void:
	EditorSfx.register_window(self, true)
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		visibility_changed.connect(_on_visibility_changed)
		_camera_position = %CameraPosition as InspectorControlVector3
		_camera_direction = %CameraDirection as InspectorControlDirection
		_on_visibility_changed()


func _on_visibility_changed() -> void:
	if visible:
		_create_helper()
		_camera_position.setup(
			_helper.get_global_position,
			_helper.set_global_position
		)
		_camera_direction.setup(
			_helper.get_quaternion,
			_helper.set_quaternion
		)
	else:
		_camera_position.setup(_get_dummy_position)
		_camera_direction.setup(_get_dummy_rotation)
		_helper = null


# Requires a valid workspace context so it cannot happen during instantiation.
# Camera dialog is shared across workspaces so the helper has to be recreated each time.
func _create_helper() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	assert(is_instance_valid(workspace_context), "Trying to use the camera dialog before the workspace is ready.")
	var workspace_viewport: WorkspaceEditorViewport = workspace_context.get_editor_viewport()
	var workspace_camera: Camera3D = workspace_viewport.get_camera_3d()
	_helper = SetCameraTransformHelper.new(workspace_camera)


func _get_dummy_position() -> Vector3:
	# this prevents assertion on InspectorControlVector3
	return Vector3()


func _get_dummy_rotation() -> Quaternion:
	#this prevents assertion on InspectorControlDirection
	return Quaternion()
