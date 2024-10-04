class_name TrackableMutex extends RefCounted

var _name: String = ""
var _logging_enabled: bool = false
var _output_file_mutex := Mutex.new()
var _output_file: FileAccess = null
var _mutex := Mutex.new()

var LogColors: Dictionary = {
	ROYAL_BLUE = Color.ROYAL_BLUE.to_html(),
	FIREBRICK  = Color.FIREBRICK.to_html(),
	YELLOW     = Color.YELLOW.to_html()
}

func _init(in_name: String, in_log_enabled: bool = false) -> void:
	_name = in_name
	_logging_enabled = in_log_enabled
	_log("", "Created", LogColors.ROYAL_BLUE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(self):
		_log("", "DELETED", LogColors.FIREBRICK)

func set_output_file_path(in_path: String, in_append: bool = false) -> void:
	_output_file_mutex.lock()
	var path: String = ProjectSettings.globalize_path(in_path)
	_output_file = FileAccess.open(path, FileAccess.WRITE)
	if in_append:
		_output_file.seek_end()
	_output_file_mutex.unlock()


func set_output_file(in_file: FileAccess = null) -> void:
	_output_file_mutex.lock()
	_output_file = in_file
	_output_file_mutex.unlock()


func lock(in_context: String) -> void:
	_log("", "Lock-Request", LogColors.YELLOW, in_context)
	_mutex.lock()
	_log(">>\t", "Locked", LogColors.ROYAL_BLUE)


func unlock(in_context: String) -> void:
	_log("", "Unlock-Request", LogColors.YELLOW, in_context)
	_mutex.unlock()
	_log(">>\t", "Unocked", LogColors.ROYAL_BLUE)


func _log(in_prefix: String, in_message: String, in_color: String, in_context := String()) -> void:
	if not _logging_enabled:
		return
	var caller: int = OS.get_thread_caller_id()
	var main: int = OS.get_main_thread_id()
	var thread_desc: = "MAIN" if caller == main else str(caller)
	var msg: String = in_prefix + "Mutex " + _name + " " + in_message + " in thread " + thread_desc + \
			" at FRAME " + str(Engine.get_frames_drawn())
	if not in_context.is_empty():
		msg += " from: " + in_context
	if is_instance_valid(_output_file):
		_output_file_mutex.lock()
		_output_file.store_string(msg + "\n")
		_output_file_mutex.unlock()
	else:
		print_rich("[color=#%s]%s[/color]" % [in_color, msg])
