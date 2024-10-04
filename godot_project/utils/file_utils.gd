class_name FileUtils extends RefCounted

static func calculate_file_hash(in_file_path: String) -> String:
	var file_access: FileAccess = FileAccess.open(in_file_path, FileAccess.ModeFlags.READ)
	if not is_instance_valid(file_access):
		return ""
	
	var hasher: HashingContext = HashingContext.new()
	hasher.start(HashingContext.HASH_MD5)
	
	while not file_access.eof_reached():
		var chunk: PackedByteArray = file_access.get_buffer(4096)  # Read in chunks of 4KB
		hasher.update(chunk)
	
	file_access.close()
	return hasher.finish().hex_encode()


static func copy_file_from_to(in_source_path: String, in_destination_path: String) -> void:
	var file := FileAccess.open(in_source_path, FileAccess.READ)
	var data := file.get_buffer(file.get_length())
	file.close()
	
	file = FileAccess.open(in_destination_path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()
