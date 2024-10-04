@tool
extends EditorScript

var _uid_resources_map: Dictionary = {
#	uid: String = resources: PackedStringArray
}
# Called when the script is executed (using File -> Run in Script Editor).
func _run() -> void:
	print("========START SEARCHING DUPLICATE UIDS========")
	_uid_resources_map.clear()
	_scan_directory("res://")
	var uids: Array = _uid_resources_map.keys()
	var duplicate_uids: Array = uids.filter(_uid_has_many_resources)
	for uid: String in duplicate_uids:
		var resources: PackedStringArray = _uid_resources_map.get(uid, [])
		var err: String = "%s has many asociated paths:" % uid
		for path in resources:
			err += "\n\t" + path
		print_debug(err)
	print("=========END SEARCHING DUPLICATE UIDS=========")

func _scan_directory(in_path: String) -> void:
	var dir: DirAccess = DirAccess.open(in_path)
	if !dir:
		push_error("Invalid Path '%s'" % in_path)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = in_path.path_join(file_name)
		if file_name in [".", ".."]:
			pass # Nothing to do here
		elif dir.current_is_dir():
			_scan_directory(full_path)
		elif file_name.ends_with(".import"):
			var uid: String = _extract_uid(full_path)
			if !_uid_resources_map.has(uid):
				_uid_resources_map[uid] = PackedStringArray()
			_uid_resources_map[uid].push_back(full_path.replace(".import", ""))
		file_name = dir.get_next()

func _uid_has_many_resources(in_uid: String) -> bool:
	var resources: PackedStringArray = _uid_resources_map.get(in_uid, [])
	return resources.size() > 1

func _extract_uid(in_path: String) -> String:
	var file: FileAccess = FileAccess.open(in_path, FileAccess.READ)
	if file == null:
		push_error("Failed to load file " + in_path + ". Could not extract uid")
		return String()
	while !file.eof_reached():
		var line: String = file.get_line()
		if line.begins_with("uid=\""):
			return line.rstrip("\"").replace("uid=\"", "")
	push_warning("Failed to extract uid from file " + in_path + ". File does not seem to contain a uid Entry")
	return String()
