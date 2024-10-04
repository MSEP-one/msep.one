class_name RingActionSelectElement extends RingMenuAction


const RingMenuAtomIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_atom_icon/ring_menu_atom_icon.tscn")


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null
var element: int = -1


func _init(in_element: ElementData, in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	assert(in_element != null and in_element.number > 0, "Invalid atomic number")
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	element = in_element.number
	super._init(
		tr(in_element.name),
		_execute_action,
		in_element.symbol + ": " +tr(in_element.name)
	)
	with_validation(_can_select)


func get_icon() -> RingMenuIcon:
	return RingMenuAtomIconScn.instantiate().init(element)


func _can_select() -> bool:
	if element != PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
		return true
	return _workspace_context.are_hydrogens_visualized()


func _execute_action() -> void:
	_workspace_context.create_object_parameters.set_new_atom_element(element)
	_workspace_context.create_object_parameters.set_create_mode_type(
			CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS)
	_ring_menu.close()


