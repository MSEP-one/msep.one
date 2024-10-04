class_name RingActionAddShapes extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Reference Shapes"),
		_execute_action,
		tr("Create a geometrical shape to use as base for buinding your system")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_referenceShapes.svg"))


func _execute_action() -> void:
	var structure := NanoShape.new()
	structure.set_shape(null)
	_workspace_context.start_creating_object(structure)
	_workspace_context.create_object_parameters.set_create_mode_type(
			CreateObjectParameters.CreateModeType.CREATE_SHAPES)
	MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
	var menu_level_select_shape := RingLevelShapes.new(
		_workspace_context, _ring_menu
	)
	_ring_menu.add_level(menu_level_select_shape)
	
