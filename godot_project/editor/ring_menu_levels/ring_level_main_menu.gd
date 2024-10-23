class_name RingLevelMainMenu extends RingMenuLevel

var _workspace_context: WorkspaceContext

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	super._init([], tr("Actions"))
	
	add_action(RingActionFileMenu.new(_workspace_context, in_menu))
	add_action(RingActionAtomsMenu.new(_workspace_context, in_menu))
	add_action(RingActionAddShapes.new(_workspace_context, in_menu))
	add_action(RingActionVirtualObjectsMenu.new(_workspace_context, in_menu))
	add_action(RingActionEditMenu.new(_workspace_context, in_menu))
	add_action(RingActionViewMenu.new(_workspace_context, in_menu))
	add_action(RingActionSimulationMenu.new(_workspace_context, in_menu))
	add_action(RingActionSelectMenu.new(_workspace_context, in_menu))
	add_action(RingActionHelpMenu.new(_workspace_context, in_menu))
	
