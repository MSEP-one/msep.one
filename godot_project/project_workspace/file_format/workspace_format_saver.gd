extends ResourceFormatSaver

func _recognize(resource: Resource) -> bool:
	return resource is Workspace

func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	var extensions := PackedStringArray()
	if resource is Workspace:
		extensions.push_back("msep1")
	return extensions

func _save(resource: Resource, path: String, flags: int) -> Error:
	_update_msep_vertsion_history(resource)
	_update_simulation_forcefield_hashes(resource)
	var tmp_path: String = path + ".tres"
	var result: Error = ResourceSaver.save(resource, tmp_path, flags)
	if result == OK:
		resource.suggested_path = ""
		var d: DirAccess = DirAccess.open("user://")
		result = d.rename(tmp_path, path)
	return result


func _update_msep_vertsion_history(out_workspace: Workspace) -> void:
	var timestamp: String = Time.get_datetime_string_from_system()
	out_workspace.msep_version_history[timestamp] = Editor_Utils.get_msep_version()


func _update_simulation_forcefield_hashes(out_workspace: Workspace) -> void:
	out_workspace.simulation_settings_forcefield_md5 = OpenMMUtils.hash_forcefield(
		out_workspace.simulation_settings_forcefield
	)
	out_workspace.simulation_settings_msep_extensions_md5 = OpenMMUtils.hash_forcefield_extension(
		out_workspace.simulation_settings_forcefield_extension
	)
