class_name RingActionSelectShape extends RingMenuAction


const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null
var _shape: PrimitiveMesh = null


func _init(in_shape: PrimitiveMesh, in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	assert(in_shape != null, "Invalid shape")
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	_shape = in_shape
	var name: String = in_shape.get_class().replace("Mesh", "")
	if in_shape.has_method(&"get_shape_name"):
		name = str(in_shape.get_shape_name())
	super._init(
			tr(name),
			_execute_action,
			tr(name)
	)


func get_icon() -> RingMenuIcon:
	if ResourceLoader.exists("res://editor/ring_menu_levels/shapes/icons/icon_ActionRing_Shape_%s.svg" % get_title()):
		return RingMenuSpriteIconScn.instantiate().init(load("res://editor/ring_menu_levels/shapes/icons/icon_ActionRing_Shape_%s.svg" % get_title()))
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_referenceShapes.svg"))


func _execute_action() -> void:
	_workspace_context.create_object_parameters.set_selected_shape_for_new_objects(_shape)
	_workspace_context.create_object_parameters.set_create_mode_type(CreateObjectParameters.CreateModeType.CREATE_SHAPES)
	MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
	_ring_menu.close()

