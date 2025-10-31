class_name RingLevelMsepCommunity extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("Msep Community"),
		tr("Share your projects, or import projects from the Community!")
	)
	add_action(RingActionCommunityAuthenticate.new(_workspace_context, in_menu))
	add_action(RingActionCommunityImport.new(_workspace_context, in_menu))
	add_action(RingActionCommunityShare.new(_workspace_context, in_menu))
	add_action(RingActionCommunityUserProfile.new(_workspace_context, in_menu))
