extends AcceptDialog

var _camera_position: InspectorControlVector3
var _camera_direction: InspectorControlDirection

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
		var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
		var workspace_viewport: WorkspaceEditorViewport = workspace_context.get_editor_viewport()
		var workspace_camera: Camera3D = workspace_viewport.get_camera_3d()
		_camera_position.setup(
			workspace_camera.get_global_position,
			workspace_camera.set_global_position
		)
		_camera_direction.setup(
			workspace_camera.get_quaternion,
			workspace_camera.set_quaternion
		)
	else:
		_camera_position.setup(_get_dummy_position)
		_camera_direction.setup(_get_dummy_rotation)


func _get_dummy_position() -> Vector3:
	# this prevents assertion on InspectorControlVector3
	return Vector3()

func _get_dummy_rotation() -> Quaternion:
	#this prevents assertion on InspectorControlDirection
	return Quaternion()
