extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")
const DnaRepresentation = RepresentationSettings.DnaRepresentation


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
			tr("Toggle DNA Representation"),
			_execute_action,
			"", # dynamic description returned from get_description() override
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_dna_representation_96px.svg"))


func get_description() -> String:
	var current_representation: DnaRepresentation = \
		_workspace_context.workspace.representation_settings.get_dna_representation()
	match current_representation:
		DnaRepresentation.SIMPLIFIED:
			return tr(&"Show DNA Objects as Atoms and Bonds")
		DnaRepresentation.ATOMS_AND_BONDS:
			return tr(&"Show DNA Objects as simplified blocks")
	return ""


func _execute_action() -> void:
	var current_representation: DnaRepresentation = \
		_workspace_context.workspace.representation_settings.get_dna_representation()
	match current_representation:
		DnaRepresentation.SIMPLIFIED:
			_workspace_context.workspace.representation_settings.set_dna_representation(DnaRepresentation.ATOMS_AND_BONDS)
		DnaRepresentation.ATOMS_AND_BONDS:
			_workspace_context.workspace.representation_settings.set_dna_representation(DnaRepresentation.SIMPLIFIED)
	_workspace_context.snapshot_moment("Change DNA Representation")
	_ring_menu.close()
