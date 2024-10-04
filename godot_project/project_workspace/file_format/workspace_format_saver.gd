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
	out_workspace.msep_version_history[timestamp] = _get_msep_version()


func _update_simulation_forcefield_hashes(out_workspace: Workspace) -> void:
	out_workspace.simulation_settings_forcefield_md5 = OpenMMUtils.hash_forcefield(
		out_workspace.simulation_settings_forcefield
	)
	out_workspace.simulation_settings_msep_extensions_md5 = OpenMMUtils.hash_forcefield_extension(
		out_workspace.simulation_settings_forcefield_extension
	)


func _get_msep_version() -> String:
	var msep_version: String = _try_get_msep_version_from_git()
	if msep_version == "":
		msep_version = _try_get_msep_version_from_project_settings()
	if msep_version == "":
		push_warning("Could not identify the version of MSEP editor")
		msep_version = "unknown"
	# append godot's version
	var godot_version: Dictionary = Engine.get_version_info()
	godot_version.features = _collect_godot_features()
	var godot_version_string: String = "+Godot[{features}]{string}".format(godot_version)
	return msep_version + godot_version_string


func _collect_godot_features() -> String:
	var godot_features: PackedStringArray = []
	var all_features: Array[String] = [
		"windows", "linux", "macos", "universal",
		"debug", "release", "editor", "template_debug", "template_release"]
	for feature: String in all_features:
		if OS.has_feature(feature):
			godot_features.push_back(feature)
	# include rendering device
	var rendering_device: RenderingDevice = RenderingServer.get_rendering_device()
	godot_features.push_back(rendering_device.get_device_name().replace(" ", "-"))
	godot_features.push_back(rendering_device.get_device_vendor_name().replace(" ", "-"))
	return ",".join(godot_features)

func _try_get_msep_version_from_git() -> String:
	var git_out: Array = []
	var latest_head_hash: String = ""
	var branch: String = ""
	var commit_date: String = ""
	# The “$ git rev-parse” command can be utilized for getting the SHA hashes of branches or HEAD.
	#+In this case we run it as a shell command to get the hash from the captured stdout
	if OS.execute("git", ["rev-parse", "HEAD"], git_out) == OK:
		assert(git_out.size() > 0)
		latest_head_hash = git_out[0]
	else:
		return ""
	git_out = []
	# The “$ git symbolic-ref --short HEAD” command can collect the name of the current branch
	if OS.execute("git", ["symbolic-ref", "--short", "HEAD"], git_out) == OK:
		assert(git_out.size() > 0)
		branch = git_out[0].replace("\n", "") # This output comes with an eol
	git_out = []
	# The $ git log -1 --format="%at" | xargs -I{} date -d @{} +%Y-%m-%d
	# command can collect the date of the last commit made
	if OS.execute("git", ["log", "-1", "--format='%at'"], git_out) == OK:
		assert(git_out.size() > 0)
		var unix_date: int = int(git_out[0])
		commit_date = Time.get_date_string_from_unix_time(unix_date)
	var version: String = latest_head_hash.left(10)
	if not commit_date.is_empty():
		version = commit_date + "." + version
	if not branch.is_empty():
		version = version + "(" + branch + ")"
	return version


func _try_get_msep_version_from_project_settings() -> String:
	const EXPORT_DATE_SETTING_NAME: StringName = &"application/config/export_date"
	const EXPORT_COMMIT_SETTING_NAME: StringName = &"application/config/export_commit"
	
	var export_date: String = ProjectSettings.get_setting(EXPORT_DATE_SETTING_NAME, "")
	var export_commit: String = ProjectSettings.get_setting(EXPORT_COMMIT_SETTING_NAME, "")
	
	if (export_date+export_commit).is_empty():
		return ""
	return export_date + "." + export_commit.left(10)
