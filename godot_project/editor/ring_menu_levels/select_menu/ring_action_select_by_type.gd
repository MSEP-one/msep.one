class_name RingActionSelectByType
extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	assert(_workspace_context)
	super._init(
		tr("Select Atoms by Type"),
		_execute_action,
		tr("Select visible atoms by their atomic number")
	)
	with_validation(has_structure_with_atoms)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_select_by_type_96px.svg"))


func has_structure_with_atoms() -> bool:
	if _workspace_context == null:
		return false
	return not _workspace_context.get_visible_structure_contexts(false).is_empty()


func _execute_action() -> void:
	_ring_menu.close()
	MolecularEditorContext.request_workspace_docker_focus(DynamicContextDocker.UNIQUE_DOCKER_NAME, &"Find Visible Atoms by Type")
