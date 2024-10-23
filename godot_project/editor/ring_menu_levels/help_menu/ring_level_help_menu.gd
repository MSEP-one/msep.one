class_name RingLevelHelpMenu extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("Help"),
		tr("Find Help")
	)
	add_action(preload("ring_action_about_msep.gd").new(in_workspace_context, in_menu))
	add_action(_workspace_context.action_documentation)
