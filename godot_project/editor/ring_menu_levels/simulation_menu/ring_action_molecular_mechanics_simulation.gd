extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")
const OpenmmWarningDialog = preload("res://autoloads/openmm/alert_controls/openmm_alert_dialog.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Molecular Dynamics Simulation"),
		_execute_action,
		tr("Perform a MD simulation with specified environment variables")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_representation_mechanical_simulation.svg"))

func _execute_action() -> void:
	_workspace_context.create_object_parameters.set_simulation_type(
			CreateObjectParameters.SimulationType.MOLECULAR_MECHANICS)
	MolecularEditorContext.request_workspace_docker_focus(SimulationsDocker.UNIQUE_DOCKER_NAME, &"Molecular Dynamics Simulation")

