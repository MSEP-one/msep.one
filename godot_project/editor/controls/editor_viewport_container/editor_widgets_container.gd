class_name EditorWidgetsContainer
extends Control

## This is the parent control for all the viewport widgets.
## It will adjust its scale and position to match the workspace tools container
## control, so the widgets don't go over the dockers on the side.


const TAB_BAR_HEIGHT: float = 64.0
const MESSAGE_BAR_HEIGHT: float = 19.0

var _workspace_tools_container: Control


func set_workspace_tools_reference(in_workspace_tools_container: Control) -> void:
	if _workspace_tools_container and _workspace_tools_container.resized.is_connected(_on_working_area_control_resized):
		_workspace_tools_container.resized.disconnect(_on_working_area_control_resized)
	
	_workspace_tools_container = in_workspace_tools_container
	if not _workspace_tools_container:
		return
	
	_workspace_tools_container.resized.connect(_on_working_area_control_resized)
	_on_working_area_control_resized()


func _on_working_area_control_resized() -> void:
	var tools_global_transform: Transform2D = _workspace_tools_container.get_global_transform()
	var tools_global_rect: Rect2 = tools_global_transform * _workspace_tools_container.get_rect()
	tools_global_rect = tools_global_rect.grow_side(SIDE_TOP, -TAB_BAR_HEIGHT)
	tools_global_rect = tools_global_rect.grow_side(SIDE_BOTTOM, -MESSAGE_BAR_HEIGHT)
	set_deferred(&"size", tools_global_rect.size)
	global_position = tools_global_rect.position
	
	for c in get_children():
		if c is Container:
			c.queue_sort()
