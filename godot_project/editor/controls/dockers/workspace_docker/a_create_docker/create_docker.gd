class_name CreateDocker extends WorkspaceDocker


const UNIQUE_DOCKER_NAME: StringName = &"__CreateDocker__"
const _CREATE_OBJECT_CONTROLS: Dictionary = {
	&"CreateMode":
		{
			header = false,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/a_create_docker/controls/create_mode_picker.tscn"
			]
		},
	&"Atoms and Bonds Parameters":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/a_create_docker/create_atoms_and_bonds_panel.tscn"
			]
		},
	&"Auto-Create Bonds":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/a_create_docker/auto_create_bonds_panel.tscn"
			]
		},
	&"Reference Shape Parameters":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/a_create_docker/create_shape_panel.tscn"
			]
		},
	&"Small Molecules":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/a_create_docker/create_fragment_panel.tscn"
			]
		},
	&"Virtual Motors":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/a_create_docker/create_virtual_motor_panel.tscn"
			]
		},
	&"Particle Emitters":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/a_create_docker/create_particle_emitter_panel.tscn"
			]
		},
	&"Virtual Springs":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/a_create_docker/create_virtual_spring_panel.tscn"
			]
		},
	&"Creation Distance":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/a_create_docker/creation_distance_panel.tscn"
			]
		}
}


var _workspace_context: WorkspaceContext = null


func should_show(_in_workspace_context: WorkspaceContext) -> bool:
	return true


func _update_internal(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context
	_ensure_workspace_initialized(in_workspace_context)
	super(in_workspace_context)


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if in_workspace_context == null:
		return
	var create_object_parameters: CreateObjectParameters = \
			in_workspace_context.create_object_parameters
	assert(create_object_parameters != null, "Workspace Context should always have CreateObjectParameters component")
	if !create_object_parameters.create_mode_type_changed.is_connected(_on_create_object_parameters_create_mode_changed):
		create_object_parameters.create_mode_type_changed.connect(_on_create_object_parameters_create_mode_changed)


func _on_create_object_parameters_create_mode_changed(_in_create_mode: int) -> void:
	# Update controls visibility
	_update_visibility(should_show(_workspace_context))


func add_control_to_category(in_category_id: StringName, in_control: DynamicContextControl) -> bool:
	var success: bool = super.add_control_to_category(in_category_id, in_control)
	if success && is_instance_valid(_workspace_context):
		var category: Category = _categories[in_category_id]
		var category_control: Control = category.category_control
		var container: VBoxContainer = category.container
		var category_visible: bool = false
		in_control.visible = in_control.should_show(_workspace_context)
		for ctrl in container.get_children():
			var control: Control = ctrl as Control
			if is_instance_valid(control):
				category_visible = category_visible || control.visible
		category_control.visible = category_visible
	return success


func get_unique_docker_name() -> StringName:
	return UNIQUE_DOCKER_NAME


func get_default_docker_area() -> int:
	return DOCK_AREA_DEFAULT


func get_content_template() -> Dictionary:
	return _CREATE_OBJECT_CONTROLS


func _get_category_container() -> Container:
	return %CategoryContainer

# region: Internal
# IMPORTANT: Dockers are added and removed from the tree when should_show
# is called. This prevents to use signals connections because they only fire
# when the node is in the tree.
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
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(MolecularEditorContext.get_current_workspace())
	if is_instance_valid(workspace_context):
		_update_visibility(should_show(workspace_context))

