extends DynamicContextControl


var _weak_create_object_parameters: WeakRef = weakref(null)

@onready var _option_button: OptionButton = %OptionButton


func _ready() -> void:
	_option_button.get_popup().id_pressed.connect(_on_option_button_id_pressed)


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


func _on_create_object_parameters_create_mode_changed(in_new_create_mode: int) -> void:
	set_create_mode_type(in_new_create_mode)


func _on_option_button_id_pressed(id: int) -> void:
	var create_object_parameters: CreateObjectParameters = _weak_create_object_parameters.get_ref() as CreateObjectParameters
	if create_object_parameters != null:
		create_object_parameters.set_create_mode_type(id as CreateObjectParameters.CreateModeType)
