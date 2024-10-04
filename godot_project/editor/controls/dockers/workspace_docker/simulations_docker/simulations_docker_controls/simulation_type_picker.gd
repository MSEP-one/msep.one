extends DynamicContextControl


@onready var option_button: OptionButton = $"Main Container/OptionButton"


var _weak_create_object_parameters: WeakRef = weakref(null)

func _ready() -> void:
	option_button.get_popup().id_pressed.connect(_on_option_button_id_pressed)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(in_workspace_context)
	return true


func set_simulation_type(in_simulation_type: int) -> void:
	if !is_instance_valid(option_button):
		await ready
	var idx: int = option_button.get_popup().get_item_index(in_simulation_type)
	option_button.selected = idx


func _on_option_button_id_pressed(id: int) -> void:
	var create_object_parameters: CreateObjectParameters = _weak_create_object_parameters.get_ref() as CreateObjectParameters
	if create_object_parameters != null:
		create_object_parameters.set_simulation_type(id as CreateObjectParameters.SimulationType)


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if in_workspace_context == null:
		return
	var create_object_parameters: CreateObjectParameters = in_workspace_context.create_object_parameters as CreateObjectParameters
	assert(create_object_parameters != null, "Workspace Context should always have CreateObjectParameters component")
	_weak_create_object_parameters = weakref(create_object_parameters)
	set_simulation_type(create_object_parameters.get_simulation_type())
	if !create_object_parameters.simulation_type_changed.is_connected(_on_create_object_parameters_simulation_type_changed):
		create_object_parameters.simulation_type_changed.connect(_on_create_object_parameters_simulation_type_changed)


func _on_create_object_parameters_simulation_type_changed(in_new_simulation_type: int) -> void:
	set_simulation_type(in_new_simulation_type)

