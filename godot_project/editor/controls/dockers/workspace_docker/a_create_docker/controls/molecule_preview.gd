extends AspectRatioContainer


var _preview_viewport: PreviewViewport3D
var _three_d_preview_container: SubViewportContainer
var _preview_camera_pivot: Node3D
var _camera_3d: Camera3D
var _rendering: Rendering


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_preview_viewport = %"3DPreviewViewport" as PreviewViewport3D
		_three_d_preview_container = $"3DPreviewContainer" as SubViewportContainer
		_preview_camera_pivot = _preview_viewport.get_node("%PreviewCameraPivot") as Node3D
		_camera_3d = _preview_viewport.get_camera_3d() as Camera3D
		_rendering = _preview_viewport.get_node("%Rendering") as Rendering


func get_rendering() -> Rendering:
	return _rendering


func get_structure_preview() -> StructurePreview:
	return get_rendering().get_node("StructurePreview") as StructurePreview


func _ready() -> void:
	_three_d_preview_container.gui_input.connect(_on_three_d_preview_container_gui_input)


func _on_three_d_preview_container_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseMotion and in_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_preview_camera_pivot.rotation.y += deg_to_rad(-in_event.relative.x)


func set_preview_camera_pivot_position(in_global_position: Vector3) -> void:
	_preview_viewport.set_preview_camera_pivot_position(in_global_position)


func set_preview_camera_distance_to_pivot(in_distance_to_pivot: float) -> void:
	_preview_viewport.set_preview_camera_distance_to_pivot(in_distance_to_pivot)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_preview_viewport.update(delta)
