class_name RingLevelFileMenu extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("File"),
		tr("Save, Open, or Import files.")
	)
	add_action(RingActionCreateWorkspace.new(_workspace_context, in_menu))
	add_action(RingActionLoadWorkspace.new(_workspace_context, in_menu))
	add_action(RingActionSaveWorkspace.new(_workspace_context, in_menu))
	add_action(RingActionSaveWorkspaceAs.new(_workspace_context, in_menu))
	add_action(_workspace_context.action_import_file)
	add_action(_workspace_context.action_import_from_library)
	add_action(_workspace_context.action_load_fragment)
	add_action(_workspace_context.action_documentation)
	
