class_name DeviceCodeLogin extends Node
## Responsible for the device authorization login.


signal device_code_issued(user_code: String, verification_uri: String)


@export var keycloak_client: KeycloakClient


var _attempt: int = 0


## Asks Keycloak for a device code, then waits until the user approved it. A newer run or cancel() ends the wait.
func run() -> Result:
	_attempt += 1
	var attempt: int = _attempt
	var verifier: String = PkceCodes.random_urlsafe(64)
	var device: DeviceCodeResponse = await keycloak_client.request_device_code(
			PkceCodes.challenge_for(verifier))
	var device_request_failed: bool = not device.is_issued()
	if device_request_failed:
		return Result.failed(tr("Device authorization failed: %s") % device.get_error_text())
	device_code_issued.emit(device.user_code, device.verification_uri)
	var tokens: TokenResponse = await _poll_device_tokens(device, verifier, attempt)
	var exchange_failed: bool = not tokens.is_granted()
	if exchange_failed:
		return Result.failed(tr("Device login failed: %s") % tokens.get_error_text())
	return Result.granted(tokens)


## Returns the granted tokens once the user approves the device code, or a rejection.
func _poll_device_tokens(
		in_device: DeviceCodeResponse, in_verifier: String, in_attempt: int) -> TokenResponse:
	var interval_sec: float = maxf(in_device.interval_sec, 1.0)
	var deadline: int = Time.get_ticks_msec() + int(in_device.lifetime_sec * 1000.0)
	while Time.get_ticks_msec() < deadline and in_attempt == _attempt:
		await get_tree().create_timer(interval_sec).timeout
		var tokens: TokenResponse = await keycloak_client.poll_device_tokens(
				in_device.device_code, in_verifier)
		var got_tokens: bool = tokens.is_granted()
		if got_tokens:
			return tokens
		var still_pending: bool = tokens.error == "authorization_pending"
		var must_slow_down: bool = tokens.error == "slow_down"
		if still_pending:
			continue
		if must_slow_down:
			interval_sec += 5.0
			continue
		return tokens
	var was_superseded: bool = in_attempt != _attempt
	if was_superseded:
		return TokenResponse.failed("superseded")
	return TokenResponse.failed(
			"expired_token", tr("Device code expired before login was finished"))


func cancel() -> void:
	_attempt += 1


class Result:
	var tokens: TokenResponse = null
	var failure: String = ""
	
	
	static func granted(in_tokens: TokenResponse) -> Result:
		var result := Result.new()
		result.tokens = in_tokens
		return result
	
	
	static func failed(in_failure: String) -> Result:
		var result := Result.new()
		result.failure = in_failure
		return result
	
	
	func has_failed() -> bool:
		return not failure.is_empty()
