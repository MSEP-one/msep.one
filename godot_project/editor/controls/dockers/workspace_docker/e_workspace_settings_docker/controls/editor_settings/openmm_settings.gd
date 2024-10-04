extends DynamicContextControl


var _enable_logging_button: CheckButton
var _logging_reporters_tree: Tree
var _logs_folder_path_line_edit: LineEdit
var _logs_folder_open_button: Button
var _logs_folder_select_button: Button
var _logs_folder_dialog: NanoFileDialog
var _allow_edit_button: CheckButton
var _container_script_actions: HFlowContainer
var _button_edit_script: Button
var _button_open_location: Button
var _button_relaunch_server: Button



func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_enable_logging_button = %EnableLoggingButton as CheckButton
		_logging_reporters_tree = %LoggingReportersTree as Tree
		_logs_folder_path_line_edit = %LogsFolderPathLineEdit as LineEdit
		_logs_folder_open_button = %LogsFolderOpenButton as Button
		_logs_folder_select_button = %LogsFolderSelectButton as Button
		_logs_folder_dialog = %LogsFolderDialog as NanoFileDialog
		_allow_edit_button = %AllowEditButton as CheckButton
		_container_script_actions = %ContainerScriptActions as HFlowContainer
		_button_edit_script = %ButtonEditScript as Button
		_button_open_location = %ButtonOpenLocation as Button
		_button_relaunch_server = %ButtonRelaunchServer as Button
		# initialize
		_enable_logging_button.button_pressed = MolecularEditorContext.msep_editor_settings.is_simulation_logging_enabled
		_logging_reporters_tree.visible = _enable_logging_button.button_pressed
		_logs_folder_select_button.disabled = not _enable_logging_button.button_pressed
		MolecularEditorContext.msep_editor_settings.changed.connect(_on_msep_editor_settings_changed)
		_enable_logging_button.toggled.connect(_on_enable_logging_button_toggled)
		_initialize_reporters_list()
		_logging_reporters_tree.item_edited.connect(_on_logging_reporters_tree_item_edited)
		_logs_folder_open_button.pressed.connect(_on_logs_folder_open_button_pressed)
		_logs_folder_select_button.pressed.connect(_on_logs_folder_select_button_pressed)
		_logs_folder_dialog.dir_selected.connect(_on_logs_folder_dialog_dir_selected)
		_logs_folder_path_line_edit.text = MolecularEditorContext.msep_editor_settings.openmm_server_logs_path
		_allow_edit_button.button_pressed = OpenMM.utils.is_modification_of_server_script_allowed()
		_container_script_actions.visible = _allow_edit_button.button_pressed
		_allow_edit_button.toggled.connect(_on_allow_edit_button_toggled)
		_button_edit_script.pressed.connect(_on_button_edit_script_pressed)
		_button_open_location.pressed.connect(_on_button_open_location_pressed)
		_button_relaunch_server.pressed.connect(_on_button_relaunch_server_pressed)


func should_show(_in_workspace_context: WorkspaceContext)-> bool:
	return true


func _initialize_reporters_list() -> void:
	_logging_reporters_tree.clear()
	var root: TreeItem = _logging_reporters_tree.create_item()
	_logging_reporters_tree.hide_root = true
	const COLUMN_0 = 0
	var enabled_reporters: int = MolecularEditorContext.msep_editor_settings.openmm_server_logs_reporters
	for reporter_name: StringName in MSEPSettings.OpenMMLoggingReporters.keys():
		var reporter_id: int = MSEPSettings.OpenMMLoggingReporters[reporter_name]
		var item: TreeItem = _logging_reporters_tree.create_item(root)
		item.set_cell_mode(COLUMN_0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COLUMN_0, true)
		item.set_metadata(COLUMN_0, reporter_id)
		item.set_text(COLUMN_0, reporter_name)
		var is_report_enabled: bool = reporter_id & enabled_reporters
		item.set_checked(COLUMN_0, is_report_enabled)

func _on_enable_logging_button_toggled(in_button_pressed: bool) -> void:
	MolecularEditorContext.msep_editor_settings.is_simulation_logging_enabled = in_button_pressed
	_logging_reporters_tree.visible = in_button_pressed
	_logs_folder_select_button.disabled = not in_button_pressed


func _on_msep_editor_settings_changed() -> void:
	_enable_logging_button.set_pressed_no_signal(MolecularEditorContext.msep_editor_settings.is_simulation_logging_enabled)
	_allow_edit_button.button_pressed = OpenMM.utils.is_modification_of_server_script_allowed()


func _on_logging_reporters_tree_item_edited() -> void:
	var root: TreeItem = _logging_reporters_tree.get_root()
	var new_enabled_reporters: int = 0
	const COLUMN_0 = 0
	for item: TreeItem in root.get_children():
		if item.is_checked(COLUMN_0):
			var reporter_id: int = item.get_metadata(COLUMN_0)
			new_enabled_reporters |= reporter_id
	MolecularEditorContext.msep_editor_settings.openmm_server_logs_reporters = new_enabled_reporters
	MolecularEditorContext.msep_editor_settings.save_settings()


func _on_logs_folder_open_button_pressed() -> void:
	var logs_path: String = MolecularEditorContext.msep_editor_settings.openmm_server_logs_path
	if DirAccess.dir_exists_absolute(logs_path):
		OS.shell_show_in_file_manager(logs_path, true)


func _on_logs_folder_select_button_pressed() -> void:
	var logs_path: String = MolecularEditorContext.msep_editor_settings.openmm_server_logs_path
	_logs_folder_dialog.current_dir = logs_path.get_base_dir()
	_logs_folder_dialog.current_file = logs_path.get_file()
	_logs_folder_dialog.popup_centered_ratio()


func _on_logs_folder_dialog_dir_selected(in_path: String) -> void:
	_logs_folder_path_line_edit.text = in_path
	MolecularEditorContext.msep_editor_settings.openmm_server_logs_path = in_path
	MolecularEditorContext.msep_editor_settings.save_settings()


func _on_allow_edit_button_toggled(in_button_pressed: bool) -> void:
	MolecularEditorContext.msep_editor_settings.openmm_server_allow_modified_script = in_button_pressed
	MolecularEditorContext.msep_editor_settings.save_settings()
	_container_script_actions.visible = in_button_pressed


func _on_button_edit_script_pressed() -> void:
	var script_path: String = OpenMM.utils.get_server_script_absolute_path()
	if FileAccess.file_exists(script_path):
		OS.shell_open(script_path)


func _on_button_open_location_pressed() -> void:
	var script_path: String = OpenMM.utils.get_server_script_absolute_path()
	if FileAccess.file_exists(script_path):
		OS.shell_show_in_file_manager(script_path)


func _on_button_relaunch_server_pressed() -> void:
	OpenMM.relaunch_openmm_server()

