class_name AtomLabelsRingMenuAction extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Show/Hide Element Labels"),
		_execute_action,
		tr("Turns on/off element symbol labels for 3d view"),
	)
	with_validation(_can_activate)
	var settings: RepresentationSettings = in_workspace_context.workspace.representation_settings
	settings.atom_labels_visibility_changed.connect(_on_atom_labels_visibility_changed)
	_on_atom_labels_visibility_changed(settings.get_display_atom_labels())


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_atom_labels.svg"))


func _can_activate() -> bool:
	if _workspace_context == null:
		return false
	var uncompatible_representations := [Rendering.Representation.STICKS, Rendering.Representation.ENHANCED_STICKS]
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	var current_rendering_representation: Rendering.Representation = representation_settings.get_rendering_representation()
	var can_representation_use_3d_labels: bool = not current_rendering_representation in uncompatible_representations
	return can_representation_use_3d_labels


func _execute_action() -> void:
	if _workspace_context.are_atom_labels_visualised():
		_workspace_context.disable_atom_labels()
	else:
		_workspace_context.enable_atom_labels()
	_ring_menu.close()


func _on_atom_labels_visibility_changed(atoms_visible: bool) -> void:
	if atoms_visible:
		_title = tr("Hide Element Labels")
	else:
		_title = tr("Show Element Labels")
