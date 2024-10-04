class_name RingActionSaveWorkspace extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Save Workspace"),
		_execute_action,
		tr("Save the workspace to disk"),
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_file/icons/icon_save_workspace.svg"))


func _execute_action() -> void:
	_ring_menu.close()
	MolecularEditorContext.save_workspace(
		_workspace_context.workspace,
		_workspace_context.workspace.resource_path
	)
