extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")
const OpenmmWarningDialog = preload("res://autoloads/openmm/alert_controls/openmm_alert_dialog.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Relax"),
		_execute_action,
		tr("Minimize the energy of the selected or all visible molecules")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/ring_menu_levels/simulation_menu/icons/icon_ActionRing_RelaxBonds.svg"))

func _execute_action() -> void:
	_workspace_context.create_object_parameters.set_simulation_type(
			CreateObjectParameters.SimulationType.RELAXATION)
	MolecularEditorContext.request_workspace_docker_focus(SimulationsDocker.UNIQUE_DOCKER_NAME, &"Relax")

