class_name DynamicContextDocker extends WorkspaceDocker


const UNIQUE_DOCKER_NAME: StringName = &"__DynamicContextDocker__"
const _DYNAMIC_CONTEXT_CONTROLS: Dictionary = {
	&"Preview":
		{
			header = false,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/no_selection_preview.tscn",
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/3d_preview.tscn",
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/single_atom_preview.tscn"
			]
		},
	&"Apply Atoms to Shapes":
		{
			header = true,
			scroll = false,
			collapse = true,
			start_collapsed = true,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/apply_atoms_to_shape.tscn"
			]
		},
	&"Change Atom Type":
		{
			header = true,
			scroll = false,
			collapse = true,
			start_collapsed = true,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/change_atom_type.tscn"
			]
		},
	&"Change Bond Type":
		{
			header = true,
			scroll = false,
			collapse = true,
			start_collapsed = true,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/change_bond_type.tscn"
			]
		},
	&"Find Visible Atoms by Type":
		{
			header = true,
			scroll = false,
			collapse = true,
			start_collapsed = true,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/find_atoms_by_type.tscn"
			]
		},
	&"Lock/Unlock Atoms":
		{
			header = true,
			scroll = false,
			collapse = true,
			start_collapsed = true,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/lock_atoms.tscn"
			]
		},
	&"Override Default Colors":
		{
			header = true,
			scroll = false,
			collapse = true,
			start_collapsed = true,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/override_default_colors.tscn"
			]
		},
	&"Edit Motors Parameters":
		{
			header = true,
			scroll = false, # will use Tree control scroll instead
			collapse = false,
			start_collapsed = false,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/edit_virtual_motor_parameters.tscn"
			]
		},
	&"Edit Springs Parameters":
		{
			header = true,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/edit_virtual_spring_parameters.tscn"
			]
		},
	&"Connect Object to Motor":
		{
			header = true,
			scroll = false, # will use Tree control scroll instead
			collapse = false,
			start_collapsed = false,
			stretch_ratio = 0.0,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/connect_motors_to_groups_panel.tscn"
			]
		},
	&"Selection Information":
		{
			header = true,
			scroll = false, # will use Tree control scroll instead
			collapse = true,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/selection_info.tscn"
			]
		}
}


var _workspace_context: WorkspaceContext = null


func _ready() -> void:
	super()
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	if is_instance_valid(_workspace_context):
		_workspace_context.create_object_parameters.set_create_mode_enabled(false)


func should_show(_in_workspace_context: WorkspaceContext) -> bool:
	return true


func _update_internal(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context
	super(in_workspace_context)


func _update_docker_visibility() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(MolecularEditorContext.get_current_workspace())
	if is_instance_valid(workspace_context):
		_update_visibility(should_show(workspace_context))


func get_unique_docker_name() -> StringName:
	return UNIQUE_DOCKER_NAME


func get_default_docker_area() -> int:
	return DOCK_AREA_DEFAULT


func get_content_template() -> Dictionary:
	return _DYNAMIC_CONTEXT_CONTROLS


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
	if !context.structure_about_to_remove.is_connected(_on_structure_removed):
		context.structure_about_to_remove.connect(_on_structure_removed)
	_on_current_structure_context_changed(context.get_current_structure_context())


func _on_current_structure_context_changed(in_structure_context: StructureContext) -> void:
	if in_structure_context == null:
		return
	if !in_structure_context.selection_changed.is_connected(_on_structure_context_selection_changed):
		in_structure_context.selection_changed.connect(_on_structure_context_selection_changed)


func _on_structure_context_selection_changed() -> void:
	ScriptUtils.call_deferred_once(_update_docker_visibility)


func _on_structure_removed(_in_nano_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_update_docker_visibility)
