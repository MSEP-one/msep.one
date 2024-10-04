extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")
const ScreneCaptureDialogScn = preload("res://editor/controls/screen_capture_dialog/screen_capture_dialog.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Change Position"),
		_execute_action,
		tr("Parametrically change camera position and look direction")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/camera_position_dialog/icon_change_position_action.svg"))


func _execute_action() -> void:
	WorkspaceUtils.open_camera_position_dialog()
	_ring_menu.close()

