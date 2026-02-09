extends ResourceFormatLoader

const _RESOURCE_RENAMES_DURING_DEVELOPMENT: Dictionary = {
	"\"res://project_workspace/structs/nano_atom.gd\"": "\"res://project_workspace/structs/nano_atom_legacy.gd\""
}

var _application_is_editor_build: bool = OS.has_feature("editor")

func _get_recognized_extensions() -> PackedStringArray:
	var extensions := PackedStringArray()
	extensions.push_back("msep1")
	return extensions


func _get_resource_type(path: String) -> String:
	if path.get_extension() == "msep1":
		return "Workspace"
	return ""


func _handles_type(typename: StringName) -> bool:
	return typename == &"Resource"


func _load(path: String, _original_path: String, _use_sub_threads: bool, cache_mode: int) -> Workspace:
	var tmp_path: String = OS.get_temp_dir().path_join(path.get_file().get_basename() + ".tres")
	var d: DirAccess = DirAccess.open("user://")
	var workspace: Workspace = null
	var file_content: String = FileAccess.get_file_as_string(path)
	if _application_is_editor_build:
		# Perform some conversion hacks for backward compatibility during development
		for old_resource_path: String in _RESOURCE_RENAMES_DURING_DEVELOPMENT.keys():
			var new_resource_path: String = _RESOURCE_RENAMES_DURING_DEVELOPMENT[old_resource_path]
			file_content = file_content.replace(old_resource_path, new_resource_path)
	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file != null:
		tmp_file.store_string(file_content)
		tmp_file.flush()
		tmp_file.close()
		workspace = ResourceLoader.load(tmp_path, "", cache_mode) as Workspace
		workspace.post_load()
		if workspace != null:
			workspace.take_over_path(path)
	d.remove(tmp_path)
	if workspace._file_format_version < Workspace.get_most_recent_file_format_version():
		push_warning("This workspace file was written with an older file format version: ",
			Workspace.FileFormatVersion.find_key(workspace._file_format_version))
	elif workspace._file_format_version > Workspace.get_most_recent_file_format_version():
		push_error("This workspace file was written with an newer file format version: ",
			workspace._file_format_version)
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_DNA_BUILDER) == false:
		var need_to_enable_flag: bool = false
		var need_dna_as_group: bool = false
		for obj: NanoStructure in workspace.get_structures():
			if obj is DnaStructure:
				need_to_enable_flag = true
				if obj.int_guid == workspace.active_structure_int_guid:
					need_dna_as_group = true
					break
		var enabled_flags: Array[String]
		if need_to_enable_flag:
			FeatureFlagManager.set_flag_value(FeatureFlagManager.FEATURE_FLAGS_DNA_BUILDER, true)
			enabled_flags.append(FeatureFlagManager.FEATURE_FLAGS_DNA_BUILDER)
		if need_dna_as_group:
			FeatureFlagManager.set_flag_value(FeatureFlagManager.FEATURE_FLAGS_DNA_CHAIN_AS_GROUP_OF_ATOMS, true)
			FeatureFlagManager.set_flag_value(FeatureFlagManager.FEATURE_FLAGS_DNA_CHAIN_CAN_HAVE_CHILDREN, true)
			enabled_flags.append(FeatureFlagManager.FEATURE_FLAGS_DNA_CHAIN_AS_GROUP_OF_ATOMS)
			enabled_flags.append(FeatureFlagManager.FEATURE_FLAGS_DNA_CHAIN_CAN_HAVE_CHILDREN)
		if OS.is_debug_build() and OS.has_feature("editor") and not enabled_flags.is_empty():
			enabled_flags.push_front(&"The following feature flag(s) was enabled to support this file:")
			DisplayServer.dialog_show.call_deferred("INFO", "\n· ".join(enabled_flags), ["OK"], Callable())
	return workspace
