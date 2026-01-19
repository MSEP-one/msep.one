@tool
class_name MsepOnlineAuthenticator extends Node


signal logged_in()
signal avatar_loaded()
signal authentication_failed()
signal logged_out()


const AUTH_CACHE_DIR: String = "user://msep.one/"
const AUTH_CACHE_FILE: String = AUTH_CACHE_DIR + "auth"
const AUTH_CACHE_IV: String = AUTH_CACHE_FILE + ".iv"


@export_group("Tests")
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var test_name: String:
	set(v):
		test_name = v
		generated_color = _gen_avatar_background_color(test_name)
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var generated_color: Color
@export_tool_button("Randomize Name") var test_button: Callable = _randomize_test_name
func _randomize_test_name() -> void:
	test_name = _generate_initialization_vector(10).get_string_from_ascii()
@export_group("")


var _is_authenticated: bool = false
var _auth_token: String = ""
var _refresh_token: String = ""
var _username: String = ""
var _avatar_background_color := Color.BLACK
var _avatar: Texture2D = null
var _user_public_data: Dictionary


func _init() -> void:
	if Engine.is_editor_hint():
		return
	_initialize_deferred.call_deferred()


func _initialize_deferred() -> void:
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_MSEP_ONLINE):
		_authenticate_from_cache()
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)


func get_username() -> String:
	return _username if _is_authenticated else ""


func get_avatar() -> Texture2D:
	return _avatar if _is_authenticated else null


func get_avatar_background_color() -> Color:
	return _avatar_background_color if _is_authenticated else Color.BLACK


func get_user_public_data() -> Dictionary:
	return _user_public_data.duplicate(true) if _is_authenticated else {}


func _authenticate_from_cache() -> void:
	if FileAccess.file_exists(AUTH_CACHE_FILE) and FileAccess.file_exists(AUTH_CACHE_IV):
		var encrypt_key: PackedByteArray = _get_encryption_key()
		assert(encrypt_key.size() == 32)
		var iv: PackedByteArray = FileAccess.get_file_as_bytes(AUTH_CACHE_IV)
		var auth_file: FileAccess = FileAccess.open_encrypted(AUTH_CACHE_FILE, FileAccess.READ, encrypt_key, iv)
		if auth_file == null:
			_clear_authentication()
			push_error("Failed to load encrypted auth file. ", error_string(FileAccess.get_open_error()))
			return
		_is_authenticated = true
		_auth_token = auth_file.get_pascal_string()
		_refresh_token = auth_file.get_pascal_string()
		_username = auth_file.get_pascal_string()
		_avatar_background_color = _gen_avatar_background_color(_username)
		var avatar_buffer_length: int = auth_file.get_64()
		if avatar_buffer_length > 0:
			var avatar_buffer: PackedByteArray = auth_file.get_buffer(avatar_buffer_length)
			var img: Image = Image.new()
			img.load_png_from_buffer(avatar_buffer)
			_avatar = ImageTexture.create_from_image(img)
		else:
			_avatar = null
		var public_data_json: String = auth_file.get_pascal_string()
		_user_public_data = {} if public_data_json.is_empty() else JSON.parse_string(public_data_json)
		assert(auth_file.get_position() == auth_file.get_length(), "authentication file has more bytes than expected!")
		logged_in.emit()
		_revalidate_tokens()
	else:
		_clear_authentication()


func _revalidate_tokens() -> void:
	# TODO: use http request to revalidate auth and refresh tokens
	if _auth_token == "abcd" and _refresh_token == "abcd":
		print("Tokens are valid. Welcome ", _username)
		return
	else:
		_clear_authentication()
		logged_out.emit()


func is_authenticated() -> bool:
	return _is_authenticated


func get_authentication_headers() -> PackedStringArray:
	if is_authenticated():
		return ["Bearer: " + _auth_token]
	return []


func login(in_username: String, in_password: String) -> Promise:
	var promise: Promise = AuthenticationPromise.new(self)
	# Arguments could change in the future
	# For now any password equal to the username in lower case will work
	if not OS.is_debug_build():
		# FIXME: Delete this when real authentication is implemented
		push_error("Authentication is not implemented!")
		authentication_failed.emit()
		return promise
	if in_password == in_username.to_lower():
		_is_authenticated = true
		_auth_token = "abcd"
		_refresh_token = "abcd"
		_username = in_username
		_avatar_background_color = _gen_avatar_background_color(in_username)
		_avatar = null
		if _write_auth_cache():
			logged_in.emit()
			# TODO: Load avatar from url
			avatar_loaded.emit()
		else:
			authentication_failed.emit()
	else:
		authentication_failed.emit()
	return promise


func logout() -> void:
	if FileAccess.file_exists(AUTH_CACHE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_CACHE_FILE))
	if FileAccess.file_exists(AUTH_CACHE_IV):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_CACHE_IV))
	_clear_authentication()
	logged_out.emit()


class AuthenticationPromise extends Promise:
	var _auth: MsepOnlineAuthenticator
	func _init(authenticator: MsepOnlineAuthenticator) -> void:
		authenticator.logged_in.connect(_on_result.bind(true))
		authenticator.authentication_failed.connect(_on_result.bind(false))
		_auth = authenticator
	func _on_result(in_success: bool) -> void:
		if in_success:
			fulfill(true)
		else:
			fail("Authentication Failed", false)
		_auth.logged_in.disconnect(_on_result)
		_auth.authentication_failed.disconnect(_on_result)
		_auth = null


func _write_auth_cache() -> bool:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(AUTH_CACHE_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUTH_CACHE_DIR))
	var encrypt_key: PackedByteArray = _get_encryption_key()
	const IV_LEN = 16
	var iv: PackedByteArray = _generate_initialization_vector(IV_LEN)
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
		push_error("Failed to open encrypted auth file with write permissions. ", error_string(FileAccess.get_open_error()))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_CACHE_IV))
		return false
	auth_file.store_pascal_string(_auth_token)
	auth_file.store_pascal_string(_refresh_token)
	auth_file.store_pascal_string(_username)
	if _avatar == null:
		var avatar_buffer_length: int = 0
		auth_file.store_64(avatar_buffer_length)
	else:
		var avatar_buffer: PackedByteArray = _avatar.get_image().save_png_to_buffer()
		var avatar_buffer_length: int = avatar_buffer.size()
		auth_file.store_64(avatar_buffer_length)
		auth_file.store_buffer(avatar_buffer)
	var public_data_json: String = JSON.stringify(_user_public_data, "", false)
	auth_file.store_pascal_string(public_data_json)
	auth_file.close()
	return true


func _get_encryption_key() -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = OS.get_unique_id().md5_text().hash()
	var key := PackedByteArray()
	for i in 32:
		key.append(rng.randi_range(0, 255))
	return key


func _generate_initialization_vector(in_iv_length: int) -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var iv := PackedByteArray()
	for i in in_iv_length:
		iv.append(rng.randi_range(0, 255))
	return iv


func _gen_avatar_background_color(in_username: String) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = in_username.to_lower().hash()
	var h: float = rng.randf_range(0.0, 1)
	var s: float = rng.randf_range(0.4, 0.5)
	var v: float = rng.randf_range(0.8, 1)
	return Color.from_hsv(h, s, v)


func _clear_authentication() -> void:
	_is_authenticated = false
	_auth_token = ""
	_refresh_token = ""
	_username = ""
	_avatar_background_color = Color.BLACK
	_avatar = null
	_user_public_data = {}


func _on_feature_flag_toggled(in_path: String, in_value: bool) -> void:
	if in_path == FeatureFlagManager.FEATURE_FLAGS_MSEP_ONLINE:
		if in_value:
			_authenticate_from_cache()
		else:
			if not _is_authenticated:
				return
			_clear_authentication()
			logged_out.emit()
