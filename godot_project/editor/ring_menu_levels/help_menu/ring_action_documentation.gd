class_name RingActionOpenDocumentation extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

const DOCUMENTATION_PATH_SOURCE: String = "res://documentation/msep_documentation.pdf"
const DOCUMENTATION_FILE_NAME_IN_USER_DIR = "msep_one_documentation.pdf"

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Tutorials and Instructions"),
		_execute_action,
		tr("Open the documentation using an external viewer."),
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_documentation.svg"))


func _execute_action() -> void:
	if not FileAccess.file_exists(DOCUMENTATION_PATH_SOURCE):
		printerr("Trying to open documentation, but I cannot find the source file")
		return
	
	var destination_documentation_path: String = OS.get_user_data_dir() + "/" + DOCUMENTATION_FILE_NAME_IN_USER_DIR
	if _need_to_refresh_user_file(destination_documentation_path):
		# file needs to be moved out of .pck in order for the OS to be able to open it in external program
		FileUtils.copy_file_from_to(DOCUMENTATION_PATH_SOURCE, destination_documentation_path)
	
	OS.shell_open(ProjectSettings.globalize_path(destination_documentation_path))
	_ring_menu.close()


func _need_to_refresh_user_file(in_user_file_path: String) -> bool:
	if not FileAccess.file_exists(in_user_file_path):
		return true
	
	var source_hash: String = FileUtils.calculate_file_hash(DOCUMENTATION_PATH_SOURCE)
	var destination_hash: String = FileUtils.calculate_file_hash(in_user_file_path)
	return source_hash != destination_hash


