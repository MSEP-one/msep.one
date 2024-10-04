class_name RingActionValidateBonds extends RingMenuAction


const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Validate Model"),
		_execute_action,
		tr("Check if every atoms has the correct amounts of bonds.")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_validate_bonds.svg"))


func _execute_action() -> void:
	_ring_menu.close()
	_workspace_context.create_object_parameters.set_simulation_type(
		CreateObjectParameters.SimulationType.VALIDATION)
	MolecularEditorContext.request_workspace_docker_focus(SimulationsDocker.UNIQUE_DOCKER_NAME, &"Validate Model")
