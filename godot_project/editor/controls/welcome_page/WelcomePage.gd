extends Control

const MespHomeSettings = preload("res://editor/controls/welcome_page/MespHomeSettings.gd")
const SETTINGS_FOLDER = "user://editor/"
const SETTINGS_FILE   = "home_settings.res"
const MAX_KNOWN_WORKSPACES_SHOWN: int = 4

const FEATURE_FLAG_NEW_PROJECT_ON_STARTUP = "feature_flags/new_workspace_on_startup"

@onready var new_workspace: LinkButton = %NewWorkspace
@onready var load_workspace_from_disk: LinkButton = %LoadWorkspaceFromDisk
@onready var known_workspaces_box: VBoxContainer = %KnownWorkspacesBox

var _settings: MespHomeSettings
var _first_run: bool = true

func _ready() -> void:
	_ensure_settings_exists()
	_update_workspaces_list()
	new_workspace.pressed.connect(_on_new_workspace_pressed)
	load_workspace_from_disk.pressed.connect(_on_load_workspace_from_disk_pressed)
	visibility_changed.connect(_update_workspaces_list)

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
		var link := LinkButton.new()
		link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		link.text = tr("Open '%s'" % [workspace])
		link.tooltip_text = tr("Open and activate %s" % [workspace])
		link.pressed.connect(_on_open_workspace_by_path.bind(workspace))
		known_workspaces_box.add_child(link)
		link_count += 1
		var should_open: bool = _settings.autoload_open_workspaces and _settings.open_workspaces.find(workspace) != -1
		if should_open:
			link.text = tr("Go to '%s'" % [workspace.get_basename()])
			link.tooltip_text = tr("Activate %s" % [workspace])
			var w: Workspace = MolecularEditorContext.soft_load_workspace(workspace)
			if workspace_to_activate == null:
				# First workspace in the list should be the last one active
				# so we activate this one on startup
				workspace_to_activate = w
	if _first_run:
		if is_instance_valid(workspace_to_activate):
			MolecularEditorContext.activate_workspace(workspace_to_activate)
		elif ProjectSettings.get_setting(FEATURE_FLAG_NEW_PROJECT_ON_STARTUP, true):
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
		_settings = MespHomeSettings.new()
		_save_settings()
	if !_settings.changed.is_connected(_save_settings):
		_settings.changed.connect(_save_settings)

func _load_settings() -> void:
	_settings = load(SETTINGS_FOLDER.path_join(SETTINGS_FILE)) as MespHomeSettings
	if !is_instance_valid(_settings):
		# File got corrupted?
		_settings = MespHomeSettings.new()
		_save_settings()

func _save_settings() -> void:
	ResourceSaver.save(_settings, SETTINGS_FOLDER.path_join(SETTINGS_FILE))

func _on_open_workspace_by_path(path: String) -> void:
	MolecularEditorContext.load_and_activate_workspace(path)

func _on_new_workspace_pressed() -> void:
	MolecularEditorContext.create_workspace()

func _on_load_workspace_from_disk_pressed() -> void:
	Editor_Utils.get_editor().show_open_workspace_dialog()
