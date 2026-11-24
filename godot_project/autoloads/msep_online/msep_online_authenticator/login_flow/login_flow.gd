class_name LoginFlow extends Node
## Responsible for running one browser or device code login attempt and reporting the tokens it obtained.


signal device_code_issued(user_code: String, verification_uri: String)


@export var keycloak_client: KeycloakClient


var _attempt: int = 0

@onready var _loopback_login: LoopbackLogin = %LoopbackLogin
@onready var _device_code_login: DeviceCodeLogin = %DeviceCodeLogin


func _ready() -> void:
	_device_code_login.keycloak_client = keycloak_client


## A newer run supersedes one that is still waiting, e.g. after the browser tab was closed.
func run(in_use_device_code: bool) -> LoginPromise:
	var promise := LoginPromise.new()
	_fulfill_with_attempt(promise, in_use_device_code)
	return promise


func _fulfill_with_attempt(out_promise: LoginPromise, in_use_device_code: bool) -> void:
	var result: Result = await _run_attempt(in_use_device_code)
	out_promise.fulfill(result)


func _run_attempt(in_use_device_code: bool) -> Result:
	_attempt += 1
	var attempt: int = _attempt
	_loopback_login.cancel()
	_device_code_login.cancel()
	if in_use_device_code:
		return await _run_device_code_login(attempt)
	var verifier: String = PkceCodes.random_urlsafe(64)
	var state: String = PkceCodes.random_urlsafe(16)
	var url_for_redirect_uri: Callable = keycloak_client.get_authorization_url.bind(state,
			PkceCodes.challenge_for(verifier))
	var browser_login: LoopbackLogin.Result = await _loopback_login.run(url_for_redirect_uri)
	var attempt_superseded: bool = attempt != _attempt
	if attempt_superseded:
		return Result.superseded()
	var browser_login_unavailable: bool = not browser_login.has_started()
	if browser_login_unavailable:
		return await _run_device_code_login(attempt)
	return await _exchange_callback(browser_login, state, verifier)


func _run_device_code_login(in_attempt: int) -> Result:
	var device_login: DeviceCodeLogin.Result = await _device_code_login.run()
	var attempt_superseded: bool = in_attempt != _attempt
	if attempt_superseded:
		return Result.superseded()
	if device_login.has_failed():
		return Result.failed(device_login.failure)
	return Result.granted(device_login.tokens)


func _exchange_callback(
		in_browser_login: LoopbackLogin.Result, in_state: String, in_verifier: String) -> Result:
	var callback: AuthorizationCallback = in_browser_login.callback
	var keycloak_reported_error: bool = not callback.error.is_empty()
	var callback_timed_out: bool = not callback.has_login_result()
	var state_mismatched: bool = callback.state != in_state
	if keycloak_reported_error:
		return Result.failed((tr("Keycloak returned an error: %s %s") % [callback.error,
				callback.error_description]).strip_edges())
	if callback_timed_out:
		return Result.failed(tr("Login timed out"))
	if state_mismatched:
		return Result.failed(tr("State mismatch in login callback, login aborted"))
	var tokens: TokenResponse = await keycloak_client.exchange_authorization_code(
			callback.code, in_browser_login.redirect_uri, in_verifier)
	var exchange_failed: bool = not tokens.is_granted()
	if exchange_failed:
		return Result.failed(tr("Token exchange failed: %s") % tokens.get_error_text())
	return Result.granted(tokens)


func _on_device_code_login_device_code_issued(in_user_code: String, in_verification_uri: String) -> void:
	device_code_issued.emit(in_user_code, in_verification_uri)


class Result:
	var tokens: TokenResponse = null
	var failure: String = ""
	var is_superseded: bool = false
	
	
	static func granted(in_tokens: TokenResponse) -> Result:
		var result := Result.new()
		result.tokens = in_tokens
		return result
	
	
	static func failed(in_failure: String) -> Result:
		var result := Result.new()
		result.failure = in_failure
		return result
	
	
	static func superseded() -> Result:
		var result := Result.new()
		result.is_superseded = true
		return result
	
	
	func has_failed() -> bool:
		return not failure.is_empty()


class LoginPromise extends Promise:
	
	func get_login_result() -> Result:
		return get_result() as Result
