class_name RingActionVirtualObjectsMenu extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Virtual Objects"),
		_execute_action,
		tr("Manage virtual objects.")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_virtual_objects/icons/icon_object_x96.svg"))


func _execute_action() -> void:
	var menu_level_virtual_objects := RingLevelVirtualObjects.new(
		_workspace_context, _ring_menu
	)
	_ring_menu.add_level(menu_level_virtual_objects)
