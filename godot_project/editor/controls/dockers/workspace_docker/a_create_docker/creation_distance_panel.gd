extends DynamicContextControl

var check_box_closest_object: CheckBox = null
var check_box_center_of_selection: CheckBox = null
var check_box_fixed_distance: CheckBox = null
var button_group_creation_distance_method: ButtonGroup = null
var creation_distance: SpinBox = null
var snap_to_shape_surface: CheckBox = null

var _weak_workspace_context: WeakRef = weakref(null)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		check_box_closest_object = $VBoxContainer/CheckBoxClosestObject
		check_box_center_of_selection = $VBoxContainer/CheckBoxCenterOfSelection
		check_box_fixed_distance = $VBoxContainer/DistancePickerBox/CheckBoxFixedDistance
		button_group_creation_distance_method = check_box_fixed_distance.button_group
		creation_distance = %CreationDistance
		snap_to_shape_surface = %SnapToShapeSurface
		
		button_group_creation_distance_method.pressed.connect(_on_button_group_creation_distance_method_pressed)
		snap_to_shape_surface.toggled.connect(_on_snap_to_shape_surface_toggled)


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_weak_workspace_context = weakref(in_workspace_context)
	var structure_context: StructureContext = in_workspace_context.get_current_structure_context()
	if !is_instance_valid(structure_context) || !is_instance_valid(structure_context.nano_structure):
		return false
	if not in_workspace_context.create_object_parameters.get_create_mode_type() in [
		CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS,
		CreateObjectParameters.CreateModeType.CREATE_SHAPES,
		CreateObjectParameters.CreateModeType.CREATE_FRAGMENT,
		CreateObjectParameters.CreateModeType.CREATE_VIRTUAL_MOTORS,
	]:
		return false
	if !in_workspace_context.create_object_parameters.creation_distance_from_camera_factor_changed.is_connected(_on_creation_distance_from_camera_factor_changed):
		in_workspace_context.create_object_parameters.create_distance_method_changed.connect(_on_create_distance_method_changed)
		in_workspace_context.create_object_parameters.creation_distance_from_camera_factor_changed.connect(_on_creation_distance_from_camera_factor_changed)
		in_workspace_context.create_object_parameters.snap_to_shape_surface_changed.connect(_on_snap_to_shape_surface_changed)
		creation_distance.min_value = in_workspace_context.create_object_parameters.min_drop_distance
		creation_distance.max_value = in_workspace_context.create_object_parameters.max_drop_distance
		creation_distance.value_changed.connect(_on_creation_distance_value_changed)
		_on_create_distance_method_changed(in_workspace_context.create_object_parameters.get_create_distance_method())
		_on_creation_distance_from_camera_factor_changed(in_workspace_context.create_object_parameters.get_creation_distance_from_camera_factor())
		_on_snap_to_shape_surface_changed(in_workspace_context.create_object_parameters.get_snap_to_shape_surface())
	return structure_context.nano_structure is AtomicStructure


func _on_button_group_creation_distance_method_pressed(in_button: Button) -> void:
	var workspace_context: WorkspaceContext = _weak_workspace_context.get_ref() as WorkspaceContext
	if workspace_context == null:
		return
	match in_button:
		check_box_closest_object:
			workspace_context.create_object_parameters.set_create_distance_method(
				CreateObjectParameters.CreateDistanceMethod.CLOSEST_OBJECT_TO_POINTER)
		check_box_center_of_selection:
			workspace_context.create_object_parameters.set_create_distance_method(
				CreateObjectParameters.CreateDistanceMethod.CENTER_OF_SELECTION)
		check_box_fixed_distance:
			workspace_context.create_object_parameters.set_create_distance_method(
				CreateObjectParameters.CreateDistanceMethod.FIXED_DISTANCE_TO_CAMERA)


func _on_snap_to_shape_surface_toggled(enabled: bool) -> void:
	var workspace_context: WorkspaceContext = _weak_workspace_context.get_ref() as WorkspaceContext
	if workspace_context == null:
		return
	workspace_context.create_object_parameters.set_snap_to_shape_surface(enabled)


func _on_creation_distance_value_changed(in_new_distance: float) -> void:
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	if workspace == null:
		return
	var delta: float = creation_distance.max_value - creation_distance.min_value
	var factor: float = (in_new_distance - creation_distance.min_value) / delta
	var context: WorkspaceContext = MolecularEditorContext.get_workspace_context(workspace)
	context.create_object_parameters.set_creation_distance_from_camera_factor(factor)


func _on_create_distance_method_changed(in_new_method: CreateObjectParameters.CreateDistanceMethod) -> void:
	check_box_closest_object.set_pressed_no_signal(in_new_method == CreateObjectParameters.CreateDistanceMethod.CLOSEST_OBJECT_TO_POINTER)
	check_box_center_of_selection.set_pressed_no_signal(in_new_method == CreateObjectParameters.CreateDistanceMethod.CENTER_OF_SELECTION)
	check_box_fixed_distance.set_pressed_no_signal(in_new_method == CreateObjectParameters.CreateDistanceMethod.FIXED_DISTANCE_TO_CAMERA)


func _on_creation_distance_from_camera_factor_changed(_in_factor: float) -> void:
	var context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	if creation_distance.value == context.create_object_parameters.drop_distance:
		return
	creation_distance.value = context.create_object_parameters.drop_distance


func _on_snap_to_shape_surface_changed(in_enabled: bool) -> void:
	snap_to_shape_surface.set_pressed_no_signal(in_enabled)
