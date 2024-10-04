class_name OrientationWidget
extends Node3D

const DISTANCE_FROM_CAMERA = 90.0
@onready var _draw_orientation_widget: OrientationWidgetUI = %DrawOrientationWidget
@onready var _editor_viewport: WorkspaceEditorViewport = _find_editor_viewport()
@onready var _camera : Camera3D = _find_editor_viewport_camera_3d()


func _ready() -> void:
	_position_orientation_wrapper()


func _process(_in_delta : float) -> void:
	_position_orientation_wrapper()


func is_snap_active() -> bool:
	return _draw_orientation_widget.snap_is_active


func finish_snap() -> void:
	if _draw_orientation_widget != null:
		_draw_orientation_widget.finish_snap()


func set_workspace_tools_reference(in_workspace_tools_container: Control) -> void:
	_draw_orientation_widget.set_workspace_tools_reference(in_workspace_tools_container)


func _find_editor_viewport() -> WorkspaceEditorViewport:
	var ancestor: Node = get_parent()
	while not ancestor is SubViewportContainer:
		ancestor = ancestor.get_parent()
	if not ancestor.visibility_changed.is_connected(_on_editor_viewport_container_visibility_changed):
		ancestor.visibility_changed.connect(_on_editor_viewport_container_visibility_changed.bind(ancestor))
	return ancestor.get_child(0) as WorkspaceEditorViewport


func _find_editor_viewport_camera_3d() -> Camera3D:
	assert(_editor_viewport, "Invalid project hierarchy, could not find viewport!")
	return _editor_viewport.get_camera_3d()


func _position_orientation_wrapper() -> void:
	if not is_instance_valid(_camera):
		return
	var camera_direction := _camera.global_transform.basis.get_rotation_quaternion() \
			* Vector3.FORWARD
	global_position = _camera.global_position + camera_direction * DISTANCE_FROM_CAMERA


func _on_editor_viewport_container_visibility_changed(in_container: SubViewportContainer) -> void:
	_draw_orientation_widget.visible = in_container.is_visible_in_tree()
