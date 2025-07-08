class_name WorkspaceCamera extends Node3D

var axes_widget : Control = null
var no_selection_reference_position: Vector3 = Vector3.ZERO

@onready var _initial_far_plane: float = _camera.far

var _camera: Camera3D

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_camera = $Camera3D as Camera3D
		_camera.set_script(Tracker)
	if what == NOTIFICATION_READY:
		MolecularEditorContext.msep_editor_settings.changed.connect(_on_editor_settings_changed)
		_on_editor_settings_changed.call_deferred()


func _on_editor_settings_changed() -> void:
	var orthographic_setting_enabled: bool = \
		MolecularEditorContext.msep_editor_settings.editor_camera_orthographic_projection_enabled
	
	if orthographic_setting_enabled and _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return # Nothing to do
	
	if orthographic_setting_enabled:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = 1.0
		# A too big far plane causes glitches in some NVidia cards
		_camera.far = 4000.0
		# Move the camera out of the visible structures
		var viewport: WorkspaceEditorViewport = get_viewport() as WorkspaceEditorViewport
		var workspace_context: WorkspaceContext = viewport.get_workspace_context()
		if workspace_context.has_visible_objects():
			var workspace_aabb: AABB = WorkspaceUtils.get_visible_objects_aabb(workspace_context)
			WorkspaceUtils.move_camera_outside_of_aabb(workspace_context, workspace_aabb)
	else:
		# Move the camera forward or backward based on the orthographic zoom level
		var _move_offset: Vector3
		if _camera.size >= 1.0:
			_move_offset = Vector3.BACK * (_camera.size - 1.0)
		else:
			_move_offset = Vector3.FORWARD / max(_camera.size, 0.1)
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.far = _initial_far_plane
		_camera.translate_object_local(_move_offset)
	


class Tracker extends Camera3D:
	signal transform_changed(new_global_transform: Transform3D)
	signal projection_changed()
	signal changed()
	
	var _last_known_transform := Transform3D()
	
	func _init() -> void:
		set_notify_transform(true)
		transform_changed.connect(_on_anything_changed.unbind(1))
		projection_changed.connect(_on_anything_changed)
	
	func _enter_tree() -> void:
		_last_known_transform = global_transform
	
	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			if global_transform != _last_known_transform:
				_last_known_transform = global_transform
				transform_changed.emit(global_transform)
	
	func _set(property: StringName, value: Variant) -> bool:
		if property in [
				&"projection",
				&"far",
				&"near",
				&"fov",
				&"size",
			]:
			if get(property) != value:
				ScriptUtils.call_deferred_once(projection_changed.emit)
		return false
	
	func _on_anything_changed() -> void:
		changed.emit()
