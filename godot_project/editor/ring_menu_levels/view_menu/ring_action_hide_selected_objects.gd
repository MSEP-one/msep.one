extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
			tr("Hide Selected Objects"),
			_execute_action,
			tr("Hide selected objects or atoms.")
	)
	with_validation(_has_selection)


func get_icon() -> RingMenuIcon:
	# FIXME
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_hide_selected_96px.svg"))


func _has_selection() -> bool:
	return is_instance_valid(_workspace_context) and _workspace_context.has_selection()


func _execute_action() -> void:
	WorkspaceUtils.hide_selected_objects(_workspace_context)
	_ring_menu.close()
