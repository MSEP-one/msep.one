class_name TokenResponse extends RefCounted
## Responsible for holding one answer of the Keycloak token endpoint, granted or rejected.


const DEFAULT_LIFETIME_SEC: float = 60.0


var access_token: String = ""
var refresh_token: String = ""
var lifetime_sec: float = DEFAULT_LIFETIME_SEC
var error: String = ""
var error_description: String = ""


static func from_dictionary(in_body: Dictionary) -> TokenResponse:
	var response := TokenResponse.new()
	response.access_token = str(in_body.get("access_token", ""))
	response.refresh_token = str(in_body.get("refresh_token", ""))
	response.lifetime_sec = float(in_body.get("expires_in", DEFAULT_LIFETIME_SEC))
	response.error = str(in_body.get("error", ""))
	response.error_description = str(in_body.get("error_description", ""))
	return response


static func failed(in_error: String, in_error_description: String = "") -> TokenResponse:
	var response := TokenResponse.new()
	response.error = in_error
	response.error_description = in_error_description
	return response


func is_granted() -> bool:
	return not access_token.is_empty()


func get_error_text() -> String:
	if not error_description.is_empty():
		return error_description
	if not error.is_empty():
		return error
	return TranslationServer.translate("unknown error")
