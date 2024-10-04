class_name RingActionInvertSelection extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	assert(_workspace_context)
	super._init(
		tr("Invert Selection"),
		_execute_action,
		tr("Invert Selection")
	)
	with_validation(has_visible_objects)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_invert_selection_x96.svg"))


func has_visible_objects() -> bool:
	if _workspace_context == null:
		return false
	return _workspace_context.has_visible_objects()


func _execute_action() -> void:
	_ring_menu.close()
	if has_visible_objects():
		_workspace_context.invert_selection()
