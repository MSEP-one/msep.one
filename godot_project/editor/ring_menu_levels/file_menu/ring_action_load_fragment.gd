class_name RingActionLoadFragment
extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Load Small Molecules"),
		_execute_action,
		tr("Load a chemical structure from a list of samples."),
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_file/icons/load_fragment.svg"))


func _execute_action() -> void:
	_workspace_context.create_object_parameters.set_create_mode_type(CreateObjectParameters.CreateModeType.CREATE_FRAGMENT)
	MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME, &"Small Molecules")
	_ring_menu.close()
