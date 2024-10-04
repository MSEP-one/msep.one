class_name GroupsDocker extends WorkspaceDocker


const UNIQUE_DOCKER_NAME: StringName = &"__GroupsDocker__"
const _DYNAMIC_CONTEXT_CONTROLS: Dictionary = {
	&"Groups":
		{
			header = false,
			scroll = false,
			collapse = false,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/groups_docker/groups_docker_controls/nano_groups_list.tscn"
			]
		},
	&"Assign Group to Selection":
		{
			header = true,
			scroll = false,
			collapse = true,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/groups_docker/groups_docker_controls/assign_group_panel.tscn"
			]
		},
}


# OVERRIDE
func should_show(_in_workspace_context: WorkspaceContext) -> bool:
	return true


# OVERRIDE
func get_unique_docker_name() -> StringName:
	return UNIQUE_DOCKER_NAME


# OVERRIDE
func get_default_docker_area() -> int:
	return DOCK_AREA_DEFAULT


# OVERRIDE
func get_content_template() -> Dictionary:
	return _DYNAMIC_CONTEXT_CONTROLS


# OVERRIDE
func _get_category_container() -> Container:
	return %CategoryContainer
