class_name RingActionUndo extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	assert(_workspace_context)
	super._init(
		tr("Undo"),
		_execute_action,
		tr("Undo")
	)
	with_validation(can_undo)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_edit/icons/icon_undo_x96.svg"))


func can_undo() -> bool:
	return _workspace_context.can_undo()


func get_description() -> String:
	if can_undo():
		var action_name: String = _workspace_context.get_undo_name()
		return tr("Undo") + " '%s'" % [action_name]
	return tr("Undo")


func _execute_action() -> void:
	_workspace_context.apply_previous_snapshot()

