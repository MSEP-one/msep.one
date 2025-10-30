class_name RingActionCommunityImport extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Import Project"),
		_execute_action,
		tr("Download a project from the Community and include add it to your project.")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("uid://so7ocf4kpq2f"))


func _execute_action() -> void:
	_ring_menu.close()
	DisplayServer.dialog_show.call_deferred(
		"Unimplemented",
		"Unimplemented option: PROJECT IMPORT",
		["OK"], Callable())
