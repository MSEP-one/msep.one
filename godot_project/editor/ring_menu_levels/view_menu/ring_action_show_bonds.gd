extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
			tr("Show/Hide Bonds"),
			_execute_action,
			tr("Show or hide the bonds in the 3D view")
	)
	var settings: RepresentationSettings = in_workspace_context.workspace.representation_settings
	settings.bond_visibility_changed.connect(_on_bond_visibility_changed)
	_on_bond_visibility_changed(settings.get_display_bonds())


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_show_bonds_96px.svg"))


func _can_focus() -> bool:
	return _workspace_context != null and \
			_workspace_context.get_visible_structure_contexts().size() > 0


func _execute_action() -> void:
	var bonds_visible: bool = _workspace_context.are_bonds_visualised()
	_workspace_context.change_bond_visibility(not bonds_visible)
	_ring_menu.close()


func _on_bond_visibility_changed(bond_visible: bool) -> void:
	if bond_visible:
		_title = tr("Hide Bonds")
	else:
		_title = tr("Show Bonds")
