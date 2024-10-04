extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")
const ScreneCaptureDialogScn = preload("res://editor/controls/screen_capture_dialog/screen_capture_dialog.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Capture Camera Image"),
		_execute_action,
		tr("Take an screenshot of current view and save it as a PNG file")
	)
	with_validation(_can_capture)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_add_x64.svg"))


func _can_capture() -> bool:
	# Nothing to capture if workspace is empty
	return _workspace_context != null and \
			_workspace_context.get_visible_structure_contexts().size() > 0


func _execute_action() -> void:
	WorkspaceUtils.open_screen_capture_dialog(_workspace_context)
	_ring_menu.close()

