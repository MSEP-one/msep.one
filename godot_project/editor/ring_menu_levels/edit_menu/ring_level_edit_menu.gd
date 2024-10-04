class_name RingLevelEditMenu extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("Edit"),
		tr("Use the clipboard, transform selection, or perform Undo/Redo operations.")
	)
	add_action(_workspace_context.action_delete)
	add_action(_workspace_context.action_redo)
	add_action(_workspace_context.action_undo)
	add_action(_workspace_context.action_copy)
	add_action(_workspace_context.action_cut)
	add_action(_workspace_context.action_paste)
	add_action(_workspace_context.action_bonded_paste)
