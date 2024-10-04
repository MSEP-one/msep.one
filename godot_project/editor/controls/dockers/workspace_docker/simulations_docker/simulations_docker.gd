class_name SimulationsDocker extends WorkspaceDocker

const UNIQUE_DOCKER_NAME: StringName = &"__SimulationsDocker__"
const _DYNAMIC_CONTEXT_CONTROLS: Dictionary = {
	&"Type":
		{
			header = false,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/simulation_type_picker.tscn"
			]
		},
	&"Relax":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/relax_tools_panel.tscn"
			]
		},
	&"Molecular Dynamics Simulation":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/simulation_tools_panel.tscn"
			]
		},
	&"Validate Model":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/validate_bonds_panel.tscn"
			]
		},
	&"Settings":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker_controls/simulation_settings_panel.tscn"
			]
		},
}


var _weak_workspace_context: WeakRef = weakref(null)
func should_show(_in_workspace_context: WorkspaceContext) -> bool:
	return true


func _update_internal(in_workspace_context: WorkspaceContext) -> void:
	_weak_workspace_context = weakref(in_workspace_context)
	_ensure_workspace_initialized(in_workspace_context)
	super(in_workspace_context)


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if in_workspace_context == null:
		return
	var create_object_parameters: CreateObjectParameters = \
			in_workspace_context.create_object_parameters
	assert(create_object_parameters != null, "Workspace Context should always have CreateObjectParameters component")
	if !create_object_parameters.simulation_type_changed.is_connected(_on_create_object_parameters_simulation_type_changed):
		create_object_parameters.simulation_type_changed.connect(_on_create_object_parameters_simulation_type_changed)


func _on_create_object_parameters_simulation_type_changed(_in_new_type: CreateObjectParameters.SimulationType) -> void:
	var context := _weak_workspace_context.get_ref() as WorkspaceContext
	if context == null:
		return
	# This will flush the state of any running simulation and terminate it
	context.apply_simulation_if_running()
	# Update controls visibility
	_update_visibility(should_show(context))


func get_unique_docker_name() -> StringName:
	return UNIQUE_DOCKER_NAME


func get_default_docker_area() -> int:
	return DOCK_AREA_DEFAULT


func get_content_template() -> Dictionary:
	return _DYNAMIC_CONTEXT_CONTROLS


func _get_category_container() -> Container:
	return %CategoryContainer


func _on_workspace_activated(in_workspace: Workspace) -> void:
	super._on_workspace_activated(in_workspace)
	var context: WorkspaceContext = MolecularEditorContext.get_workspace_context(in_workspace)
	if !context.current_structure_context_changed.is_connected(_on_current_structure_context_changed):
		context.current_structure_context_changed.connect(_on_current_structure_context_changed)
	_on_current_structure_context_changed(context.get_current_structure_context())


func _on_current_structure_context_changed(in_structure_context: StructureContext) -> void:
	if in_structure_context == null:
		return
	if !in_structure_context.selection_changed.is_connected(_on_structure_context_selection_changed):
		in_structure_context.selection_changed.connect(_on_structure_context_selection_changed)


func _on_structure_context_selection_changed() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	if is_instance_valid(workspace_context):
		_update_visibility(should_show(workspace_context))
