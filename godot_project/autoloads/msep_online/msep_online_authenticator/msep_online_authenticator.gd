@tool
class_name MsepOnlineAuthenticator extends Node
## Responsible for the signed-in MSEP Online session: logging in and out, keeping its tokens valid
## and remembering it between runs.


signal logged_in()
signal avatar_loaded()
signal authentication_failed(error: String)
signal device_code_issued(user_code: String, verification_uri: String)
signal logged_out()
signal profile_reloaded()
signal session_opened()


const TOKEN_REFRESH_MARGIN_SEC: float = 10.0


@export_group("Tests")
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var test_name: String:
	set(v):
		test_name = v
		generated_color = _gen_avatar_background_color(test_name)
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var generated_color: Color
@export_tool_button("Randomize Name") var test_button: Callable = _randomize_test_name
func _randomize_test_name() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var name_bytes := PackedByteArray()
	for i: int in 10:
		name_bytes.append(rng.randi_range(0, 255))
	test_name = name_bytes.get_string_from_ascii()
@export_group("")


var _is_authenticated: bool = false
var _auth_token: String = ""
var _refresh_token: String = ""
var _auth_uuid: String = ""
var _username: String = ""
var _expire_time: float = 0
var _avatar_background_color := Color.BLACK
var _avatar: Texture2D = null
var _user_public_data: Dictionary = {
	# username<String>: MSEP Community username
	# auth_uuid<String>: user identifier
	# avatar<String>: url of the avatar image, null when the user has none
	# bio<String>: null when empty
	# primary_email<String>
	# email_visibility<String>
	# organization_affiliations<Array>: names<String>
}

@onready var _keycloak_client: KeycloakClient = %KeycloakClient
@onready var _token_refresher: TokenRefresher = %TokenRefresher
@onready var _login_flow: LoginFlow = %LoginFlow


func _init() -> void:
	if Engine.is_editor_hint():
		return
	_initialize_deferred.call_deferred()


func _initialize_deferred() -> void:
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_MSEP_ONLINE):
		_authenticate_from_cache()
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)


func _authenticate_from_cache() -> void:
	var has_cached_session: bool = MsepOnlineAuthCache.exists()
	if not has_cached_session:
		_clear_authentication()
		return
	var session: Dictionary = MsepOnlineAuthCache.read()
	var cache_unreadable: bool = session.is_empty()
	if cache_unreadable:
		_clear_authentication()
		return
	_is_authenticated = true
	_auth_token = session["auth_token"]
	_refresh_token = session["refresh_token"]
	_auth_uuid = session["auth_uuid"]
	_username = session["username"]
	_expire_time = session["expire_time"]
	_avatar_background_color = _gen_avatar_background_color(_username)
	_avatar = session["avatar"]
	_user_public_data = session["user_public_data"]
	logged_in.emit()
	_revalidate_tokens()


func _clear_authentication() -> void:
	_token_refresher.discard_pending_refresh()
	_is_authenticated = false
	_auth_token = ""
	_refresh_token = ""
	_username = ""
	_avatar_background_color = Color.BLACK
	_avatar = null
	_user_public_data = {}


func _gen_avatar_background_color(in_username: String) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = in_username.to_lower().hash()
	var h: float = rng.randf_range(0.0, 1)
	var s: float = rng.randf_range(0.4, 0.5)
	var v: float = rng.randf_range(0.8, 1)
	return Color.from_hsv(h, s, v)


func _revalidate_tokens() -> void:
	await ensure_valid_token().wait_for_fulfill()
	if _is_authenticated:
		print("Session is valid. Welcome ", _username)


func _on_feature_flag_toggled(in_path: String, in_value: bool) -> void:
	if in_path == FeatureFlagManager.FEATURE_FLAGS_MSEP_ONLINE:
		if in_value:
			_authenticate_from_cache()
		else:
			if not _is_authenticated:
				return
			_clear_authentication()
			logged_out.emit()



func get_username() -> String:
	return _username if _is_authenticated else ""


func get_avatar() -> Texture2D:
	return _avatar if _is_authenticated else null


func get_avatar_background_color() -> Color:
	return _avatar_background_color if _is_authenticated else Color.BLACK


func get_user_public_data() -> Dictionary:
	return _user_public_data.duplicate(true) if _is_authenticated else {}


## Returns the url of the avatar image in the profile, or an empty string when the user has none.
func get_avatar_url() -> String:
	var avatar_url: Variant = _user_public_data.get("avatar")
	var has_avatar_url: bool = avatar_url is String and not (avatar_url as String).is_empty()
	if not has_avatar_url:
		return ""
	return avatar_url


## Refreshes the access token when it is expired or about to expire.
## The promise holds false if a refresh did not succeed.
## The session is ended only when Keycloak revoked it.
func ensure_valid_token() -> TokenValidationPromise:
	var promise := TokenValidationPromise.new()
	_validate_token(promise)
	return promise


func _validate_token(out_promise: TokenValidationPromise) -> void:
	var token_expires_soon: bool = _expire_time - TOKEN_REFRESH_MARGIN_SEC <= Time.get_unix_time_from_system()
	var needs_refresh: bool = _is_authenticated and token_expires_soon
	if not needs_refresh:
		out_promise.fulfill(true)
		return
	var refresh_promise: TokenRefresher.RefreshPromise = _token_refresher.refresh(_refresh_token)
	await refresh_promise.wait_for_fulfill()
	var result: TokenRefresher.Result = refresh_promise.get_outcome()
	var session_revoked: bool = result == TokenRefresher.Result.SESSION_REVOKED
	var session_still_open: bool = _is_authenticated
	if session_revoked and session_still_open:
		_end_session()
	out_promise.fulfill(result == TokenRefresher.Result.REFRESHED)


func _on_token_refresher_tokens_refreshed(in_tokens: TokenResponse) -> void:
	_apply_tokens(in_tokens)
	# Keycloak rotates refresh tokens, so the new one must be cached right away.
	_write_auth_cache()


func _apply_tokens(in_tokens: TokenResponse) -> void:
	_is_authenticated = true
	_auth_token = in_tokens.access_token
	var rotated_refresh_token: bool = not in_tokens.refresh_token.is_empty()
	if rotated_refresh_token:
		_refresh_token = in_tokens.refresh_token
	_expire_time = Time.get_unix_time_from_system() + in_tokens.lifetime_sec


func _write_auth_cache() -> bool:
	return MsepOnlineAuthCache.write({
		"auth_token": _auth_token,
		"refresh_token": _refresh_token,
		"auth_uuid": _auth_uuid,
		"username": _username,
		"expire_time": _expire_time,
		"avatar": _avatar,
		"user_public_data": _user_public_data,
	})


func _end_session() -> void:
	MsepOnlineAuthCache.remove()
	_clear_authentication()
	logged_out.emit()


func is_authenticated() -> bool:
	return _is_authenticated


func get_authentication_headers() -> PackedStringArray:
	if is_authenticated():
		return ["Authorization: Bearer " + _auth_token]
	return []


## Logs in through the browser and stores the resulting session.
## With in_use_device_code the user approves a code on a device
func login(in_use_device_code: bool = false) -> void:
	if _is_authenticated:
		return
	var login_promise: LoginFlow.LoginPromise = _login_flow.run(in_use_device_code)
	await login_promise.wait_for_fulfill()
	var login_result: LoginFlow.Result = login_promise.get_login_result()
	if login_result.is_superseded:
		return
	if login_result.has_failed():
		authentication_failed.emit(login_result.failure)
		return
	_open_session(login_result.tokens)


## Applies the tokens of a finished login and announces the session, which has no profile yet.
func _open_session(in_tokens: TokenResponse) -> void:
	_apply_tokens(in_tokens)
	session_opened.emit()


func _on_login_flow_device_code_issued(in_user_code: String, in_verification_uri: String) -> void:
	device_code_issued.emit(in_user_code, in_verification_uri)


## Ends the session that was just opened and reports in_reason.
func fail_login(in_reason: String) -> void:
	var session_ended_meanwhile: bool = not _is_authenticated
	if session_ended_meanwhile:
		return
	_clear_authentication()
	authentication_failed.emit(in_reason)


## Finishes the login with the profile of the new session. Returns false when the session ended in
## the meantime, the profile has no username or the session could not be stored.
func complete_login(in_me: Dictionary) -> bool:
	var session_ended_meanwhile: bool = not _is_authenticated
	if session_ended_meanwhile:
		return false
	var profile_missing_username: bool = not in_me.has("username")
	if profile_missing_username:
		_clear_authentication()
		authentication_failed.emit(tr("Could not load your MSEP Community profile"))
		return false
	_apply_profile(in_me)
	var cache_written: bool = _write_auth_cache()
	if not cache_written:
		authentication_failed.emit(tr("Failed to store credentials"))
		return false
	logged_in.emit()
	return true


func _apply_profile(in_me: Dictionary) -> void:
	_username = in_me["username"]
	_auth_uuid = str(in_me.get("auth_uuid", ""))
	_user_public_data = in_me
	_avatar_background_color = _gen_avatar_background_color(_username)


## Replaces the profile with a freshly loaded one. Returns false on failure.
func replace_profile(in_me: Dictionary) -> bool:
	var profile_missing_username: bool = not in_me.has("username")
	if profile_missing_username:
		return false
	_apply_profile(in_me)
	_avatar = null
	_write_auth_cache()
	profile_reloaded.emit()
	return true


func set_avatar_image(in_image: Image) -> void:
	_avatar = ImageTexture.create_from_image(in_image)
	_write_auth_cache()
	avatar_loaded.emit()


func logout() -> void:
	var old_refresh_token: String = _refresh_token
	_end_session()
	var had_refresh_token: bool = not old_refresh_token.is_empty()
	if had_refresh_token:
		_keycloak_client.revoke_refresh_token(old_refresh_token)


class TokenValidationPromise extends Promise:
	
	func is_valid() -> bool:
		return get_result() as bool
