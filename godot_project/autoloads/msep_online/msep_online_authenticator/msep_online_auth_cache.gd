class_name MsepOnlineAuthCache extends RefCounted
## Responsible for storing the MSEP Online session in an encrypted file between runs of the app.


const AUTH_CACHE_DIR: String = "user://msep.one/"
const AUTH_CACHE_FILE: String = AUTH_CACHE_DIR + "auth"
const AUTH_CACHE_IV: String = AUTH_CACHE_FILE + ".iv"
const IV_LENGTH: int = 16


static func exists() -> bool:
	return FileAccess.file_exists(AUTH_CACHE_FILE) and FileAccess.file_exists(AUTH_CACHE_IV)


## Returns the stored session, or an empty dictionary when the file cannot be decrypted.
## It holds auth_token, refresh_token, auth_uuid, username, expire_time (unix time the auth token
## expires), avatar (Texture2D, null when none) and user_public_data (the profile).
static func read() -> Dictionary:
	var encrypt_key: PackedByteArray = _get_encryption_key()
	assert(encrypt_key.size() == 32)
	var iv: PackedByteArray = FileAccess.get_file_as_bytes(AUTH_CACHE_IV)
	var auth_file: FileAccess = FileAccess.open_encrypted(AUTH_CACHE_FILE, FileAccess.READ, encrypt_key, iv)
	if auth_file == null:
		push_error("Failed to load encrypted auth file. ", error_string(FileAccess.get_open_error()))
		return {}
	var auth_token: String = auth_file.get_pascal_string()
	var refresh_token: String = auth_file.get_pascal_string()
	var auth_uuid: String = auth_file.get_pascal_string()
	var username: String = auth_file.get_pascal_string()
	var expire_time: float = auth_file.get_float()
	var avatar: Texture2D = null
	var avatar_buffer_length: int = auth_file.get_64()
	if avatar_buffer_length > 0:
		var avatar_buffer: PackedByteArray = auth_file.get_buffer(avatar_buffer_length)
		var img: Image = Image.new()
		img.load_png_from_buffer(avatar_buffer)
		avatar = ImageTexture.create_from_image(img)
	var public_data_json: String = auth_file.get_pascal_string()
	var user_public_data: Dictionary = {} if public_data_json.is_empty() else JSON.parse_string(public_data_json)
	assert(auth_file.get_position() == auth_file.get_length(), "authentication file has more bytes than expected!")
	return {
		"auth_token": auth_token,
		"refresh_token": refresh_token,
		"auth_uuid": auth_uuid,
		"username": username,
		"expire_time": expire_time,
		"avatar": avatar,
		"user_public_data": user_public_data,
	}


static func _get_encryption_key() -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = OS.get_unique_id().md5_text().hash()
	var key := PackedByteArray()
	for i: int in 32:
		key.append(rng.randi_range(0, 255))
	return key


## Stores a session. Returns false when a file could not be written.
static func write(in_session: Dictionary) -> bool:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(AUTH_CACHE_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUTH_CACHE_DIR))
	var encrypt_key: PackedByteArray = _get_encryption_key()
	var iv: PackedByteArray = _generate_initialization_vector(IV_LENGTH)
	# Write IV file
	var iv_file := FileAccess.open(AUTH_CACHE_IV, FileAccess.WRITE)
	if iv_file == null:
		push_error("Failed to open auth.iv file with write permissions. ", error_string(FileAccess.get_open_error()))
		return false
	iv_file.store_buffer(iv)
	iv_file.close()
	# Write auth file
	var auth_file: FileAccess = FileAccess.open_encrypted(AUTH_CACHE_FILE, FileAccess.WRITE, encrypt_key, iv)
	if auth_file == null:
		push_error("Failed to open encrypted auth file with write permissions. ",
				error_string(FileAccess.get_open_error()))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_CACHE_IV))
		return false
	auth_file.store_pascal_string(in_session["auth_token"])
	auth_file.store_pascal_string(in_session["refresh_token"])
	auth_file.store_pascal_string(in_session["auth_uuid"])
	auth_file.store_pascal_string(in_session["username"])
	auth_file.store_float(in_session["expire_time"])
	var avatar: Texture2D = in_session["avatar"]
	if avatar == null:
		var avatar_buffer_length: int = 0
		auth_file.store_64(avatar_buffer_length)
	else:
		var avatar_buffer: PackedByteArray = avatar.get_image().save_png_to_buffer()
		var avatar_buffer_length: int = avatar_buffer.size()
		auth_file.store_64(avatar_buffer_length)
		auth_file.store_buffer(avatar_buffer)
	var public_data_json: String = JSON.stringify(in_session["user_public_data"], "", false)
	auth_file.store_pascal_string(public_data_json)
	auth_file.close()
	return true


static func _generate_initialization_vector(in_iv_length: int) -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var iv := PackedByteArray()
	for i: int in in_iv_length:
		iv.append(rng.randi_range(0, 255))
	return iv


static func remove() -> void:
	if FileAccess.file_exists(AUTH_CACHE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_CACHE_FILE))
	if FileAccess.file_exists(AUTH_CACHE_IV):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_CACHE_IV))
