extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
			tr("Show/Hide Hydrogens"),
			_execute_action,
			tr("Show or hide the hydrogen atoms in the 3D view")
	)
	var settings: RepresentationSettings = in_workspace_context.workspace.representation_settings
	settings.hydrogen_visibility_changed.connect(_on_hydrogen_visibility_changed)
	_on_hydrogen_visibility_changed(settings.get_hydrogens_visible())


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_show_hydrogens_96px.svg"))


func _execute_action() -> void:
	if _workspace_context.are_hydrogens_visualized():
		_workspace_context.disable_hydrogens_visualization(true)
	else:
		_workspace_context.enable_hydrogens_visualization(false)
	_ring_menu.close()


func _on_hydrogen_visibility_changed(hydrogen_visible: bool) -> void:
	if hydrogen_visible:
		_title = tr("Hide Hydrogens")
	else:
		_title = tr("Show Hydrogens")
