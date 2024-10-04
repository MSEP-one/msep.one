extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
			tr("Focus on Visible Objects"),
			_execute_action,
			tr("Move the camera to ensure all visible objects are in the frustrum")
	)
	with_validation(_can_focus)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_focus.svg"))


func _can_focus() -> bool:
	return _workspace_context != null and \
			_workspace_context.get_visible_structure_contexts().size() > 0


func _execute_action() -> void:
	assert(_workspace_context)
	var focus_aabb: AABB = WorkspaceUtils.get_visible_objects_aabb(_workspace_context)
	WorkspaceUtils.focus_camera_on_aabb(_workspace_context, focus_aabb)
	_ring_menu.close()

