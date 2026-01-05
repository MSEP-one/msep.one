extends DynamicContextControl

@onready var _info_label: InfoLabel = %InfoLabel

func _ready() -> void:
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	_on_feature_flag_toggled(
		FeatureFlagManager.FEATURE_FLAGS_DNA_CHAIN_CAN_HAVE_CHILDREN,
		FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_DNA_CHAIN_CAN_HAVE_CHILDREN)
	)

func should_show(in_workspace_context: WorkspaceContext) -> bool:
	match in_workspace_context.create_object_parameters.get_create_mode_type():
		CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS, \
		CreateObjectParameters.CreateModeType.CREATE_FRAGMENT, \
		CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS:
			if not in_workspace_context.get_current_structure_context().nano_structure.can_create_and_delete_atoms():
				return true
		CreateObjectParameters.CreateModeType.CREATE_SHAPES, \
		CreateObjectParameters.CreateModeType.CREATE_DNA_CHAIN, \
		CreateObjectParameters.CreateModeType.CREATE_VIRTUAL_MOTORS, \
		CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS:
			if not in_workspace_context.get_current_structure_context().nano_structure.can_contain_child_structure():
				return true
	return false

func _on_feature_flag_toggled(in_path: String, in_new_value: bool) -> void:
	if in_path == FeatureFlagManager.FEATURE_FLAGS_DNA_CHAIN_CAN_HAVE_CHILDREN:
		if in_new_value:
			_info_label.message = tr(&"Immutable structures cannot add, remove, or modify atoms or bonds")
		else:
			_info_label.message = tr(&"Immutable structures cannot add, remove, or modify atoms, bonds, or child objects")
			
