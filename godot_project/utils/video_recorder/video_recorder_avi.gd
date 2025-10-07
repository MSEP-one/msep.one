"@abstract_class"
class_name VideoRecorderAVI extends VideoRecorder

var _filename: String
var _resolution: Vector2i
var _fps: int = 30
var _w: RiffFileWriter = null
var _error: String = ""
var _quality: float = 0.75
var _total_frames_pos: PackedInt32Array = [0,0,0,0]
var _jpg_frame_start: PackedInt32Array = []
var _jpg_frame_size: PackedInt32Array = []
var _frame_count: int = 0


func _init(in_filename: String, in_resolution: Vector2i, in_fps: int = 30) -> void:
	assert(in_filename.is_absolute_path() and in_filename.get_extension().to_lower() == "avi",
		"This video recorder (%s) cannot write this file format (%s)" %
		[get_script().resource_path, in_filename.get_extension()])
	assert(in_fps > 0, "Invalid framerate")
	_filename = in_filename
	_resolution = in_resolution
	_fps = in_fps
	_write_begin()


static func get_file_format_filters() -> PackedStringArray:
	return ["*.avi ; FMPEG encoded video (AVI)"]


func is_running() -> bool:
	return is_instance_valid(_w)


func is_converting() -> bool:
	return false


func abort() -> void:
	if _w == null:
		return
	var f: FileAccess = _w.get_file_access()
	f.close()
	var err: Error = DirAccess.remove_absolute(_filename)
	if err != OK:
		push_error("Failed to delete ", _filename, " with error ", error_string(err))
	_w = null


func has_error() -> bool:
	return not _error.is_empty()


func get_error() -> String:
	return _error


func set_quality(in_quality: float) -> void:
	if _frame_count != 0:
		push_warning("Quality changed in middle of file writing, this is not recommended")
	_quality = in_quality


func add_frame(in_image: Image) -> void:
	_write_frame(in_image)

func finish() -> void:
	_write_end()

func _write_begin() -> void:
	if not DirAccess.dir_exists_absolute(_filename.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(_filename.get_base_dir())

	_w = RiffFileWriter.new(_filename, "AVI ")
	if not _w.is_file_valid():
		_error = "Failed to open file with write permissions: " + _filename
		push_error(_error)
		return
	_w.push_list_start("hdrl")
	_w.push_block("avih")
	
	@warning_ignore("integer_division")
	_w.store_32(int(1000000 / _fps)) # Microsecs per frame.
	_w.store_32(7000) # Max bytes per second
	_w.store_32(0) # Padding Granularity
	_w.store_32(16)
	_total_frames_pos[0] = _w.get_position()
	_w.store_32(0) # Total frames (update later)
	_w.store_32(0) # Initial frames
	_w.store_32(1) # Streams
	_w.store_32(0) # Suggested buffer size
	_w.store_32(_resolution.x) # Movie Width
	_w.store_32(_resolution.y) # Movie Height
	for i in 4:
		_w.store_32(0) # Reserved.
	_w.pop_block() # [/avih]
	
	_w.push_list_start("strl")
	_w.push_block("strh")
	_w.store_four_cc("vids")
	_w.store_four_cc("MJPG")
	_w.store_32(0) # Flags
	_w.store_16(0) # Priority
	_w.store_16(0) # Language
	_w.store_32(0) # Initial Frames
	_w.store_32(1) # Scale
	_w.store_32(_fps) # FPS
	_w.store_32(0) # Start
	_total_frames_pos[1] = _w.get_position()
	_w.store_32(0) # Number of frames (to be updated later)
	_w.store_32(0) # Suggested Buffer Size
	_w.store_32(0) # Quality
	_w.store_32(0) # Sample Size
	_w.pop_block() # [/vids]
	
	_w.push_block("strf")
	_w.store_32(40) # Size.
	
	_w.store_32(_resolution.x) # Movie Width
	_w.store_32(_resolution.y) # Movie Height
	_w.store_16(1) # Planes
	_w.store_16(24) # Bitcount
	_w.store_four_cc("MJPG") # Compression
	
	@warning_ignore("integer_division")
	_w.store_32((int(_resolution.x * 24 / 8 + 3) & 0xFFFFFFFC) * _resolution.y) # SizeImage
	_w.store_32(0) # XPelsXMeter
	_w.store_32(0) # YPelsXMeter
	_w.store_32(0) # ClrUsed
	_w.store_32(0) # ClrImportant
	_w.pop_block() # [/strf]
	
	_w.push_list_start("odml")
	
	_w.push_block("dmlh")

	_total_frames_pos[2] = _w.get_position()
	_w.store_32(0) # Number of frames (to be updated later)
	
	_w.pop_block() # [/dmlh]
	_w.pop_block() # [/LIST odml]
	
	_w.pop_block() # [/LIST strl]
	
	# Skipped audio header!
	
	_w.pop_block() # [/LIST hdrl]
	
	_total_frames_pos[3] = _w.get_position()
	_w.push_list_start("movi")


func _write_frame(in_image: Image) -> void:
	assert(is_instance_valid(_w), "File doesn't exists, cannot inject frame data")
	var jpeg_buffer: PackedByteArray = in_image.save_jpg_to_buffer(_quality)
	var buffer_size: int = jpeg_buffer.size()
	
	_jpg_frame_start.append(_w.get_position())
	_w.store_four_cc("00db") # Stream 0, Video
	_w.store_32(jpeg_buffer.size())
	_w.store_buffer(jpeg_buffer)
	if buffer_size & 1:
		# padding correction
		_w.store_8(0)
		buffer_size += 1
	_jpg_frame_size.append(buffer_size)
	
	# Skipped audio block
	
	_frame_count += 1

func _write_end() -> void:
	assert(is_instance_valid(_w) and _w.is_file_valid(), "File doesn't exists, cannot inject frame data")
	_w.pop_block() # [/movi]
	
	_w.push_block("idx1")
	var movi_block_start_pos: int = _total_frames_pos[3] + 8
	for i in _frame_count:
		_w.store_four_cc("00db")
		_w.store_32(16) # AVI_KEYFRAME
		_w.store_32(_jpg_frame_start[i] - movi_block_start_pos)
		_w.store_32(_jpg_frame_size[i])
	_w.pop_block() # [/idx1]
	_w.pop_block() # [/RIFF]

	# Post process: store frame count in relevant bytes
	var f: FileAccess = _w.get_file_access()
	for i in 3:
		f.seek(_total_frames_pos[i])
		f.store_32(_frame_count)
	
	f.close()
	_w = null
