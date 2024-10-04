class_name RingActionAutoBonder extends RingMenuAction


const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Auto-Create Bonds"),
		_execute_action,
		tr("Find and add valid covalent bonds between selected atoms")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_AutoBonder.svg"))


func _execute_action() -> void:
	_ring_menu.close()
	_workspace_context.create_object_parameters.set_create_mode_type(
			CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS)
	MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME, &"Auto-Create Bonds")
