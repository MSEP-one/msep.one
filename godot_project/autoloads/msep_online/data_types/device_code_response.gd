class_name DeviceCodeResponse extends RefCounted
## Responsible for holding one answer of the Keycloak device authorization endpoint.


const DEFAULT_INTERVAL_SEC: float = 5.0
const DEFAULT_LIFETIME_SEC: float = 300.0


var device_code: String = ""
var user_code: String = ""
var verification_uri: String = ""
var interval_sec: float = DEFAULT_INTERVAL_SEC
var lifetime_sec: float = DEFAULT_LIFETIME_SEC
var error: String = ""
var error_description: String = ""


static func from_dictionary(in_body: Dictionary) -> DeviceCodeResponse:
	var response := DeviceCodeResponse.new()
	response.device_code = str(in_body.get("device_code", ""))
	response.user_code = str(in_body.get("user_code", ""))
	response.verification_uri = str(
			in_body.get("verification_uri", in_body.get("verification_uri_complete", "")))
	response.interval_sec = float(in_body.get("interval", DEFAULT_INTERVAL_SEC))
	response.lifetime_sec = float(in_body.get("expires_in", DEFAULT_LIFETIME_SEC))
	response.error = str(in_body.get("error", ""))
	response.error_description = str(in_body.get("error_description", ""))
	return response


static func failed(in_error: String, in_error_description: String = "") -> DeviceCodeResponse:
	var response := DeviceCodeResponse.new()
	response.error = in_error
	response.error_description = in_error_description
	return response


func is_issued() -> bool:
	return not device_code.is_empty()


## Returns the description of the rejection, falling back to its error code and then to a generic text.
func get_error_text() -> String:
	if not error_description.is_empty():
		return error_description
	if not error.is_empty():
		return error
	return TranslationServer.translate("unknown error")
