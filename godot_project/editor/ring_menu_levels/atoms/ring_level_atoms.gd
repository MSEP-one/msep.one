class_name RingLevelAtoms extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("Atoms"),
		tr("Free mode for editing molecules and atoms in space")
	)
	add_action(RingActionAutoBonder.new(_workspace_context, in_menu))
	add_action(in_workspace_context.action_add_hydrogens)
	add_action(in_workspace_context.action_correct_overlapping_atoms)
	add_action(preload("ring_action_set_atom_locking.gd").new(_workspace_context, in_menu))
	for element: int in PeriodicTable.NON_METALS:
		var data: ElementData = PeriodicTable.get_by_atomic_number(element) as ElementData
		var action_set_element := RingActionSelectElement.new(
				data, _workspace_context, _ring_menu
		)
		add_action(action_set_element)
	add_action(preload("ring_action_show_periodic_table.gd").new(_workspace_context, in_menu))
