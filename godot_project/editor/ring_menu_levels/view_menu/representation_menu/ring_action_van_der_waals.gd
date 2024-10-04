extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Van Der Waals"),
		_execute_action,
		tr("Draw atoms as balls, invisible bonds"),
	)
	with_validation(_can_activate)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_representation_balls.svg"))


func _can_activate() -> bool:
	if _workspace_context == null:
		return false
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	return representation_settings.get_rendering_representation() != Rendering.Representation.VAN_DER_WAALS_SPHERES


func _execute_action() -> void:
	assert(_workspace_context)
	_workspace_context.workspace.representation_settings.set_rendering_representation(Rendering.Representation.VAN_DER_WAALS_SPHERES)
	_workspace_context.workspace.representation_settings.emit_changed()
	_ring_menu.refresh_button_availability()
	_workspace_context.snapshot_moment("Representation change to Van Der Waals")
