extends Object
class_name Editor_Utils


static func get_editor() -> MolecularEditor:
	return Engine.get_main_loop().get_first_node_in_group(&"__MSEP_EDITOR__")


static func process_quit_request(in_event: InputEvent, in_called_from_node: Node) -> bool:
	if in_event.is_action_pressed(&"quit", false, true):
		in_called_from_node.get_viewport().set_input_as_handled()
		var focused_window: Window = in_called_from_node.get_last_exclusive_window()
		while focused_window != Engine.get_main_loop().root:
			if not focused_window.visible:
				focused_window = focused_window.get_parent().get_last_exclusive_window()
				continue
			focused_window.hide()
		Editor_Utils.get_editor().notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		return true
	return false


static func get_structure_thumbnail(_in_nano_structure: NanoStructure) -> Texture2D:
	# TODO: generate or load thumbnail
	return preload("uid://dsnljh3opu7ae")


static func get_msep_version(in_include_features: bool = true) -> String:
	var msep_version: String = _try_get_msep_version_from_git()
	if msep_version == "":
		msep_version = _try_get_msep_version_from_project_settings()
	if msep_version == "":
		push_warning("Could not identify the version of MSEP editor")
		msep_version = "unknown"
	if in_include_features:
		# append godot's version
		var godot_version: Dictionary = Engine.get_version_info()
		godot_version.features = _collect_godot_features()
		var godot_version_string: String = "+Godot[{features}]{string}".format(godot_version)
		return msep_version + godot_version_string
	return msep_version


static func _collect_godot_features() -> String:
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


static func _try_get_msep_version_from_git() -> String:
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


static func _try_get_msep_version_from_project_settings() -> String:
	const EXPORT_DATE_SETTING_NAME: StringName = &"application/config/export_date"
	const EXPORT_COMMIT_SETTING_NAME: StringName = &"application/config/export_commit"
	
	var export_date: String = ProjectSettings.get_setting(EXPORT_DATE_SETTING_NAME, "")
	var export_commit: String = ProjectSettings.get_setting(EXPORT_COMMIT_SETTING_NAME, "")
	
	if (export_date+export_commit).is_empty():
		return ""
	return export_date + "." + export_commit.left(10)
