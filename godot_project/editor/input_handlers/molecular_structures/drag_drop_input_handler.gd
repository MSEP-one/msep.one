extends SelectionInputHandlerBase

const MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_BOX_SELECTION = 20

var _box_selection: BoxSelection
var _has_box_selection_started: bool = false
var _selection_initial_point: Vector2 = Vector2(-100, -100)
var _is_mouse_down: bool = false


# region virtual

func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	_box_selection = in_context.get_box_selection()


func is_exclusive_input_consumer() -> bool:
	return _has_box_selection_started


func handle_inputs_end() -> void:
	pass


func handle_input_omission() -> void:
	_is_mouse_down = false
	_has_box_selection_started = false


## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return true


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(_in_structure_context: StructureContext) -> bool:
	return true


func _on_request_create_atom() -> void:
	pass


func _on_request_enter_transform_mode() -> void:
	pass


func get_priority() -> int:
	return BuiltinInputHandlerPriorities.BOX_SELECTION


func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, _in_context: StructureContext) -> bool:
	if in_input_event.is_action_pressed(&"select", false, false) or \
		_user_is_selecting_on_mac_pressed(in_input_event, false, false):
		assert (in_input_event is InputEventMouseButton)
		_selection_initial_point = in_input_event.position
		_is_mouse_down = true
		return false
	var workspace_context: WorkspaceContext = get_workspace_context()
	if (in_input_event.is_action_released(&"select", false) and not in_input_event.is_action_released(&"unselect", true)) \
				or in_input_event.is_action_released(&"multiselect", true):
		assert (in_input_event is InputEventMouseButton)
		if _has_box_selection_started:
			if not in_input_event.is_action_released(&"multiselect", true):
				#Clear Selection
				var visible_structures: Array[StructureContext] = workspace_context.get_visible_structure_contexts()
				for structure_context in visible_structures:
					structure_context.clear_selection()
			_has_box_selection_started = false
			_box_selection.apply_selection()
			_workspace_context.snapshot_moment("Change Selection")
			if !workspace_context.has_selection():
				# Selection was cleared, DynamicContextDocker is no longer relevant
				if get_workspace_context().is_simulating():
					MolecularEditorContext.request_workspace_docker_focus(SimulationsDocker.UNIQUE_DOCKER_NAME)
				elif MolecularEditorContext.is_workspace_docker_active(GroupsDocker.UNIQUE_DOCKER_NAME):
					# User is managing groups, dont bother him/her
					pass
				else:
					MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
			elif MolecularEditorContext.is_workspace_docker_active(GroupsDocker.UNIQUE_DOCKER_NAME):
				# User is managing groups, dont bother him/her
				pass
			else:
				MolecularEditorContext.request_workspace_docker_focus(DynamicContextDocker.UNIQUE_DOCKER_NAME)
		_is_mouse_down = false
		return false
	elif in_input_event.is_action_released(&"unselect", true) or \
		_user_is_unselecting_on_mac_released(in_input_event, true):
		if _has_box_selection_started:
			_has_box_selection_started = false
			_box_selection.apply_deselection()
		_is_mouse_down = false
		return true
	
	if in_input_event is InputEventMouseMotion:
		if _is_mouse_down:
			if _has_box_selection_started:
				_box_selection.update(in_input_event.position)
				return true
			else:
				var dst_from_start_selection: float = _selection_initial_point.distance_to(in_input_event.position)
				_has_box_selection_started = _has_box_selection_started or dst_from_start_selection > MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_BOX_SELECTION
				if _has_box_selection_started:
					_box_selection.start_selection(_selection_initial_point)
					_box_selection.update(in_input_event.position)
					return true
	return false
