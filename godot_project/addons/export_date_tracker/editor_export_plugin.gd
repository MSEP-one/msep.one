@tool
extends EditorExportPlugin

const _EXPORT_DATE_SETTING_NAME: StringName = &"application/config/export_date"
const _EXPORT_COMMIT_SETTING_NAME: StringName = &"application/config/export_commit"

func _get_name() -> String:
	return "Export Date Tracker"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var now: String = Time.get_date_string_from_system(true)
	ProjectSettings.set_setting(_EXPORT_DATE_SETTING_NAME, now)

	var git_out: Array = []
	# The “$ git rev-parse” command can be utilized for getting the SHA hashes of branches or HEAD.
	#+In this case we run it as a shell command to get the hash from the captured stdout
	if OS.execute("git", ["rev-parse", "HEAD"], git_out) == OK:
		assert(git_out.size() > 0)
		var latest_head_hash: String = git_out[0]
		ProjectSettings.set_setting(_EXPORT_COMMIT_SETTING_NAME, latest_head_hash)
	
	ProjectSettings.save()

func _export_end() -> void:
	ProjectSettings.set_setting(_EXPORT_DATE_SETTING_NAME, null)
	ProjectSettings.set_setting(_EXPORT_COMMIT_SETTING_NAME, null)
	ProjectSettings.save()
