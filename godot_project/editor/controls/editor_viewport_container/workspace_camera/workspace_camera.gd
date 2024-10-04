extends Node3D

var axes_widget : Control = null
var no_selection_reference_position: Vector3 = Vector3.ZERO

@onready var _camera: Camera3D = $Camera3D
@onready var _initial_far_plane: float = _camera.far


func _ready() -> void:
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
