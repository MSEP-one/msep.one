extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")
const NanotubeRepresentation = RepresentationSettings.NanotubeRepresentation


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
			tr("Toggle Nanotube Representation"),
			_execute_action,
			"", # dynamic description returned from get_description() override
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_nanotube_representation_96px.svg"))


func get_description() -> String:
	var current_representation: NanotubeRepresentation = \
		_workspace_context.workspace.representation_settings.get_nanotube_representation()
	match current_representation:
		NanotubeRepresentation.SIMPLIFIED:
			return tr(&"Show Carbon Nanotubes as Atoms and Bonds")
		NanotubeRepresentation.ATOMS_AND_BONDS:
			return tr(&"Show Carbon Nanotubes as simplified cylinders")
	return ""


func _execute_action() -> void:
	var current_representation: NanotubeRepresentation = \
		_workspace_context.workspace.representation_settings.get_nanotube_representation()
	match current_representation:
		NanotubeRepresentation.SIMPLIFIED:
			_workspace_context.workspace.representation_settings.set_nanotube_representation(NanotubeRepresentation.ATOMS_AND_BONDS)
		NanotubeRepresentation.ATOMS_AND_BONDS:
			_workspace_context.workspace.representation_settings.set_nanotube_representation(NanotubeRepresentation.SIMPLIFIED)
	_workspace_context.snapshot_moment("Change Carbon Nanotube Representation")
	_ring_menu.close()
