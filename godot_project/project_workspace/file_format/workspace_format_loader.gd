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
	var tmp_path: String = OS.get_cache_dir().path_join(path.get_file().get_basename() + ".tres")
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
	return workspace
