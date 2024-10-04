class_name RingLevelSelectMenu extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("Select"),
		tr("Select Operations.")
	)
	add_action(_workspace_context.action_invert_selection)
	add_action(_workspace_context.action_select_all)
	add_action(_workspace_context.action_deselect_all)
	add_action(_workspace_context.action_select_by_type)
	add_action(_workspace_context.action_select_connected)
	add_action(_workspace_context.action_grow_selection)
	add_action(_workspace_context.action_shrink_selection)
