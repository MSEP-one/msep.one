class_name RingActionDeselectAll extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	assert(_workspace_context)
	super._init(
		tr("Deselect All"),
		_execute_action,
		tr("Clears selection")
	)
	with_validation(has_selection)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_deselect_all_x96.svg"))


func has_selection() -> bool:
	if _workspace_context == null:
		return false
	return _workspace_context.get_structure_contexts_with_selection().size() > 0


func _execute_action() -> void:
	_ring_menu.close()
	if has_selection():
		_workspace_context.deselect_all()

