class_name WorkspaceSettingsDocker extends WorkspaceDocker

const UNIQUE_DOCKER_NAME: StringName = &"__WorkspaceSettingsDocker__"
const _WORKSPACE_SETTINGS_CONTROLS: Dictionary = {
	&"General Settings":
		{
			header = true,
			scroll = false,
			collapse = true,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/controls/general_settings/general_settings.tscn"
			]
		},
	&"Representation Settings":
		{
			header = true,
			scroll = false,
			collapse = true,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/controls/atom_size_settings/atom_size_settings.tscn",
				"res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/controls/visibility_settings/visibility_settings.tscn",
				"res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/controls/theme_settings/theme_settings.tscn"
			]
		},
	&"MSEP Settings":
		{
			header = true,
			scroll = false,
			collapse = true,
			start_collapsed = false,
			controls = [
				"res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/controls/editor_settings/audio_settings.tscn",
				"res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/controls/editor_settings/camera_settings.tscn",
				"res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/controls/editor_settings/color_settings.tscn",
				"res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/controls/editor_settings/ui_settings.tscn",
				"res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/controls/editor_settings/performance_settings.tscn",
				"res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/controls/editor_settings/openmm_settings.tscn",
			]
		}
}

func should_show(_in_workspace_context: WorkspaceContext) -> bool:
	return true


func get_unique_docker_name() -> StringName:
	return UNIQUE_DOCKER_NAME


func get_default_docker_area() -> int:
	return DOCK_AREA_DEFAULT


func get_content_template() -> Dictionary:
	return _WORKSPACE_SETTINGS_CONTROLS


func _get_category_container() -> Container:
	return %CategoryContainer

