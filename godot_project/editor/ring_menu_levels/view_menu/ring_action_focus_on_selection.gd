extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
			tr("Focus on Selected Objects"),
			_execute_action,
			tr("Move the camera to ensure all selected objects are in the frustrum")
	)
	with_validation(_can_focus)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_view/icons/icon_focus_selection.svg"))


func _can_focus() -> bool:
	return _workspace_context != null and \
			_workspace_context.get_structure_contexts_with_selection().size() > 0


func _execute_action() -> void:
	assert(_workspace_context)
	var focus_aabb: AABB = WorkspaceUtils.get_selected_objects_aabb(_workspace_context)
	var create_params: CreateObjectParameters = _workspace_context.create_object_parameters
	var create_distance_is_fixed: bool = \
		create_params.get_create_distance_method() == \
		CreateObjectParameters.CreateDistanceMethod.FIXED_DISTANCE_TO_CAMERA
	if create_params.get_create_mode_enabled() and not create_distance_is_fixed:
		var created_object_aabb: AABB = WorkspaceUtils.get_created_object_aabb(_workspace_context)
		if created_object_aabb != AABB():
			# center the template AABB in the center of selection
			created_object_aabb.position = focus_aabb.get_center() - created_object_aabb.size / 2
			focus_aabb = focus_aabb.expand(created_object_aabb.position)
			focus_aabb = focus_aabb.expand(created_object_aabb.end)
	WorkspaceUtils.focus_camera_on_aabb(_workspace_context, focus_aabb)
	_ring_menu.close()
