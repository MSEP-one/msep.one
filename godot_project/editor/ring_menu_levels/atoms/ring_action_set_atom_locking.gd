extends RingMenuAction


const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Lock/Unlock Atoms"),
		_execute_action,
		tr("Toggle the locking state of selected atoms")
	)
	with_validation(_validate)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_LockUnlockAtoms.svg"))


func _validate() -> bool:
	if is_instance_valid(_workspace_context):
		return _workspace_context.is_any_atom_selected()
	return false


func _execute_action() -> void:
	_ring_menu.close()
	assert(_validate(), "Cannot execute the action right now, there are not atoms selected")
	MolecularEditorContext.request_workspace_docker_focus(DynamicContextDocker.UNIQUE_DOCKER_NAME, &"Lock/Unlock Atoms")


func get_validation_problem_description() -> String:
	return "Cannot lock or unlock atoms, because no atoms are selected."
