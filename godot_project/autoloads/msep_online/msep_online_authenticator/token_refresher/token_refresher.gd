class_name TokenRefresher extends Node
## Responsible for exchanging a refresh token for new tokens, sharing one Keycloak call between
## concurrent requests.


signal tokens_refreshed(tokens: TokenResponse)


enum Result {
	REFRESHED,
	SESSION_REVOKED,
	UNAVAILABLE,
}


@export var keycloak_client: KeycloakClient


var _pending_refresh: RefreshPromise = null
var _discard_count: int = 0


## Emits tokens_refreshed once per granted exchange and returns the promise of how it ended.
## Returns the promise of the running exchange while one is in progress.
func refresh(in_refresh_token: String) -> RefreshPromise:
	var has_no_refresh_token: bool = in_refresh_token.is_empty()
	if has_no_refresh_token:
		var revoked_promise := RefreshPromise.new()
		revoked_promise.fulfill(Result.SESSION_REVOKED)
		return revoked_promise
	var refresh_in_progress: bool = _pending_refresh != null
	if refresh_in_progress:
		return _pending_refresh
	_pending_refresh = RefreshPromise.new()
	var promise: RefreshPromise = _pending_refresh
	_exchange(promise, in_refresh_token)
	return promise


func _exchange(out_promise: RefreshPromise, in_refresh_token: String) -> void:
	var discards_before_request: int = _discard_count
	var tokens: TokenResponse = await keycloak_client.refresh_tokens(in_refresh_token)
	var result: Result = Result.UNAVAILABLE
	var exchange_succeeded: bool = tokens.is_granted()
	var keycloak_rejected_token: bool = tokens.error == "invalid_grant"
	var refresh_discarded: bool = discards_before_request != _discard_count
	if refresh_discarded:
		_revoke_rotated_refresh_token(tokens)
	elif exchange_succeeded:
		tokens_refreshed.emit(tokens)
		result = Result.REFRESHED
	elif keycloak_rejected_token:
		result = Result.SESSION_REVOKED
	_pending_refresh = null
	out_promise.fulfill(result)


func _revoke_rotated_refresh_token(in_tokens: TokenResponse) -> void:
	var has_rotated_refresh_token: bool = not in_tokens.refresh_token.is_empty()
	if has_rotated_refresh_token:
		keycloak_client.revoke_refresh_token(in_tokens.refresh_token)


func discard_pending_refresh() -> void:
	_discard_count += 1


class RefreshPromise extends Promise:
	
	func get_outcome() -> Result:
		return get_result() as Result
