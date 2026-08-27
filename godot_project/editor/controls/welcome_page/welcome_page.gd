extends Control

const MsepHomeSettings: Script = preload("uid://x5mbp5sdep3e")
const LoadRecentBtnScene: PackedScene = preload("uid://dcasl2w72vcie")
const SETTINGS_FOLDER = "user://editor/"
const SETTINGS_FILE   = "home_settings.res"
const MAX_KNOWN_WORKSPACES_SHOWN: int = 4


@onready var new_workspace: Button = %NewWorkspace
@onready var load_workspace_from_disk: Button = %LoadWorkspaceFromDisk
@onready var known_workspaces_box: HFlowContainer = %KnownWorkspacesBox
@onready var _contextual_popup_menu: PopupMenu = $ContextualPopupMenu

var _settings: MsepHomeSettings
var _first_run: bool = true

func _ready() -> void:
	_ensure_settings_exists()
	_update_workspaces_list()
	new_workspace.pressed.connect(_on_new_workspace_pressed)
	load_workspace_from_disk.pressed.connect(_on_load_workspace_from_disk_pressed)
	_contextual_popup_menu.index_pressed.connect(_on_contextual_popup_menu_index_pressed)
	_contextual_popup_menu.visibility_changed.connect(_on_contextual_popup_menu_visibility_changed_deferred, CONNECT_DEFERRED)
	visibility_changed.connect(_update_workspaces_list)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if is_visible_in_tree():
			if _contextual_popup_menu.has_meta(&"button"):
				# Ignore when focus comes back from contextual menu
				return
			_update_workspaces_list()


func _update_workspaces_list() -> void:
	if !is_visible_in_tree():
		return
	for child in known_workspaces_box.get_children():
		child.queue_free()
	var d: DirAccess = DirAccess.open("user://")
	var workspace_to_activate: Workspace = null
	var link_count: int = 0
	for workspace in _settings.known_workspaces:
		if link_count >= MAX_KNOWN_WORKSPACES_SHOWN and MAX_KNOWN_WORKSPACES_SHOWN != -1:
			break
		if not d.file_exists(workspace):
			continue
		var btn: Button = LoadRecentBtnScene.instantiate()
		btn.set_workspace_path(workspace)
		btn.pressed.connect(_on_open_workspace_by_path.bind(workspace))
		btn.context_menu_requested.connect(_on_recent_project_button_context_menu_requested)
		known_workspaces_box.add_child(btn)
		var should_open: bool = _settings.autoload_open_workspaces and _settings.open_workspaces.find(workspace) != -1
		if should_open:
			btn.setup_for_activation()
			var w: Workspace = MolecularEditorContext.soft_load_workspace(workspace)
			if workspace_to_activate == null:
				# First workspace in the list should be the last one active
				# so we activate this one on startup
				workspace_to_activate = w
	if _first_run:
		if is_instance_valid(workspace_to_activate):
			MolecularEditorContext.activate_workspace(workspace_to_activate)
		else:
			var opening_workspace: bool = false
			for arg in OS.get_cmdline_args():
				if arg.is_absolute_path() and FileAccess.file_exists(arg) and arg.get_extension() == "msep1":
					opening_workspace = true
					break
			if not opening_workspace:
				MolecularEditorContext.create_workspace()
	_first_run = false


func _ensure_settings_exists() -> void:
	var d: DirAccess = DirAccess.open("user://")
	if !d.dir_exists(SETTINGS_FOLDER):
		d.make_dir_recursive(SETTINGS_FOLDER)
	
	if d.file_exists(SETTINGS_FOLDER.path_join(SETTINGS_FILE)):
		_load_settings()
	else:
		_settings = MsepHomeSettings.new()
		_save_settings()
	if !_settings.changed.is_connected(_save_settings):
		_settings.changed.connect(_save_settings)

func _load_settings() -> void:
	_settings = load(SETTINGS_FOLDER.path_join(SETTINGS_FILE)) as MsepHomeSettings
	if !is_instance_valid(_settings):
		# File got corrupted?
		_settings = MsepHomeSettings.new()
		_save_settings()

func _save_settings() -> void:
	ResourceSaver.save(_settings, SETTINGS_FOLDER.path_join(SETTINGS_FILE))

func _on_recent_project_button_context_menu_requested(button: Button, filepath: String) -> void:
	_contextual_popup_menu.set_meta(&"button", button)
	_contextual_popup_menu.set_meta(&"filepath", filepath)
	_contextual_popup_menu.position = get_viewport().get_mouse_position()
	_contextual_popup_menu.popup()

func _on_contextual_popup_menu_visibility_changed_deferred() -> void:
	# This is connect deferred to ensure it runs after _notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)
	# and _on_contextual_popup_menu_index_pressed(index)
	if !_contextual_popup_menu.visible:
		_contextual_popup_menu.remove_meta(&"button")
		_contextual_popup_menu.remove_meta(&"filepathon")

func _on_contextual_popup_menu_index_pressed(index: int) -> void:
	const INDEX_FORGET_RECENT_PROJECT = 0
	match index:
		INDEX_FORGET_RECENT_PROJECT:
			var button: Button = _contextual_popup_menu.get_meta(&"button") as Button
			var filepath: String = _contextual_popup_menu.get_meta(&"filepath")
			_settings.remove_known_workspace(filepath)
			if is_instance_valid(button):
				button.queue_free.call_deferred()
		_:
			assert(false, "Unknown index option %d" % index)
			return

func _on_open_workspace_by_path(path: String) -> void:
	MolecularEditorContext.load_and_activate_workspace(path)

func _on_new_workspace_pressed() -> void:
	MolecularEditorContext.create_workspace()

func _on_load_workspace_from_disk_pressed() -> void:
	Editor_Utils.get_editor().show_open_workspace_dialog()
