class_name RingActionCreateDnaObject extends RingMenuAction


const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("DNA Object"),
		_execute_action,
		tr("Create a high level representation of a DNA chain.")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_virtual_objects/icons/icon_dna_object.svg"))


func _execute_action() -> void:
	_workspace_context.create_object_parameters.set_create_mode_type(
			CreateObjectParameters.CreateModeType.CREATE_DNA_CHAIN)
	MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME, &"DNA Object")
	_ring_menu.close()


