extends Node

const WorkspaceContextScn: PackedScene = preload("res://project_workspace/workspace_context/workspace_context.tscn")
const DEFAULT_STRUCTURE_NAME = "Workspace"

signal homepage_activated()
signal workspace_loaded(workspace: Workspace)
signal workspace_activated(workspace: Workspace)
signal workspace_saved(workspace: Workspace)
signal workspace_closed(workspace: Workspace)


var msep_editor_settings: MSEPSettings = null

var _clipboard: NanoEditorClipboard

var _open_workspaces: Array[Workspace]
var _current_workspace: Workspace

var _open_contexts_holder: NodeHolder

# RegEx explained: \w+[ |_](\d{1,3})$
# - \w matches any letter, digit and underscore character
# - \w+ matches one or more letters, digits and underscore characters
# - [ |_] matches both a blankspace character and an underscore character
# - \d matches any digit, that is the same as [0-9]
# - \d{1,3} will match any number between 1 and 3 digits long.
# - $ placed at the end, this character matches a pattern at the end of the string
#
# This means that the RegEx will match strings that end with a sequence of
# letters, digits and/or underscore characters, followed by a blankspace character or
# an underscore character, followed by a number between 1 and 3 digits long.
var _workspace_name_pattern: RegEx = RegEx.create_from_string("\\w+[ |_](\\d{1,3})$")


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_open_contexts_holder = get_node("WorkspaceContextsHolder")
	if what == NOTIFICATION_PREDELETE:
		if msep_editor_settings != null:
			msep_editor_settings.save_settings()
		for workspace in _open_workspaces:
			close_workspace_no_prompt(workspace)


## Request to show the home page
func show_homepage() -> void:
	_current_workspace = null
	homepage_activated.emit()
	_update_window_title()


func is_homepage_active() -> bool:
	return _current_workspace == null


## Create a new workspace, initially stored in ram, will not be saved to disk until required
func create_workspace() -> Workspace:
	var workspace := Workspace.new()
	var main_structure := AtomicStructure.create()
	main_structure.set_structure_name(DEFAULT_STRUCTURE_NAME)
	workspace.add_structure(main_structure)
	_open_workspaces.push_back(workspace)
	workspace_loaded.emit(workspace)
	var workspace_context: WorkspaceContext = get_workspace_context(workspace)
	workspace_context.activate_nano_structure(main_structure)
	activate_workspace(workspace)
	return workspace


func get_active_workspace_count() -> int:
	return _open_workspaces.size()


func get_current_workspace() -> Workspace:
	return _current_workspace


func get_open_workspaces() -> Array[Workspace]:
	# Copy makes sure local list cannot be modified
	var open_workspaces_copy: Array[Workspace] = _open_workspaces.duplicate()
	return open_workspaces_copy


func find_workspace_possessing_structure(in_structure_to_find: NanoStructure) -> Workspace:
	var workspaces: Array[Workspace] = get_open_workspaces()
	for workspace in workspaces:
		if workspace.has_structure(in_structure_to_find):
			return workspace
	return null


## Soft loading a workspace will load it from disk but will not immediately activate it
func soft_load_workspace(in_path: String) -> Workspace:
	var workspace: Workspace = load(in_path) as Workspace
	if !is_instance_valid(workspace):
		return null
	if _open_workspaces.find(workspace) == -1:
		apply_workspace_version_fixes(workspace)
		_open_workspaces.push_back(workspace)
		workspace_loaded.emit(workspace)
		return workspace
	
	var workspace_copy: Workspace = ResourceLoader.load(in_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	# ResourceLoader.CACHE_MODE_IGNORE ignores cache, but also removes from the cache the object that was
	# asociated to in_path. This workaround should reasociate the original workspace to the path
	workspace.take_over_path(in_path)
	workspace_copy.resource_path = ""
	workspace_copy.suggested_path = _get_suggested_path(in_path)
	apply_workspace_version_fixes(workspace_copy)
	_open_workspaces.push_back(workspace_copy)
	workspace_loaded.emit(workspace_copy)
	return workspace_copy


## During development, the format or data of workspaces can change, and this invalidates old files
## This function is intended to mitigate the problem by making some changes to the workspace before
## the rest of the MSEP.one editor takes over it
func apply_workspace_version_fixes(_out_workspace: Workspace, in_force: bool = false) -> void:
	if not in_force and not FeatureFlagManager.get_flag_value(
			FeatureFlagManager.FEATURE_FLAG_APPLY_WORKSPACE_VERSION_FIXES):
		return


func _get_suggested_path(in_path: String) -> String:
	var new_workspace_name: String = _get_new_workspace_name(in_path)
	var already_used_paths: Array = _open_workspaces.map(
		func(in_workspace: Workspace) -> String: return in_workspace.resource_path \
		if not in_workspace.resource_path.is_empty() else in_workspace.suggested_path
	)
	already_used_paths = already_used_paths.filter(
		func(path: String) -> bool: return path.get_base_dir() == in_path.get_base_dir()
	)
	var dir_access: DirAccess = DirAccess.open(in_path.get_base_dir())
	if is_instance_valid(dir_access):
		var other_files_in_the_same_folder: Array = dir_access.get_files()
		var other_files_in_the_same_folder_paths: Array = \
			other_files_in_the_same_folder.map(
				func(file_name: String) -> String: return in_path.get_base_dir().path_join(file_name)
			)
		already_used_paths.append_array(other_files_in_the_same_folder_paths)
	var suggested_path: String = in_path.get_base_dir().path_join(new_workspace_name)
	while suggested_path in already_used_paths:
		new_workspace_name = _get_new_workspace_name(suggested_path)
		assert(not suggested_path.ends_with(new_workspace_name))
		suggested_path = in_path.get_base_dir().path_join(new_workspace_name)
	return suggested_path


func _get_new_workspace_name(in_path: String) -> String:
	const workspace_file_extension: String = ".msep1"
	var worskpace_name: String = in_path.get_file().get_basename()
	var regex_result: RegExMatch = _workspace_name_pattern.search(worskpace_name)
	if regex_result:
		var sequence_number_str: String = regex_result.get_string(1)
		var file_sequence_number: int = sequence_number_str.to_int() + 1
		return worskpace_name.substr(0, worskpace_name.length() - sequence_number_str.length()) + \
			str(file_sequence_number) + workspace_file_extension
	else:
		return worskpace_name + " 1" + workspace_file_extension


## Load a workspace from disk (if not already loaded) and immediately activate it.
func load_and_activate_workspace(in_path: String) -> void:
	var workspace: Workspace = soft_load_workspace(in_path)
	if not is_instance_valid(workspace):
		Editor_Utils.get_editor().prompt_error_msg(("Cannot load file '%s'\n" % in_path) +
			"ensure write permissions are granted and file is not corrupted.")
		return
	var workspace_context: WorkspaceContext = get_workspace_context(workspace)
	workspace_context.set_camera_global_transform(workspace.camera_transform)
	# Needs to call_deferred to be executed after msep_editor_settings.changed is emmited
	workspace_context.set_camera_orthogonal_size.call_deferred(workspace.camera_orthogonal_size)
	var active_structure_id: int = workspace.active_structure_int_guid
	var active_structure: NanoStructure = workspace.get_structure_by_int_guid(active_structure_id)
	workspace_context.set_current_structure_context(workspace_context.get_nano_structure_context(active_structure))
	if is_instance_valid(workspace):
		activate_workspace(workspace)
	_validate_forcefield_files(workspace_context)


## Activate a workspace will make it's Tab in editor selected
func activate_workspace(in_workspace: Workspace) -> void:
	assert(is_instance_valid(in_workspace), "Invalid workspace")

	assert(_open_workspaces.find(in_workspace) != -1, "Workspace has not been registered propperly")
	_current_workspace = in_workspace

	workspace_activated.emit(in_workspace)
	get_workspace_context(in_workspace).notify_activated()


## Save a workspace to disk, if an empty path is passed a save dialog will be proimpt
func save_workspace(in_workspace: Workspace, in_path: String = "") -> void:
	var path: String = in_path
	var workspace_context: WorkspaceContext = get_workspace_context(in_workspace)
	in_workspace.camera_transform = workspace_context.get_camera_global_transform()
	in_workspace.camera_orthogonal_size = workspace_context.get_camera_orthogonal_size()
	if path.is_empty():
		path = in_workspace.resource_path
	if path.is_empty():
		Editor_Utils.get_editor().show_save_workspace_dialog(in_workspace)
		return
	var currently_open_workspace: Workspace = _find_workspace_with_resource_path(in_path)
	var there_is_another_open_workspace_from_that_file: bool = \
		is_instance_valid(currently_open_workspace) and not in_workspace == currently_open_workspace
	if there_is_another_open_workspace_from_that_file:
		# The path selected by the user points to a file that already exists
		# and there is another open workspace that was loaded from that file
		var err_msg: String = tr(&"Failed to save file {0}. An open workspace named {1} is using that file.").format(
			[path, currently_open_workspace.get_user_friendly_name().get_file().get_basename().capitalize()]
		)
		Editor_Utils.get_editor().prompt_error_msg(err_msg)
		return
	var err: Error = ResourceSaver.save(in_workspace, path)
	if err != OK:
		Editor_Utils.get_editor().prompt_error_msg(tr(&"Failed to save file {0} with error '{1}'").format([path, error_string(err)]))
		return
	in_workspace.resource_path = in_path
	var current_workspace_context: WorkspaceContext = get_current_workspace_context()
	assert(is_instance_valid(current_workspace_context), "Invalid workspace context")
	current_workspace_context.mark_saved()
	workspace_saved.emit(in_workspace)
	_update_window_title()


func export_workspace(in_workspace: Workspace, in_path: String = "") -> void:
	var path: String = in_path
	if path.is_empty():
		Editor_Utils.get_editor().show_export_workspace_dialog(in_workspace)
		return
	var err: Error = ResourceSaver.save(in_workspace, path)
	if err != OK:
		Editor_Utils.get_editor().prompt_error_msg(tr(&"Failed to export to file {0} with error '{1}'").format([path, error_string(err)]))


func _find_workspace_with_resource_path(in_resource_path: String) -> Workspace:
	for open_workspace: Workspace in _open_workspaces:
		if open_workspace.resource_path == in_resource_path:
			return open_workspace
	return null


func request_close_workspace(in_workspace: Workspace) -> void:
	var context: WorkspaceContext = get_workspace_context(in_workspace)
	if context.has_unsaved_changes():
		Editor_Utils.get_editor().show_close_workspace_confirmation_dialog(
			in_workspace.get_user_friendly_name(),
			close_workspace_no_prompt.bind(in_workspace),
			save_workspace.bind(in_workspace))
	else:
		close_workspace_no_prompt(in_workspace)


func is_workspace_docker_active(in_docker_unique_name: StringName) -> bool:
	var workspace_context: WorkspaceContext = get_current_workspace_context()
	if workspace_context == null:
		return false
	var view: WorkspaceMainView = workspace_context.workspace_main_view
	if not in_docker_unique_name in view.editor_dockers.keys():
		push_error("Docker with unique name %s doesn't exists!" % in_docker_unique_name)
		return false
	var docker: WorkspaceDocker = view.editor_dockers.get(in_docker_unique_name, null) as WorkspaceDocker
	return docker.is_visible_in_tree()


func request_workspace_docker_focus(in_docker_unique_name: StringName, in_category_name := StringName()) -> void:
	var workspace_context: WorkspaceContext = get_current_workspace_context()
	if workspace_context == null:
		return
	var view: WorkspaceMainView = workspace_context.workspace_main_view
	if not in_docker_unique_name in view.editor_dockers.keys():
		push_error("Cannot focus on unexisting docker unique name %s!" % in_docker_unique_name)
		return
	var docker: WorkspaceDocker = view.editor_dockers.get(in_docker_unique_name, null) as WorkspaceDocker
	assert(docker, "Registered workspace docker does not inherit class WorkspaceDocker")
	docker.ensure_docker_area_visible()
	if !docker.visible:
		var tab_container: DockerTabContainer = docker.get_container() as DockerTabContainer
		if tab_container == null:
			# Just make the docker visible
			docker.visible = true
		else:
			tab_container.focus_tab_control(docker)
	
	if in_category_name == StringName():
		return
	# Wait one frame to allow controls update their visibility
	await get_tree().process_frame
	if docker.has_category(in_category_name):
		docker.highlight_category(in_category_name)


func close_workspace_no_prompt(in_workspace: Workspace) -> void:
	assert(is_instance_valid(in_workspace), "Invalid workspace")
	assert(_open_workspaces.find(in_workspace) != -1, "Workspace has not been registered propperly")
	var index: int = _open_workspaces.find(in_workspace)
	_open_workspaces.remove_at(index)
	if in_workspace == _current_workspace:
		# Prevent gizmo nodes to be deleted
		if is_instance_valid(GizmoRoot):
			GizmoRoot.disable_gizmo()
		_current_workspace = null
	if is_instance_valid(_open_contexts_holder):
		var context: WorkspaceContext = _open_contexts_holder.get_node(in_workspace.get_string_id())
		_open_contexts_holder.remove_child(context)
		context.free()
	workspace_closed.emit(in_workspace)


func get_workspace_context(in_workspace: Workspace) -> WorkspaceContext:
	assert(is_instance_valid(in_workspace))
	if _open_workspaces.find(in_workspace) == -1:
		push_error("The requested workspace is not properly registered")
		return null
	
	var workspace_name: String = in_workspace.get_string_id()
	if  not _open_contexts_holder.has_node(workspace_name):
		var workspace_context: WorkspaceContext = WorkspaceContextScn.instantiate()
		workspace_context.initialize(in_workspace)
		_open_contexts_holder.add_child_with_name(workspace_context, in_workspace.get_string_id())
	
	return _open_contexts_holder.get_node(in_workspace.get_string_id()) as WorkspaceContext


func get_current_workspace_context() -> WorkspaceContext:
	if get_current_workspace() == null:
		return null
	return get_workspace_context(get_current_workspace())


func copy_selection() -> void:
	var current_workspace_context: WorkspaceContext = get_workspace_context(_current_workspace)
	
	if current_workspace_context:
		_clipboard.copy(current_workspace_context)
	else:
		print("Copy failed")


func cut_selection() -> void:
	var current_workspace_context: WorkspaceContext = get_workspace_context(_current_workspace)
	if current_workspace_context:
		_clipboard.cut(current_workspace_context)
	else:
		print("Cut failed")


## in_auto_bond_order - order of the auto-created bond, when bonded paste is being used it will
## be of values 1,2,3 otherwise it will be -1
func paste_clipboard_content(in_auto_bond_order: int) -> void:
	assert(in_auto_bond_order >= -1 and in_auto_bond_order <= 3 and in_auto_bond_order != 0)
	var current_workspace_context: WorkspaceContext = get_workspace_context(_current_workspace)
	if current_workspace_context:
		_clipboard.paste(current_workspace_context, in_auto_bond_order)
	else:
		print("Paste failed")


func is_clipboard_empty() -> bool:
	return not _clipboard.has_content()


func bottom_bar_update_distance(in_workspace_context: WorkspaceContext, in_distance_description: String, in_distance: float) -> void:
	var view: WorkspaceMainView = in_workspace_context.workspace_main_view
	view.bottom_bar_update_distance(in_distance_description, in_distance)


func _init() -> void:
	if FileAccess.file_exists(MSEPSettings.SETTINGS_RESOURCE_PATH):
		msep_editor_settings = ResourceLoader.load(MSEPSettings.SETTINGS_RESOURCE_PATH)
	else:
		msep_editor_settings = MSEPSettings.new()
	_clipboard = NanoEditorClipboard.new()
	_clipboard.name = &"NanoEditorClipboard"
	add_child(_clipboard)


func _ready() -> void:
	workspace_activated.connect(_on_workspace_activated)
	_ready_deferred.call_deferred()
	_update_window_title()
	
	# Manually register the resources format savers and loaders.
	# This should happen automatically when giving the loader/saver a class_name but an engine bug
	# causes the parser to fail because these classes indirectly references one or more autoloads.
	const FORMAT_LOADERS: PackedStringArray = [
		"res://project_workspace/file_format/workspace_format_loader.gd",
	]
	const FORMAT_SAVERS: PackedStringArray = [
		"res://project_workspace/file_format/workspace_format_saver.gd",
		"res://project_workspace/file_format/external/xyz_format_saver.gd",
		"res://project_workspace/file_format/external/pdb_format_saver.gd",
	]
	
	for loader_path in FORMAT_LOADERS:
		var loader: ResourceFormatLoader = load(loader_path).new()
		assert(loader)
		ResourceLoader.add_resource_format_loader(loader)
	
	for saver_path in FORMAT_SAVERS:
		var saver: ResourceFormatSaver = load(saver_path).new()
		assert(saver)
		ResourceSaver.add_resource_format_saver(saver)


func _ready_deferred() -> void:
	var cmdline_args: PackedStringArray = OS.get_cmdline_args()
	for arg in cmdline_args:
		if OS.has_feature("editor"):
			if arg.begins_with("res://") && arg.ends_with("tscn") && \
			arg != ProjectSettings.get_setting(&"application/run/main_scene", ""):
				# Running a custom scene, do not initialize MolecularEditor
				return
		if arg.is_absolute_path() and FileAccess.file_exists(arg) and arg.get_extension() == "msep1":
			load_and_activate_workspace(arg)
	var molecular_editor: MolecularEditor = Editor_Utils.get_editor()
	assert(molecular_editor)
	molecular_editor.save_workspace_confirmed.connect(_on_molecular_editor_save_workspace_confirmed)
	molecular_editor.load_workspace_confirmed.connect(_on_molecular_editor_load_workspace_confirmed)
	molecular_editor.export_workspace_confirmed.connect(_on_molecular_editor_export_workspace_confirmed)
	if _current_workspace == null:
		homepage_activated.emit()


func _on_molecular_editor_save_workspace_confirmed(in_workspace: Workspace, in_path: String) -> void:
	save_workspace(in_workspace, in_path)


func _on_molecular_editor_load_workspace_confirmed(in_path: String) -> void:
	load_and_activate_workspace(in_path)


func _on_molecular_editor_export_workspace_confirmed(in_workspace: Workspace, in_path: String) -> void:
	export_workspace(in_workspace, in_path)


func _on_about_msep_one_confirmed() -> void:
	AboutMsepOne.confirmed.disconnect(_on_about_msep_one_confirmed)


func show_first_run_message() -> void:
	var first_run_dialog := NanoAcceptDialog.new()
	first_run_dialog.dialog_text = tr("Raise the 'Action Ring' by pressing TAB or right-clicking the mouse.")
	first_run_dialog.ok_button_text = tr("OK")
	first_run_dialog.title = tr("MSEP first steps")
	add_child(first_run_dialog)
	first_run_dialog.popup_centered()
	first_run_dialog.closed.connect(_on_first_run_dialog_closed.bind(first_run_dialog))
	msep_editor_settings.save_settings()


func _on_first_run_dialog_closed(_in_accepted: bool, out_first_run_dialog: NanoAcceptDialog) -> void:
	out_first_run_dialog.queue_free()


func _on_workspace_activated(in_workspace: Workspace) -> void:
	_update_window_title()
	var context: WorkspaceContext = get_workspace_context(in_workspace)
	if !context.current_structure_context_changed.is_connected(_on_current_structure_context_changed):
		context.current_structure_context_changed.connect(_on_current_structure_context_changed)
	var view: WorkspaceMainView = context.workspace_main_view
	for docker: WorkspaceDocker in view.editor_dockers.values():
		docker._on_workspace_activated(in_workspace)
	if context != null:
		var wp_name: String = in_workspace.resource_path.get_basename()
		var molecular_editor: MolecularEditor = Editor_Utils.get_editor()
		molecular_editor.save_file_dialog.current_file = wp_name


func _on_current_structure_context_changed(_in_structure_context: StructureContext) -> void:
	var view: WorkspaceMainView = get_workspace_context(_current_workspace).workspace_main_view
	for docker: WorkspaceDocker in view.editor_dockers.values():
		docker._on_workspace_activated(_current_workspace)
		var container: DockerTabContainer = docker.get_container()
		if container != null:
			var current_tab: int = container.get_current_tab()
			if container.is_tab_hidden(current_tab):
				# Current tab is not hidden, find a better candidate
				for i in range(container.get_tab_count()):
					if !container.is_tab_hidden(i) and !container.is_tab_disabled(i):
						container.focus_tab(i)
						break


func _process(delta: float) -> void:
	if is_instance_valid(_current_workspace):
		var workspace_context: WorkspaceContext = get_workspace_context(_current_workspace)
		if is_instance_valid(workspace_context):
			workspace_context.update(delta)


func _update_window_title() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	var title: String = "MSEP.one"
	if workspace_context != null:
		var wp_name: String = workspace_context.workspace.get_user_friendly_name()
		title += " - " + wp_name
	get_tree().root.title = title


func _validate_forcefield_files(in_workspace_context: WorkspaceContext) -> void:
	if not is_instance_valid(in_workspace_context) or not is_instance_valid(in_workspace_context.workspace):
		return
	const OPTIONS: Dictionary = {
		VALID = 0,
		NOT_FOUND = 1,
		CHANGED = 2,
	}
	var forcefield: String = in_workspace_context.workspace.simulation_settings_forcefield
	var prev_forcefield_md5: String = in_workspace_context.workspace.simulation_settings_forcefield_md5
	var forcefield_md5: String = OpenMMUtils.hash_forcefield(forcefield)
	var forcefield_status: int = OPTIONS.VALID
	if forcefield_md5.is_empty():
		forcefield_status = OPTIONS.NOT_FOUND
	elif forcefield_md5 != prev_forcefield_md5:
		forcefield_status = OPTIONS.CHANGED
	var extension: String = in_workspace_context.workspace.simulation_settings_forcefield_extension
	var extension_status: int = OPTIONS.VALID
	if not extension.is_empty():
		var prev_extension_md5: String = in_workspace_context.workspace.simulation_settings_msep_extensions_md5
		var extension_md5: String = OpenMMUtils.hash_forcefield_extension(extension)
		if extension_md5.is_empty():
			extension_status = OPTIONS.NOT_FOUND
		elif extension_md5 != prev_extension_md5:
			extension_status = OPTIONS.CHANGED
	var messages: PackedStringArray = []
	match forcefield_status:
		OPTIONS.NOT_FOUND:
			# Forcefield file is missing
			messages.push_back(tr(&"The forcefield file '{forcefield}' is missing and cannot be used for this file simulation.\nDefault forcefield will be used in it's place."))
			in_workspace_context.workspace.simulation_settings_forcefield = OpenMMUtils.DEFAULT_FORCEFIELD
		OPTIONS.CHANGED:
			# Forcefield hace changed
			messages.push_back(tr(&"The contents of the forcefield file '{forcefield}' have changed since the last time this file was used.\nProceed with caution"))
	match extension_status:
		OPTIONS.NOT_FOUND:
			# Extension file is missing
			if OpenMMUtils.DEFAULT_FORCEFIELD_EXTENSION == "":
				# Extensions are disabled by default, make a proper message for this
				messages.push_back(tr(&"The extension forcefield file '{extension}' is missing and cannot be used for this file simulation.\nExtensions will be disabled."))
			else:
				messages.push_back(tr(&"The extension forcefield file '{extension}' is missing and cannot be used for this file simulation.\nDefault extension will be used in it's place."))
			in_workspace_context.workspace.simulation_settings_forcefield_extension = OpenMMUtils.DEFAULT_FORCEFIELD_EXTENSION
		OPTIONS.CHANGED:
			# Forcefield hace changed
			messages.push_back(tr(&"The contents of the forcefield extension file '{extension}' have changed since the last time this file was used.\nProceed with caution"))
	if messages.size() > 0:
		# We have some messages to show the user
		var format_arguments: Dictionary = {
			forcefield = forcefield,
			extension = extension,
		}
		var full_message: String = "\n\n".join(messages).format(format_arguments)
		in_workspace_context.show_warning_dialog(full_message, tr("OK"), "")

