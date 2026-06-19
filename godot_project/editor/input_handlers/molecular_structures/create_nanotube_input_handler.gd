extends InputHandlerCreateObjectBase


var _drag_started_at := -Vector3.INF
var _press_down_position := -Vector2.INF
var _dragging: bool = false


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	var create_object_parameters: CreateObjectParameters = get_workspace_context().create_object_parameters
	create_object_parameters.create_mode_enabled_changed.connect(_on_create_object_parameters_create_mode_enabled_changed)


## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return false


func is_exclusive_input_consumer() -> bool:
	return _dragging


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.DRAG_DROP_CREATE_NANOTUBE


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(in_structure_context: StructureContext) -> bool:
	var workspace_context: WorkspaceContext = in_structure_context.workspace_context
	if (workspace_context.create_object_parameters.get_create_mode_type()
		!= CreateObjectParameters.CreateModeType.CREATE_CARBON_NANOTUBE):
			return false
	if workspace_context.is_creating_object():
		workspace_context.abort_creating_object()
	return true


func handle_inputs_end() -> void:
	_gesture_reset()


func handle_input_omission() -> void:
	_gesture_reset()



## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, _out_context: StructureContext) -> bool:
	if in_input_event.is_action_pressed(&"cancel"):
		var was_capturing_inputs: bool = is_exclusive_input_consumer()
		_gesture_reset()
		return was_capturing_inputs
	
	if in_input_event is InputEventMouseMotion:
		var is_drag_not_started_yet: bool = _dragging == false and _press_down_position != -Vector2.INF
		if is_drag_not_started_yet:
			if _press_down_position.distance_squared_to(in_input_event.global_position) > MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED:
				_dragging = true
				_drag_started_at = InputHandlerCreateObjectBase.calculate_preview_position_at_pos(
					get_workspace_context(), _press_down_position
				)
				var rendering: Rendering = get_workspace_context().get_rendering()
				rendering.carbon_nanotube_preview_show()
				rendering.carbon_nanotube_preview_set_start_pos(_drag_started_at)
				return true
			return false
		if _dragging:
			update_preview_position()
			return true
		return false
	if in_input_event is InputEventMouseButton:
		var mouse_up: bool = not in_input_event.pressed
		var mouse_down: bool = not mouse_up
		if in_input_event.button_index == MOUSE_BUTTON_LEFT and mouse_up and _dragging == false:
			# reset drag state
			_gesture_reset()
			return false
		elif  in_input_event.button_index == MOUSE_BUTTON_RIGHT and mouse_down and _dragging:
			# Cancelled with right mouse button
			_gesture_reset()
			return true
		elif in_input_event.button_index == MOUSE_BUTTON_LEFT and mouse_up and _dragging:
			# This is a drag and drop result
			var drop_pos: Vector3 = InputHandlerCreateObjectBase.calculate_preview_position_at_pos(
					get_workspace_context(), _press_down_position
				)
			_create_tube(_drag_started_at, drop_pos)
			_gesture_reset()
			return true
		elif in_input_event.button_index == MOUSE_BUTTON_LEFT and mouse_down:
			assert(_dragging == false)
			_press_down_position = in_input_event.global_position
	return false


func _gesture_reset() -> void:
	_drag_started_at = -Vector3.INF
	_press_down_position = -Vector2.INF
	_dragging = false
	_hide_preview()


func set_preview_position(in_position: Vector3) -> void:
	var rendering: Rendering = get_workspace_context().get_rendering()
	rendering.carbon_nanotube_preview_set_end_pos(in_position)


func _hide_preview() -> void:
	var rendering: Rendering = get_workspace_context().get_rendering()
	rendering.carbon_nanotube_preview_hide()


func _create_tube(from_pos: Vector3, to_pos: Vector3) -> void:
	var rendering: Rendering = get_workspace_context().get_rendering()
	if not rendering.is_carbon_nanotube_preview_visible_and_valid():
		return
	print_debug("TODO: Create Single-Wall-Carbon-Nanotube from: ", from_pos, " to ", to_pos)
	pass


func _on_create_object_parameters_create_mode_enabled_changed(in_enabled: bool) -> void:
	if not in_enabled:
		_hide_preview()
