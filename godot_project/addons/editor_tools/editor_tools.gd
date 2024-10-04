@tool
extends EditorPlugin


const BLENDER_CHECK_DEPENDENCY: bool = false
const BLENDER_WARNING_TITLE = "Please configure Blender path"
const BLENDER_WARNING_TEXT = "Configure Blender 3.x path in Editor Settings, it needs to point to Blender directory \nYou can find the related setting in Editor -> Editor Settings -> 'Filesystem/Import/Blender 3 path' \nPlease restart the editor after applying this change"

const BLENDER_EDITOR_SETTING_PATH = "filesystem/import/blender/blender3_path"


func _enter_tree() -> void:
	if BLENDER_CHECK_DEPENDENCY:
		_validate_blender_settings()


func _validate_blender_settings() -> void:
	var editor_interface: EditorInterface = get_editor_interface()
	var editor_settings: EditorSettings = editor_interface.get_editor_settings()
	var blender_path: String = editor_settings.get_setting(BLENDER_EDITOR_SETTING_PATH)
	
	if blender_path.is_empty():
		_show_warning(BLENDER_WARNING_TITLE, BLENDER_WARNING_TEXT)
		return
	
	if not DirAccess.dir_exists_absolute(blender_path):
		_show_warning(BLENDER_WARNING_TITLE, BLENDER_WARNING_TEXT)
		return
	
	var dir: DirAccess = DirAccess.open(blender_path)
	var blender_dir_files: PackedStringArray = dir.get_files()
	var blender_exacutable_found: bool = false
	for file in blender_dir_files:
		if file.to_lower().find("blender") > -1:
			blender_exacutable_found = true
			break
	
	if not blender_exacutable_found:
		_show_warning(BLENDER_WARNING_TITLE, BLENDER_WARNING_TEXT)
		return


func _show_warning(in_title:String, in_warning_text: String) -> void:
	var warning_dialog: AcceptDialog = AcceptDialog.new()
	warning_dialog.title = in_title
	warning_dialog.dialog_text = in_warning_text
	add_child(warning_dialog)
	warning_dialog.popup_centered()


func _exit_tree() -> void:
	pass
