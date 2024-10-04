class_name PreviewViewport3D extends SubViewport


@onready var _preview_camera_pivot: Node3D = %PreviewCameraPivot as Node3D
@onready var _camera_3d: Camera3D = %Camera3D as Camera3D
@onready var _rendering: Rendering = $Rendering as Rendering
@onready var _spring_selection_preview: SpringSelectionPreview = $SpringSelectionPreview as SpringSelectionPreview


var _workspace_context: WorkspaceContext


## Returns the [WorkspaceContext] associated to the active workspace
## Any node inside this viewport can access to it with the following code
## [code]
## var workspace_context: WorkspaceContext = get_viewport().get_workspace_context()
## [/code]
func get_workspace_context() -> WorkspaceContext:
	return _workspace_context


func _ready() -> void:
	# should be processed first for safety reasons - we want for default rendering to be able to set shader parameters
	# as the last one before rendering happes
	assert(_rendering.process_priority == Constants.ProcessPriority.HIGH_1, "Preview rendering should be processed before default rendering")
	_rendering.atom_preview_hide()
	_rendering.bond_preview_hide()
	_rendering.shape_preview_hide()
	_rendering.virtual_motor_preview_hide()
	_rendering.structure_preview_hide()
	_rendering.disable_hover()


## Returns the object in charge of managing rendering of the workspace
func get_rendering() -> Rendering:
	return _rendering


func get_spring_selection_preview() -> SpringSelectionPreview:
	return _spring_selection_preview


func update(delta: float) -> void:
	_rendering.update(delta)


func set_preview_camera_pivot_position(in_global_position: Vector3) -> void:
	if _preview_camera_pivot == null:
		# Too early, let's wait for ready
		await ready
	if !_preview_camera_pivot.is_inside_tree():
		await tree_entered
	_preview_camera_pivot.global_position = in_global_position


func set_preview_camera_distance_to_pivot(in_distance_to_pivot: float) -> void:
	_camera_3d.position.z = in_distance_to_pivot


func set_workspace_context(in_workspace_context: WorkspaceContext) -> void:
	if is_instance_valid(_workspace_context):
		var old_representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
		if old_representation_settings.theme_changed.is_connected(_on_workspace_representation_settings_theme_changed):
			old_representation_settings.theme_changed.disconnect(_on_workspace_representation_settings_theme_changed)
		
	_workspace_context = in_workspace_context
	var new_representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	new_representation_settings.theme_changed.connect(_on_workspace_representation_settings_theme_changed)
	_apply_current_theme()


func _on_workspace_representation_settings_theme_changed() -> void:
	_apply_current_theme()


func _apply_current_theme() -> void:
	if not _rendering.is_initialized():
		return
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	_rendering.apply_theme(representation_settings.get_theme())
