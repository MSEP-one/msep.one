extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
			tr("Override Default Colors"),
			_execute_action,
			tr("Change the color of selected atoms.")
	)
	with_validation(_has_selection)


func get_icon() -> RingMenuIcon:
	# FIXME
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_override_default_colors_96px.svg"))


func _has_selection() -> bool:
	return _workspace_context.is_any_atom_selected()


func _execute_action() -> void:
	MolecularEditorContext.request_workspace_docker_focus(DynamicContextDocker.UNIQUE_DOCKER_NAME, &"Override Default Colors")
	_ring_menu.close()
