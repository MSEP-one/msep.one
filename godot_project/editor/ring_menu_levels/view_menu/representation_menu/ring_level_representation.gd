class_name RingLevelRepresentation extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("Representation"),
		tr("Change Representation Style.")
	)
	add_action(preload("ring_action_balls_and_sticks.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_van_der_waals.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_mechanical_simulation.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_sticks.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_enhanced_sticks.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_enhanced_sticks_and_balls.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_atom_size_settings.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_theme.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_camera_projection.gd").new(in_workspace_context, in_menu))
