class_name RingActionViewMenu extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("View"),
		_execute_action,
		tr("Change visualization options")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_view_menu.svg"))


func _execute_action() -> void:
	var menu_level_view_menu := RingLevelViewMenu.new(
		_workspace_context, _ring_menu
	)
	_ring_menu.add_level(menu_level_view_menu)
	
