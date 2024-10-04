extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Theme"),
		_execute_action,
		tr("3D viewport Theme"),
	)
	with_validation(_can_activate)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_edit/icons/icon_theme_x96.svg"))


func _can_activate() -> bool:
	if _workspace_context == null:
		return false
	return true


func _execute_action() -> void:
	MolecularEditorContext.request_workspace_docker_focus(WorkspaceSettingsDocker.UNIQUE_DOCKER_NAME, &"Representation Settings")
	_ring_menu.close()
