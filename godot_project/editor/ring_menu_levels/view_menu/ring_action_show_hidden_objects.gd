extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
			tr("Show Hidden Objects"),
			_execute_action,
			tr("Show everything previously hidden.")
	)
	with_validation(_has_hidden_objects)


func get_icon() -> RingMenuIcon:
	# FIXME
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_show_hidden_objects_96px.svg"))


func _has_hidden_objects() -> bool:
	return is_instance_valid(_workspace_context) and _workspace_context.has_hidden_objects()


func _execute_action() -> void:
	WorkspaceUtils.show_hidden_objects(_workspace_context)
	_ring_menu.close()
