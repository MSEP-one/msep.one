class_name RingLevelViewMenu extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("View"),
		tr("Change visualization options.")
	)
	# TODO: add actions?
	add_action(preload("ring_action_focus_on_visible.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_focus_on_selection.gd").new(in_workspace_context, in_menu))
	add_action(RingActionRepresentation.new(in_workspace_context, in_menu))
	add_action(preload("ring_action_atom_label_settings.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_show_bonds.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_show_hydrogens.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_override_default_colors.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_hide_selected_objects.gd").new(in_workspace_context, in_menu))
	add_action(preload("ring_action_show_hidden_objects.gd").new(in_workspace_context, in_menu))
