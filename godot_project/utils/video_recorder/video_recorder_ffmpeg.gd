class_name  VideoRecorderFFMPEG extends VideoRecorder


var _filename: String
var _resolution: Vector2i
var _fps: int = 30
var _error: String = ""
var _pipe: FileAccess
var _pid: int
#var _thread: Thread
#var _queue: Array[Image]

# Note: These behaves as constants, but cannot be constants because of OS.get_name() access
static var _is_windows: bool = OS.get_name().to_lower() == "windows"
static var _cmd: String = "ffmpeg.exe" if _is_windows else "ffmpeg"

static func is_available() -> bool:
	var a: int = OS.execute(_cmd, [])
	return a >= 0


func _init(in_filename: String, in_resolution: Vector2i, in_fps: int = 30) -> void:
	if not is_available():
		_error = "FFMPEG not installed in the system"
		push_error(_error)
		return
	assert(in_fps > 0, "Invalid framerate")
	_filename = in_filename
	_resolution = in_resolution
	_fps = in_fps
	#_thread = Thread.new()
	#_thread.start(_start_in_thread)
	_start_in_thread()

func has_error() -> bool:
	return not _error.is_empty()


func is_running() -> bool:
	return _pid != 0 and OS.is_process_running(_pid)

func get_error() -> String:
	return _error


func add_frame(in_image: Image) -> void:
	_write_frame(in_image)

func finish() -> void:
	_write_end()

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
		"-preset", "veryfast",
		"-crf", "23",
		"-movflags", "+faststart",
		"-an",
		_filename
	]
	print_verbose("ffmpeg command:")
	print_verbose(_cmd, " ", " ".join(arguments))
	var pipe: Dictionary = OS.execute_with_pipe(_cmd, arguments, true)
	_pipe = pipe.stdio
	var stderr: FileAccess = pipe.stderr
	_error = stderr.get_as_text()
	if has_error():
		push_error(_error)
		_pipe.close()
		stderr.close()
	else:
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
