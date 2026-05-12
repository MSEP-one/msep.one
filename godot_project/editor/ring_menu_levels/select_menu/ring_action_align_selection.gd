extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	assert(_workspace_context)
	super._init(
		tr("Align Selection"),
		_execute_action,
		tr("Align Selection")
	)
	with_validation(can_align_selection)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_align_selection_x96.svg"))


func can_align_selection() -> bool:
	if _workspace_context == null:
		return false
	return _workspace_context.align_selection_parameters.can_align_selection()


func _execute_action() -> void:
	_ring_menu.close()
	if can_align_selection():
		MolecularEditorContext.request_workspace_docker_focus(DynamicContextDocker.UNIQUE_DOCKER_NAME, &"Align Selection")
