class_name RingLevelCameraMenu extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("Camera"),
		tr("Camera related actions")
	)
	add_action(preload("ring_action_capture_camera_image.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_change_camera_position.gd").new(in_workspace_context, in_menu))
