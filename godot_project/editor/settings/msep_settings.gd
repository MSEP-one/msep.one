extends Resource
class_name MSEPSettings

const SETTINGS_RESOURCE_PATH = "user://editor/msep_settings.tres"

enum OpenMMLoggingReporters {
	PDBxReporter       = 1 << 0,
	PDBReporter        = 1 << 1,
	CheckpointReporter = 1 << 2,
	DCDReporter        = 1 << 3,
	StateDataReporter  = 1 << 4,
}
const ALL_REPORTS = \
	OpenMMLoggingReporters.PDBxReporter | \
	OpenMMLoggingReporters.PDBReporter | \
	OpenMMLoggingReporters.CheckpointReporter | \
	OpenMMLoggingReporters.DCDReporter | \
	OpenMMLoggingReporters.StateDataReporter

var _ui_sfx_bus_index: int =  AudioServer.get_bus_index(&"Ui Sfx")
@export var editor_sfx_enabled: bool = AudioServer.is_bus_mute(_ui_sfx_bus_index) :
	set = set_editor_sfx_enabled
@export var editor_sfx_volume_db: float = AudioServer.get_bus_volume_db(_ui_sfx_bus_index) :
	set = set_editor_sfx_volume_db
@export var editor_camera_camera_orbit_x_inverted: bool = false
@export var editor_camera_camera_orbit_y_inverted: bool = false
@export var editor_camera_orthographic_projection_enabled: bool = false:
	set = set_editor_camera_orthographic_projection_enabled
@export var editor_max_undo_count: int = 128:
	set = set_editor_max_undo_count
@export var custom_background_color: Color:
	set = set_custom_background_color
@export var custom_background_color_enabled: bool = false:
	set = set_custom_background_color_enabled
@export var custom_selection_outline_color: Color:
	set = set_custom_selection_outline_color
@export var custom_selection_outline_color_enabled: bool = false:
	set = set_custom_selection_outline_color_enabled
@export var ui_widget_scale: float = 1.0:
	set = set_ui_widget_scale
@export var openmm_server_allow_modified_script: bool = false:
	set = set_openmm_server_allow_modified_script
@export var is_simulation_logging_enabled: bool = false:
	set = set_is_simulation_logging_enabled,
	get = get_is_simulation_logging_enabled
@export var openmm_server_logs_path: String = _get_default_openmm_server_logs_path():
	set = set_openmm_server_logs_path
@export var openmm_server_logs_reporters: int = ALL_REPORTS:
	set = set_openmm_server_logs_reporters

var _simulation_logging_flag_file: String = String():
	get:
		if _simulation_logging_flag_file.is_empty():
			_simulation_logging_flag_file = OpenMMUtils.globalize_path("user://python/scripts/._log_enabled")
		return _simulation_logging_flag_file


func _init() -> void:
	if openmm_server_logs_path == _get_default_openmm_server_logs_path() and not DirAccess.dir_exists_absolute(openmm_server_logs_path):
		DirAccess.make_dir_recursive_absolute(openmm_server_logs_path)


func set_editor_sfx_enabled(in_value: bool) -> void:
	AudioServer.set_bus_mute(_ui_sfx_bus_index, !in_value)
	editor_sfx_enabled = in_value


func set_editor_sfx_volume_db(in_value_db: float) -> void:
	AudioServer.set_bus_volume_db(_ui_sfx_bus_index, in_value_db)
	editor_sfx_volume_db = in_value_db


func set_editor_max_undo_count(in_value: int) -> void:
	editor_max_undo_count = in_value
	changed.emit()


func set_custom_background_color(color: Color) -> void:
	custom_background_color = color
	changed.emit()


func set_custom_background_color_enabled(enabled: bool) -> void:
	custom_background_color_enabled = enabled
	changed.emit()


func set_custom_selection_outline_color(color: Color) -> void:
	custom_selection_outline_color = color
	changed.emit()


func set_custom_selection_outline_color_enabled(enabled: bool) -> void:
	custom_selection_outline_color_enabled = enabled
	changed.emit()


func set_ui_widget_scale(in_value: float) -> void:
	ui_widget_scale = in_value
	changed.emit()


func set_editor_camera_orthographic_projection_enabled(in_enabled: bool) -> void:
	editor_camera_orthographic_projection_enabled = in_enabled
	changed.emit()


func set_openmm_server_allow_modified_script(allow: bool) -> void:
	if openmm_server_allow_modified_script == allow:
		return
	openmm_server_allow_modified_script = allow
	changed.emit()


func get_is_simulation_logging_enabled() -> bool:
	return FileAccess.file_exists(_simulation_logging_flag_file)


func set_is_simulation_logging_enabled(in_enabled: bool) -> void:
	if in_enabled == is_simulation_logging_enabled:
		return
	is_simulation_logging_enabled = in_enabled
	if in_enabled:
		_create_or_update_simulation_logging_flag_file()
	else:
		_remove_simulation_logging_flag_file()


func _create_or_update_simulation_logging_flag_file() -> void:
	var base_dir: String = _simulation_logging_flag_file.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var flag_file: FileAccess = FileAccess.open(_simulation_logging_flag_file,FileAccess.WRITE)
	flag_file.store_string(openmm_server_logs_path + "\n")
	var active_reporters: PackedStringArray = []
	for reporter_name: StringName in OpenMMLoggingReporters.keys():
		if openmm_server_logs_reporters & OpenMMLoggingReporters[reporter_name]:
			active_reporters.append(reporter_name)
	var reporters_str: String = ",".join(active_reporters)
	flag_file.store_string(reporters_str)
	flag_file.flush()
	flag_file.close()


func _remove_simulation_logging_flag_file() -> void:
	var err: Error = DirAccess.remove_absolute(_simulation_logging_flag_file)
	assert(err == OK, "Failed to remove flag file with error: simulation_logging_enabled")


func set_openmm_server_logs_path(in_path: String) -> void:
	if openmm_server_logs_path == in_path:
		return
	openmm_server_logs_path = in_path
	if is_simulation_logging_enabled:
		_create_or_update_simulation_logging_flag_file()
	changed.emit()


func _get_default_openmm_server_logs_path() -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("msep.one/openmm_logs/")


func set_openmm_server_logs_reporters(in_reporters: int) -> void:
	if openmm_server_logs_reporters == in_reporters:
		return
	openmm_server_logs_reporters = in_reporters
	if is_simulation_logging_enabled:
		_create_or_update_simulation_logging_flag_file()
	changed.emit()


func save_settings() -> void:
	ResourceSaver.save(self, SETTINGS_RESOURCE_PATH, ResourceSaver.FLAG_CHANGE_PATH)
