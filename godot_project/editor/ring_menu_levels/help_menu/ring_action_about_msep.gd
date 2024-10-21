extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

const DOCUMENTATION_PATH_SOURCE: String = "res://documentation/msep_documentation.pdf"
const DOCUMENTATION_FILE_NAME_IN_USER_DIR = "msep_one_documentation.pdf"

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("About MSEP.one"),
		_execute_action,
		tr("See authors, legals, and attribution information about MSEP."),
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_about_msep.png"))


func _execute_action() -> void:
	_ring_menu.close()
	Engine.get_main_loop().notification(MainLoop.NOTIFICATION_WM_ABOUT)

