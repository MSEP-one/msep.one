class_name RingLevelShapes extends RingMenuLevel


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		[],
		tr("Reference Shapes"),
		tr("Select and place a shape of specified type and size.")
	)
	for shape in _workspace_context.create_object_parameters.supported_shapes:
		var action_set_shape := RingActionSelectShape.new(
			shape, _workspace_context, _ring_menu
		)
		add_action(action_set_shape)
	
