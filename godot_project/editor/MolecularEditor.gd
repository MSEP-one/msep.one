extends Node
class_name MolecularEditor


signal load_workspace_confirmed(in_path: String)
signal save_workspace_confirmed(in_workspace: Workspace, in_path: String)


const WINDOW_MINIMUM_SIZE := Vector2i(930, 560)
const EditorLayoutSettings = preload("res://editor/controls/dockers/EditorLayoutSettings.gd")

var editor_layout: EditorLayoutSettings


var menu_bar: MenuBar
var import_file_dialog: ImportFileDialog
var load_file_dialog: NanoFileDialog
var save_file_dialog: NanoFileDialog
var template_library_dialog: TemplateLibraryDialog
var camera_position_dialog: AcceptDialog

var _wait_before_close_dlg: AcceptDialog


func _enter_tree() -> void:
	add_to_group(&"__MSEP_EDITOR__")


func _shortcut_input(in_event: InputEvent) -> void:
	Editor_Utils.process_quit_request(in_event, get_viewport())


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		menu_bar = %MenuBar
		import_file_dialog = %ImportFileDialog as ImportFileDialog
		load_file_dialog = %LoadFileDialog as NanoFileDialog
		save_file_dialog = %SaveFileDialog as NanoFileDialog
		template_library_dialog = $TemplateLibraryDialog
		camera_position_dialog = %CameraPositionDialog
		DisplayServer.window_set_min_size(WINDOW_MINIMUM_SIZE)
		load_editor_layout()
		EditorSfx.register_window(import_file_dialog)
		EditorSfx.register_window(load_file_dialog)
		EditorSfx.register_window(save_file_dialog)
		load_file_dialog.file_selected.connect(_on_load_file_dialog_file_selected)
		save_file_dialog.file_selected.connect(_on_save_file_dialog_file_selected)
		import_file_dialog.ok_button_text = tr(&"Import")
		var documents_path: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		load_file_dialog.current_dir = documents_path
		save_file_dialog.current_dir = documents_path
		import_file_dialog.current_dir = documents_path
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if BusyIndicator.visible:
			if not is_instance_valid(_wait_before_close_dlg):
				_wait_before_close_dlg = prompt_error_msg(tr(&"Please wait for the current operation to complete before closing the application."))
				BusyIndicator.visibility_changed.connect(_wait_before_close_dlg.queue_free, CONNECT_DEFERRED)
			return
		var open_workspaces: Array[Workspace] = MolecularEditorContext.get_open_workspaces()
		var is_unsaved: Callable = func(in_workspace: Workspace) -> bool:
			var context: WorkspaceContext = MolecularEditorContext.get_workspace_context(in_workspace) as WorkspaceContext
			return context.has_unsaved_changes()
		var unsaved_workspaces: Array[Workspace] = open_workspaces.filter(is_unsaved)
		# resume_signal is used when saving a workspace is complete or skiped
		for workspace in unsaved_workspaces:
			var save_promise := Promise.new()
			var on_discard_unsaved_changes: Callable = func() -> void:
				# Accepted to not save changes, just continue with the next workspace
				save_promise.fulfill("resume")
			var on_saved: Callable = func(out_workspace: Workspace) -> void:
				# Promise is fulfilled if workspace is saved
				if workspace == out_workspace:
					save_promise.fulfill("resume")
			var on_save_dialog_canceled: Callable = func() -> void:
				# Save dialog was canceled, cancel closing the applicaiton
				save_promise.fulfill("abort")
			var on_abort: Callable = func() -> void:
				save_promise.fulfill("abort")
			var save_and_resume: Callable = func() -> void:
				MolecularEditorContext.workspace_saved.connect(on_saved)
				save_file_dialog.canceled.connect(on_save_dialog_canceled)
				MolecularEditorContext.save_workspace(workspace)
			show_close_workspace_confirmation_dialog(workspace.get_user_friendly_name(), on_discard_unsaved_changes, save_and_resume, on_abort)
			await save_promise.wait_for_fulfill()
			if MolecularEditorContext.workspace_saved.is_connected(on_saved):
				MolecularEditorContext.workspace_saved.disconnect(on_saved)
			if save_file_dialog.canceled.is_connected(on_save_dialog_canceled):
				save_file_dialog.canceled.disconnect(on_save_dialog_canceled)
			var result: String = save_promise.get_result()
			match result:
				"resume":
					# Nothing to do here
					pass
				"abort":
					# Cancel quit
					return
				_:
					assert(false, "Unexpected save_promise result! " + result)
		# All saved or skiped, ready to quit
		get_tree().quit(0)


func _on_load_file_dialog_file_selected(in_path: String) -> void:
	if !in_path.is_empty():
		if in_path.get_extension().to_lower() != "msep1":
			# Users can type any file name and press Intro
			# This will prevent attempting to open non workspace files
			prompt_error_msg(tr("Invalid workspace file:\n>>\t") + in_path)
			return
		load_workspace_confirmed.emit(in_path)


func _on_save_file_dialog_file_selected(in_path: String) -> void:
	if !in_path.is_empty():
		var workspace: WeakRef = save_file_dialog.get_meta(&"__workspace__", null)
		assert(workspace.get_ref() != null and workspace.get_ref() is Workspace,
			"Workspace is invalid, cannot save")
		save_workspace_confirmed.emit(workspace.get_ref(), in_path)


func show_open_workspace_dialog() -> void:
	load_file_dialog.popup_centered_ratio(0.5)


func show_save_workspace_dialog(in_workspace: Workspace) -> void:
	save_file_dialog.set_meta(&"__workspace__", weakref(in_workspace))
	if not in_workspace.suggested_path.is_empty():
		save_file_dialog.current_path = in_workspace.suggested_path
	save_file_dialog.popup_centered_ratio(0.5)


func show_close_workspace_confirmation_dialog(
	in_workspace_name: String,
	in_confirm_callback: Callable,
	in_save_callback: Callable = Callable(),
	in_cancel_callback: Callable = Callable()) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Close workspace"
	dlg.dialog_text = "Are you sure you want to close '%s'?\n" % in_workspace_name + \
						"All unsaved changes will be lost."
	dlg.confirmed.connect(in_confirm_callback)
	dlg.confirmed.connect(dlg.queue_free)
	if in_cancel_callback.is_valid():
		dlg.canceled.connect(in_cancel_callback)
	dlg.canceled.connect(dlg.queue_free)
	if in_save_callback.is_valid():
		dlg.add_button(tr("Save"), false, "Save")
	dlg.custom_action.connect(_on_close_workspace_dialog_custom_action.bind(dlg, in_save_callback))
	add_child(dlg)
	dlg.popup_centered()


func _on_close_workspace_dialog_custom_action(in_action: String, out_dlg: ConfirmationDialog, in_save_callback: Callable) -> void:
	match in_action:
		"Save":
			assert(in_save_callback.is_valid(), "Cannot execute invalid save callback")
			in_save_callback.call()
		_:
			assert(false, "Unexpected action in close workspace confirm dialog! " + in_action)
	if is_instance_valid(out_dlg):
		out_dlg.queue_free()

const LAYOUTS_FOLDER = "user://editor/layouts/"
const LATEST_LAYOUT_FILE   = "__latest__"
func load_editor_layout(in_name: String = "") -> void:
	var filename: String = LATEST_LAYOUT_FILE if in_name.is_empty() else in_name
	var path: String = LAYOUTS_FOLDER + filename + ".res"
	if !ResourceLoader.exists(path):
		if in_name.is_empty():
			# LATEST_LAYOUT_FILE does not exist, create it
			editor_layout = EditorLayoutSettings.new()
			save_editor_layout(editor_layout, LATEST_LAYOUT_FILE)
		else:
			push_error("Failed to load layout '%s'" % in_name)
		return
	var layout_settings: EditorLayoutSettings = load(path)
	if layout_settings == null:
		push_error("Failed to load layout '%s'" % in_name)
		return
	editor_layout = layout_settings.duplicate()
	editor_layout.changed.connect(save_editor_layout.bind(editor_layout))


func save_editor_layout(in_layout_settings: EditorLayoutSettings, in_name: String = "") -> void:
	# Ensure directory exists
	var d: DirAccess = DirAccess.open("user://")
	if d != null:
		d.make_dir_recursive(LAYOUTS_FOLDER)
	if !is_instance_valid(in_layout_settings):
		return
	var filename: String = LATEST_LAYOUT_FILE if in_name.is_empty() else in_name
	var path: String = LAYOUTS_FOLDER + filename + ".res"
	ResourceSaver.save(in_layout_settings, path)


func prompt_error_msg(in_error_msg: String) -> AcceptDialog:
	var dlg := AcceptDialog.new()
	dlg.size.x = Engine.get_main_loop().root.size.x * 0.4
	dlg.title = tr(&"Failed")
	dlg.dialog_text = in_error_msg
	dlg.dialog_autowrap = true
	BusyIndicator.add_child(dlg)
	dlg.popup_centered()
	dlg.visibility_changed.connect(dlg.queue_free, CONNECT_DEFERRED)
	return dlg
