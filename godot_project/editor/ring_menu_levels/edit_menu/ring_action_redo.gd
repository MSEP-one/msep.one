class_name RingActionRedo extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	assert(_workspace_context)
	super._init(
		tr("Redo"),
		_execute_action,
		tr("Redo")
	)
	with_validation(can_redo)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_edit/icons/icon_redo_x96.svg"))


func can_redo() -> bool:
	return _workspace_context.can_redo()


func get_description() -> String:
	if can_redo():
		var action_name: String = _workspace_context.get_redo_name()
		return tr("Redo") + " '%s'" % [action_name]
	return tr("Redo")


func _execute_action() -> void:
	_workspace_context.apply_next_snapshot()
	_ring_menu.refresh_button_availability()

