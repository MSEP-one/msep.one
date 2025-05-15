extends DynamicContextControl


var _weak_create_object_parameters: WeakRef = weakref(null)

@onready var _option_button: OptionButton = %OptionButton


func _ready() -> void:
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	
	_option_button.get_popup().id_pressed.connect(_on_option_button_id_pressed)


func _on_feature_flag_toggled(in_path: String, _in_new_value: bool) -> void:
	if in_path in [FeatureFlagManager.FEATURE_FLAG_VIRTUAL_MOTORS, FeatureFlagManager.FEATURE_FLAG_PARTICLE_EMITTERS, FeatureFlagManager.FEATURE_FLAG_VIRTUAL_SPRINGS]:
		_update_visibility_of_options()


func _update_visibility_of_options() -> void:
	var can_create_virtual_motors: bool = FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_VIRTUAL_MOTORS)
	var can_create_particle_emitters: bool = FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_PARTICLE_EMITTERS)
	var can_create_virtual_springs: bool = FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_VIRTUAL_SPRINGS)
	var virtual_motors_idx: int = _option_button.get_popup().get_item_index(CreateObjectParameters.CreateModeType.CREATE_VIRTUAL_MOTORS)
	var particle_emitters_idx: int = _option_button.get_popup().get_item_index(CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS)
	var virtual_springs_idx: int = _option_button.get_popup().get_item_index(CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS)
	var motors_item_exists: bool = virtual_motors_idx != -1
	var emitters_item_exists: bool = particle_emitters_idx != -1
	var spring_item_exists: bool = virtual_springs_idx != -1
	if can_create_virtual_motors == motors_item_exists \
			and can_create_particle_emitters == emitters_item_exists \
			and can_create_virtual_springs == spring_item_exists:
		# Nothing to do here
		return
	# 1. Remove all existing items
	if spring_item_exists:
		# Springs first since it is always added last
		_option_button.get_popup().remove_item(virtual_springs_idx)
	if emitters_item_exists:
		_option_button.get_popup().remove_item(particle_emitters_idx)
	if motors_item_exists:
		_option_button.get_popup().remove_item(virtual_motors_idx)
	# 2. Add any desired option
	if can_create_virtual_motors:
		_option_button.get_popup().add_radio_check_item(tr("Virtual Motors"), CreateObjectParameters.CreateModeType.CREATE_VIRTUAL_MOTORS)
	if can_create_particle_emitters:
		_option_button.get_popup().add_radio_check_item(tr("Particle Emitters"), CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS)
	if can_create_virtual_springs:
		_option_button.get_popup().add_radio_check_item(tr("Anchors and Springs"), CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS)
	# 3. Change mode if necesary
	if _option_button.selected == CreateObjectParameters.CreateModeType.CREATE_VIRTUAL_MOTORS and not can_create_virtual_motors:
		_on_option_button_id_pressed(CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS)
	elif _option_button.selected == CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS and not can_create_particle_emitters:
		_on_option_button_id_pressed(CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS)
	elif _option_button.selected == CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS and not can_create_virtual_springs:
		_on_option_button_id_pressed(CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS)
	var create_object_parameters: CreateObjectParameters = _weak_create_object_parameters.get_ref() as CreateObjectParameters
	_option_button.select(-1) # This ensures RadioButton is updated
	set_create_mode_type(create_object_parameters.get_create_mode_type())


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(in_workspace_context)
	return true


func set_create_mode_type(in_create_mode: int) -> void:
	if !is_instance_valid(_option_button):
		await ready
	var idx: int = _option_button.get_popup().get_item_index(in_create_mode)
	_option_button.selected = idx


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if in_workspace_context == null:
		return
	var create_object_parameters: CreateObjectParameters = in_workspace_context.create_object_parameters as CreateObjectParameters
	assert(create_object_parameters != null, "Workspace Context should always have CreateObjectParameters component")
	_weak_create_object_parameters = weakref(create_object_parameters)
	if !create_object_parameters.create_mode_type_changed.is_connected(_on_create_object_parameters_create_mode_changed):
		create_object_parameters.create_mode_type_changed.connect(_on_create_object_parameters_create_mode_changed)
	_update_visibility_of_options()


func _on_create_object_parameters_create_mode_changed(in_new_create_mode: int) -> void:
	set_create_mode_type(in_new_create_mode)


func _on_option_button_id_pressed(id: int) -> void:
	var create_object_parameters: CreateObjectParameters = _weak_create_object_parameters.get_ref() as CreateObjectParameters
	if create_object_parameters != null:
		create_object_parameters.set_create_mode_type(id as CreateObjectParameters.CreateModeType)
