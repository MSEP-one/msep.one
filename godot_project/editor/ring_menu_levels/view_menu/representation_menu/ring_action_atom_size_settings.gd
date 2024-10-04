extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Balls and Sticks Size Settings"),
		_execute_action,
		tr("Change the size of Atoms for 'Balls and Sticks' Style"),
	)
	with_validation(_can_activate)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_atom_size.svg"))


func _can_activate() -> bool:
	if _workspace_context == null:
		return false
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	return representation_settings.get_rendering_representation() == Rendering.Representation.BALLS_AND_STICKS


func _execute_action() -> void:
	MolecularEditorContext.request_workspace_docker_focus(WorkspaceSettingsDocker.UNIQUE_DOCKER_NAME, &"Representation Settings")
	_ring_menu.close()
