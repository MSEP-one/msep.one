class_name OpenMMUtils extends Node

const _EXTERNAL_PROCESS_SCRIPTS_UNIX: Array[String] = [
	"res://python/launch_server.sh",
]
const _EXTERNAL_PROCESS_SCRIPTS_ALL: Array[String] = [
	"res://python/scripts/openmm_server.py",
	"res://python/scripts/patches/__init__.py",
	"res://python/scripts/patches/patch_frozen_molecule.py",
	"res://python/scripts/offxml_extensions/msep.one_extension-0.0.1.offxml",
	"res://python/scripts/offxml/openff-2.1.0.offxml",
]
const MSEP_EXTENSIONS_FORCEFIELD: String = "msep.one_extension-0.0.1.offxml"
const DEFAULT_FORCEFIELD: String = "openff-2.1.0.offxml"
const DEFAULT_FORCEFIELD_EXTENSION: String = MSEP_EXTENSIONS_FORCEFIELD

var msep_environment_path: String = ProjectSettings.globalize_path("user://msep.one/")
signal environment_installed()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func get_server_script_absolute_path() -> String:
	var script_path: String = _EXTERNAL_PROCESS_SCRIPTS_ALL[0]
	return globalize_path(script_path.replace("res://", "user://"))


func get_default_forcefield_filename() -> String:
	return DEFAULT_FORCEFIELD


func get_msep_extensions_forcefield_filename() -> String:
	return MSEP_EXTENSIONS_FORCEFIELD


## Returns an md5 of the contents of the forcefield file or empty if doesn't exists
static func hash_forcefield(in_forcefield_filename: String) -> String:
	if in_forcefield_filename.is_empty():
		return ""
	return FileAccess.get_md5(globalize_path("user://python/scripts/offxml/" + in_forcefield_filename))


## Returns an md5 of the contents of the forcefield file or empty if doesn't exists
static func hash_forcefield_extension(in_extension_filename: String) -> String:
	if in_extension_filename.is_empty():
		return ""
	return FileAccess.get_md5(globalize_path("user://python/scripts/offxml_extensions/" + in_extension_filename))


## Returns a list of all forcefields files included by default with MSEP
func get_all_forcefield_filenames() -> Array:
	var all: Array = []
	for path in _EXTERNAL_PROCESS_SCRIPTS_ALL:
		if path.begins_with("res://python/scripts/offxml/"):
			all.push_back(path.get_file())
	return all


## Returns a list of all forcefields extension files included by default with MSEP
## Those files are additional parametrizations to use on top of the main forcefield file to support
## special case scenarios
func get_all_forcefield_extensions() -> Array:
	var all: Array = []
	all.push_back("") # Disabled extensions
	for path in _EXTERNAL_PROCESS_SCRIPTS_ALL:
		if path.begins_with("res://python/scripts/offxml_extensions/"):
			all.push_back(path.get_file())
	return all


## Return forcefields files added to the user folder by the user. Use under your own risk
func get_user_defined_forcefields() -> Array:
	return _get_files_not_in_list("user://python/scripts/offxml/", get_all_forcefield_filenames())


## Returns true when the specified file was added by a user and not by MSEP
func is_user_defined_forcefield(in_forcefield_filename: String) -> bool:
	return not get_all_forcefield_filenames().has(in_forcefield_filename)


## Return forcefields extension files added to the user folder by the user. Use under your own risk
func get_user_defined_forcefield_extensions() -> Array:
	return _get_files_not_in_list("user://python/scripts/offxml_extensions/", get_all_forcefield_extensions())


## Returns true when the specified file was added by a user and not by MSEP
func is_user_defined_extension(in_forcefield_extension_filename: String) -> bool:
	return not get_all_forcefield_extensions().has(in_forcefield_extension_filename)


func _get_files_not_in_list(in_folder: String, in_blacklist: Array) -> Array:
	var offxml_folder: String = globalize_path(in_folder)
	var user_defined: Array = []
	var dir: DirAccess = DirAccess.open(offxml_folder)
	if is_instance_valid(dir):
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension() == "offxml":
				if not in_blacklist.has(file_name):
					user_defined.push_back(file_name)
			file_name = dir.get_next()
	else:
		push_error("Could not open folder ", offxml_folder)
	return user_defined


func make_forcefield_descriptions(forcefield_files: Array) -> Dictionary: 
	# {    filename<String>  =  description<String>    }
	var all_descriptions: Dictionary = { }
	for filename: String in forcefield_files:
		var description: String = filename
		description = description.replace(".offxml", "") # remove extension
		description = description.replace("openff", "OpenFF") # Capitalize OpenFF
		description = description.replace("msep", "MSEP") # Capitalize MSEP
		description = description.replace("-", " ") # Change - to spaces
		description = description.replace("_", " ") # Change _ to spaces
		if description.is_empty():
			# Disabled extensions uses an empty filename entry
			description = tr(&"None")
		all_descriptions[filename] = description
	return all_descriptions


func is_modification_of_server_script_allowed() -> bool:
	return MolecularEditorContext.msep_editor_settings.openmm_server_allow_modified_script


func is_custom_server_script_in_use() -> bool:
	if not is_modification_of_server_script_allowed():
		return false
	var original_path: String = _EXTERNAL_PROCESS_SCRIPTS_ALL[0]
	var dest_path: String = get_server_script_absolute_path()
	if not FileAccess.file_exists(dest_path):
		return false
	var original_content: PackedByteArray = FileAccess.get_file_as_bytes(original_path)
	var custom_content: PackedByteArray = FileAccess.get_file_as_bytes(dest_path)
	return original_content != custom_content


# This is an integrity check that looks for files necesary to run the processes
# It is used to detect if non resource files are missing in the export whitelist
func find_missing_files() -> Array[String]:
	var missing_files: Array[String] = []
	var platform: String = OS.get_name().to_lower()
	var arch: String = "x86_64"
	# Detect platform
	if platform == "macos":
		if OS.has_feature("arm64"):
			arch= "arm64"
	var filename: String = "env_%s_%s.tar.gz" % [platform, arch]
	var files_to_check: Array[String] = [
		"res://python/conda/" + filename
	]
	files_to_check.append_array(_get_additional_scripts_list())
	for file in files_to_check:
		if !FileAccess.file_exists(file):
			missing_files.append(file)
	return missing_files


func install_environment() -> void:
	assert(needs_install_or_update(), "Environment is already installed, this is not necesary")
	var env_md5_path: String = msep_environment_path.path_join("environment_md5")
	var platform: String = OS.get_name().to_lower()
	var arch: String = "x86_64"
	# Detect platform
	if platform == "macos":
		if OS.has_feature("arm64"):
			arch= "arm64"
	var filename: String = "env_%s_%s.tar.gz" % [platform, arch]
	# 1. Create the directory to extract the environment
	var dir: DirAccess = DirAccess.open("user://")
	if !dir.dir_exists(msep_environment_path):
		DirAccess.make_dir_recursive_absolute(msep_environment_path)
	var pre_pck_filepath: String = "res://python/conda/%s" % filename
	var pck_filepath: String = ProjectSettings.globalize_path("user://%s" % filename)
	# 2. Copy the packed environment, to unzip it
	_install_file_from_res(pre_pck_filepath, pck_filepath, true, false)
	var args: PackedStringArray = ["-xf",  pck_filepath, "-C", msep_environment_path]
	var stdout: Array = []
	var result: int = OS.execute("tar", args, stdout, true)
	if result != OK:
		push_warning("Extraction of the environment was not clean, TAR error code %d\n%s" % [ result, "\n".join(stdout) ])
	DirAccess.remove_absolute(pck_filepath)
	# 3. Write version file indicating the last installed environment
	var file: FileAccess = FileAccess.open(env_md5_path, FileAccess.WRITE)
	var md5: String = FileAccess.get_md5(pre_pck_filepath)
	file.store_string(md5)
	file.close()
	
	_notify_environment_installed.call_deferred()


func install_additional_scripts(out_backed_up_files := PackedStringArray()) -> void:
	assert(needs_install_scripts(), "Scripts are already installed in the user folder")
	for src in _get_additional_scripts_list():
		var abs_destination: String = globalize_path(src.replace("res://", "user://"))
		_install_file_from_res(src, abs_destination, false, true, out_backed_up_files)
		if src.get_extension() == "sh":
			var result: int = OS.execute("chmod", ["+x", abs_destination])
			assert(result == OK, "Could not set executable permissions to file %s" % [abs_destination] )


func needs_install_or_update() -> bool:
	var old_md5_path: String = msep_environment_path.path_join("environment_md5")
	if not FileAccess.file_exists(old_md5_path):
		return true
	var platform: String = OS.get_name().to_lower()
	var arch: String = "x86_64"
	# Detect platform
	if platform == "macos":
		if OS.has_feature("arm64"):
			arch= "arm64"
	var filename: String = "env_%s_%s.tar.gz" % [platform, arch]
	var pck_filepath: String = "res://python/conda/%s" % filename
	var pack_md5: String = FileAccess.get_md5(pck_filepath)
	var old_md5: String = FileAccess.get_file_as_string(old_md5_path)
	if pack_md5.is_empty():
		push_error("Unexisting environment pack '%s'" % [filename])
		return false
	return old_md5 != pack_md5


func needs_install_scripts() -> bool:
	for src in _get_additional_scripts_list():
		var abs_destination: String = globalize_path(src.replace("res://", "user://"))
		if !FileAccess.file_exists(abs_destination):
			# File is not installed yet
			return true
		if is_modification_of_server_script_allowed():
			# No need to override
			continue
		var old_md5: String = FileAccess.get_md5(src)
		assert(!old_md5.is_empty(), "A mandatory OpenMM script (%s) is not present in the project." % src + \
									" Was it not added to export?")
		var installed_md5: String = FileAccess.get_md5(abs_destination)
		if old_md5 != installed_md5:
			# File has changed, needs reinstall
			return true
	return false


func _install_file_from_res(in_res_path: String, in_absolute_dest_path: String, in_force: bool,
			in_do_backup: bool, out_backed_up_files := PackedStringArray()) -> void:
	if not in_force and is_modification_of_server_script_allowed() and FileAccess.file_exists(in_absolute_dest_path):
		# Do not override file with default implementation when editing it is allowed
		return
	# This method is used instead of
	# DirAccess.copy(pre_pck_filepath, pck_filepath)
	# because after export, files located in res:// are stored inside the project
	# MSEP.pck file, and in consecuence file system operations are not possible
	DirAccess.make_dir_recursive_absolute(in_absolute_dest_path.get_base_dir())
	if in_do_backup and FileAccess.file_exists(in_absolute_dest_path):
		if FileAccess.get_file_as_bytes(in_res_path) == FileAccess.get_file_as_bytes(in_absolute_dest_path):
			# source and dest files are equal, no need to backup or override
			return
		# backup the file to prevent loss of modifications that could be performed by advanced users
		var base_dir: String = in_absolute_dest_path.get_base_dir()
		var filename: String = in_absolute_dest_path.get_file()
		var file_basename: String = filename.get_basename()
		var extension: String = filename.get_extension()
		var timestamp: String = Time.get_datetime_string_from_system().replace(":","-")
		var new_path: String = "{base_dir}/{file_basename}-{timestamp}.{extension}~".format({
			"base_dir" = base_dir,
			"file_basename" = file_basename,
			"extension" = extension,
			"timestamp" = timestamp,
		})
		var err: Error = DirAccess.rename_absolute(in_absolute_dest_path, new_path)
		if err == OK:
			out_backed_up_files.append(new_path)
		else:
			push_error("Failed to rename '%s' to '%s' with error code %d" % [in_absolute_dest_path, new_path, err])
	var destination_file := FileAccess.open(in_absolute_dest_path, FileAccess.WRITE)
	destination_file.store_buffer(FileAccess.get_file_as_bytes(in_res_path))
	destination_file.close()


func _get_additional_scripts_list() -> Array[String]:
	var scripts_paths: Array[String] = []
	var is_unix: bool = OS.get_name().to_lower() in ["linux", "macos"]
	if is_unix:
		scripts_paths.append_array(_EXTERNAL_PROCESS_SCRIPTS_UNIX)
	scripts_paths.append_array(_EXTERNAL_PROCESS_SCRIPTS_ALL)
	return scripts_paths


func _notify_environment_installed() -> void:
	environment_installed.emit()


static func globalize_path(path: String) -> String:
	if not path.begins_with("res://") or OS.has_feature("editor"):
		# Running from an editor binary.
		# `path` will contain the absolute path to `hello.txt` located in the project root.
		return ProjectSettings.globalize_path(path)
	else:
		# Running from an exported project.
		# `path` will contain the absolute path to `hello.txt` next to the executable.
		# This is *not* identical to using `ProjectSettings.globalize_path()` with a `res://` path,
		# but is close enough in spirit.
		return OS.get_executable_path().get_base_dir().path_join(path.replace("res://", ""))


