class_name RingActionCopy extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	assert(_workspace_context)
	super._init(
		tr("Copy"),
		_execute_action,
		tr("Copy selection into clipboard")
	)
	with_validation(can_copy)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_edit/icons/icon_copy_x96.svg"))


func can_copy() -> bool:
	if _workspace_context == null:
		return false
	return _workspace_context.has_selection()


func _execute_action() -> void:
	_ring_menu.close()
	if can_copy():
		MolecularEditorContext.copy_selection()

