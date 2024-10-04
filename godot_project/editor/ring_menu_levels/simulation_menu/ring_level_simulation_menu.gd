class_name RingLevelSimulationMenu extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null

const RingActionRelax: Script = preload("res://editor/ring_menu_levels/simulation_menu/ring_action_relax.gd")
const RingActionMolecularMechanicsSimulation: Script = preload("res://editor/ring_menu_levels/simulation_menu/ring_action_molecular_mechanics_simulation.gd")

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("Simulation"),
		tr("Perform physically accurate operations.")
	)
	add_action(RingActionRelax.new(in_workspace_context, in_menu))
	add_action(RingActionMolecularMechanicsSimulation.new(in_workspace_context, in_menu))
	add_action(RingActionValidateBonds.new(in_workspace_context, in_menu))
