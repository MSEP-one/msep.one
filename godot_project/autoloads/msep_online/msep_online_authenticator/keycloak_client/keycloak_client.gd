class_name KeycloakClient extends Node
## Responsible for the HTTP calls to the Keycloak server that issues, refreshes and revokes MSEP
## Online sessions.


const OPEN_ID_CONNECT_SCOPES: String = "openid profile email offline_access"


@onready var _request_template: HTTPRequest = %RequestTemplate


## Returns the browser url of the login page that redirects to in_redirect_uri afterwards.
func get_authorization_url(in_redirect_uri: String, in_state: String, in_code_challenge: String) -> String:
	return _keycloak_issuer() + "/protocol/openid-connect/auth?" + _encode_form({
		"response_type": "code",
		"client_id": _client_id(),
		"redirect_uri": in_redirect_uri,
		"scope": OPEN_ID_CONNECT_SCOPES,
		"state": in_state,
		"code_challenge": in_code_challenge,
		"code_challenge_method": "S256",
	})


func _keycloak_issuer() -> String:
	return ProjectSettings.get_setting("msep/msep_online/keycloak_issuer")


func _encode_form(in_form: Dictionary) -> String:
	var pairs: PackedStringArray = []
	for key: String in in_form:
		pairs.append("%s=%s" % [key, str(in_form[key]).uri_encode()])
	return "&".join(pairs)


func _client_id() -> String:
	return ProjectSettings.get_setting("msep/msep_online/client_id")


func exchange_authorization_code(
		in_code: String, in_redirect_uri: String, in_code_verifier: String) -> TokenResponse:
	return await _post_token_request({
		"grant_type": "authorization_code",
		"code": in_code,
		"redirect_uri": in_redirect_uri,
		"client_id": _client_id(),
		"code_verifier": in_code_verifier,
	})


func _post_token_request(in_form: Dictionary) -> TokenResponse:
	var body: Dictionary = await _post_form(_keycloak_issuer() + "/protocol/openid-connect/token", in_form)
	return TokenResponse.from_dictionary(body)


## Returns the parsed JSON answer, or a dictionary with only error and error_description when the call
## failed.
func _post_form(in_url: String, in_form: Dictionary) -> Dictionary:
	var request: HTTPRequest = _spawn_request()
	var err: int = request.request(
		in_url,
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		_encode_form(in_form)
	)
	var request_failed_to_start: bool = err != OK
	if request_failed_to_start:
		request.queue_free()
		return {"error": error_string(err)}
	var completed: Array = await request.request_completed
	request.queue_free()
	var body: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	var parsed_as_dictionary: bool = body is Dictionary
	if parsed_as_dictionary:
		return body
	return {"error": "invalid_response", "error_description": "HTTP %d" % completed[1]}


func _spawn_request() -> HTTPRequest:
	var request: HTTPRequest = _request_template.duplicate()
	add_child(request)
	return request


func refresh_tokens(in_refresh_token: String) -> TokenResponse:
	return await _post_token_request({
		"grant_type": "refresh_token",
		"refresh_token": in_refresh_token,
		"client_id": _client_id(),
	})


func request_device_code(in_code_challenge: String) -> DeviceCodeResponse:
	var body: Dictionary = await _post_form(_keycloak_issuer() + "/protocol/openid-connect/auth/device", {
		"client_id": _client_id(),
		"scope": OPEN_ID_CONNECT_SCOPES,
		"code_challenge": in_code_challenge,
		"code_challenge_method": "S256",
	})
	return DeviceCodeResponse.from_dictionary(body)


## Returns the granted tokens once the user approved the device code; until then the error is
## authorization_pending or slow_down.
func poll_device_tokens(in_device_code: String, in_code_verifier: String) -> TokenResponse:
	return await _post_token_request({
		"grant_type": "urn:ietf:params:oauth:grant-type:device_code",
		"device_code": in_device_code,
		"client_id": _client_id(),
		"code_verifier": in_code_verifier,
	})


func revoke_refresh_token(in_token: String) -> void:
	var request: HTTPRequest = _spawn_request()
	var err: int = request.request(
		_keycloak_issuer() + "/protocol/openid-connect/revoke",
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		_encode_form({"token": in_token, "token_type_hint": "refresh_token", "client_id": _client_id()})
	)
	var request_failed_to_start: bool = err != OK
	if request_failed_to_start:
		request.queue_free()
		return
	await request.request_completed
	request.queue_free()
