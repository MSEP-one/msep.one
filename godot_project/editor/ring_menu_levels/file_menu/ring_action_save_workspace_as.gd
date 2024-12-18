class_name RingActionSaveWorkspaceAs extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Save Workspace As ..."),
		_execute_action,
		tr("Save the workspace as a new file."),
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_file/icons/icon_save_workspace_as.svg"))


func _execute_action() -> void:
	_ring_menu.close()
	Editor_Utils.get_editor().show_save_workspace_dialog(_workspace_context.workspace)
