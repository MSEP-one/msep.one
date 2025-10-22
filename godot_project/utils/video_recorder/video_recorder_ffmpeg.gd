class_name  VideoRecorderFFMPEG extends VideoRecorder


var _filename: String
var _resolution: Vector2i
var _fps: int = 30
var _error: String = ""
var _pipe: FileAccess
var _err_pipe: FileAccess
var _pid: int
var _converting: bool = false
var _preset: String = "fast"
var _crf: int = 17
#var _thread: Thread
#var _queue: Array[Image]

# Note: These behaves as constants, but cannot be constants because of OS.get_name() access
static var _is_windows: bool = OS.get_name().to_lower() == "windows"
static var _cmd: String:
	get():
		if _cmd.is_empty():
			if _is_windows:
				_cmd = "ffmpeg.exe"
			else:
				var out := Array()
				var exit_code: int = OS.execute("bash", ["-l", "-c", "which ffmpeg"], out)
				_cmd = "" if exit_code != 0 else str(out[0]).rstrip("\n")
				if _cmd.is_empty():
					# bash could not find the path, MacOS could be using zsh
					exit_code = OS.execute("zsh", ["-l", "-c", "which ffmpeg"], out)
					_cmd = "" if exit_code != 0 else str(out[0]).rstrip("\n")
		return _cmd

static func is_available() -> bool:
	if _cmd.is_empty():
		return false
	var a: int = OS.execute(_cmd, [])
	return a >= 0


func _init(in_filename: String, in_resolution: Vector2i, in_fps: int = 30, in_preset: String = "fast", in_crf: int = 17) -> void:
	if not is_available():
		_error = "FFMPEG not installed in the system"
		push_error(_error)
		return
	assert(in_fps > 0, "Invalid framerate")
	_filename = in_filename
	_resolution = in_resolution
	_fps = in_fps
	_preset = in_preset
	_crf = in_crf
	#_thread = Thread.new()
	#_thread.start(_start_in_thread)
	_start_in_thread()


static func get_file_format_filters() -> PackedStringArray:
	return [
		"*.mp4 ; MPEG-4 Part 14 (MP4)",
		"*.avi ; FMPEG encoded video (AVI)",
	]


func is_running() -> bool:
	return _pid != 0 and OS.is_process_running(_pid)


func is_converting() -> bool:
	return _converting


func abort() -> void:
	if not is_running():
		return
	OS.kill(_pid)
	_dispose_video_file(_pid, _filename)

static func _dispose_video_file(child_pid: int, filename: String) -> void:
	while OS.is_process_running(child_pid):
		await Engine.get_main_loop().process_frame
	var err: Error = ERR_FILE_NOT_FOUND
	var i := 0
	while err != OK and i < 10:
		err = DirAccess.remove_absolute(filename)
		i += 1
		await Engine.get_main_loop().physics_frame
	if err != OK:
		push_error("Failed to delete ", filename, " with error '", error_string(err), "'")


func has_error() -> bool:
	return not _error.is_empty()


func get_error() -> String:
	return _error


func _flush_pipes() -> void:
	if _err_pipe.get_length() > 0:
		_error = _err_pipe.get_as_text()
		print_verbose("ffmpeg error: ", _error)
	if _pipe.get_length() > 0:
		print_verbose("ffmpeg output: ", _pipe.get_as_text())


func add_frame(in_image: Image) -> void:
	_flush_pipes()
	_write_frame(in_image)


func finish() -> void:
	_write_end()
	_converting = true


func _start_in_thread() -> void:
	var arguments: PackedStringArray = [
		"-y",
		"-f", "rawvideo",
		"-pixel_format", "rgb24",
		"-video_size", "%dx%d" % [_resolution.x, _resolution.y],
		"-framerate", str(_fps),
		"-i", "pipe:0",
		"-c:v", "libx264",
		"-pix_fmt", "yuv420p",
		"-preset", _preset,
		"-crf", str(_crf),
		"-movflags", "+faststart",
		"-an",
		_filename
	]
	print_verbose("ffmpeg command:")
	print_verbose(_cmd, " ", " ".join(arguments))
	var pipe: Dictionary = OS.execute_with_pipe(_cmd, arguments, true)
	_pipe = pipe.stdio
	_pid = pipe.pid
	_err_pipe = pipe.stderr
	print_verbose("Started recording ", _filename)


func _write_frame(in_image: Image) -> void:
	if in_image.get_format() != Image.FORMAT_RGB8:
		in_image.convert(Image.FORMAT_RGB8)
	if not in_image.get_size() == _resolution:
		push_warning("Resolution missmatch, will resize frame")
		in_image.resize(_resolution.x, _resolution.y, Image.INTERPOLATE_BILINEAR)
	var buffer: PackedByteArray = in_image.get_data()
	_pipe.store_buffer(buffer)


func _write_end() -> void:
	_pipe.close()
	print_verbose("Finished recording ", _filename)
