class_name MsepOnlineHTTPRequest
extends HTTPRequest


var url: String
var method: String

var _promise := Promise.new()


static func _is_using_stub_service() -> bool:
	return FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_MSEP_ONLINE_STUB_SERVICE)


static func get_base_url() -> String:
	if _is_using_stub_service():
		return ProjectSettings.get_setting_with_override("msep/msep_online/test_baseurl") + "/"
	return ProjectSettings.get_setting_with_override("msep/msep_online/baseurl") + "/"

func _init(in_method: HTTPClient.Method, subpath: String, request_body: String = "") -> void:
	Engine.get_main_loop().root.add_child(self)
	request_completed.connect(_on_request_completed)

	var headers: PackedStringArray
	if request_body.is_empty():
		headers.append("Content-Type: application/json")
	var authenticator: MsepOnlineAuthenticator = MolecularEditorContext.authenticator
	headers.append_array(authenticator.get_authentication_headers())
	
	if subpath.begins_with("http://") or subpath.begins_with("https://"):
		# Is a full path, in example the url of an image or binary file
		url = subpath
	else:
		url = get_base_url() + subpath
	const METHODS = {
		HTTPClient.Method.METHOD_GET : "GET",
		HTTPClient.Method.METHOD_HEAD : "HEAD",
		HTTPClient.Method.METHOD_POST : "POST",
		HTTPClient.Method.METHOD_PUT : "PUT",
		HTTPClient.Method.METHOD_DELETE : "DELETE",
		HTTPClient.Method.METHOD_OPTIONS : "OPTIONS",
		HTTPClient.Method.METHOD_TRACE : "TRACE",
		HTTPClient.Method.METHOD_CONNECT : "CONNECT",
		HTTPClient.Method.METHOD_PATCH : "PATCH",
	}
	method = METHODS[in_method]
	_promise.set_meta(&"url", "URL: "+ method + " : " + url)
	var error: Error = request(url, headers, in_method, request_body)
	if error != OK:
		push_error("An %s error occurred in the HTTP request." % error_string(error))
		_promise.fail("An %s error occurred in the HTTP request." % error_string(error))
		queue_free()


func get_promise() -> Promise:
	return _promise


func _on_request_completed(result_code: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result_code == RESULT_SUCCESS:
		var result := ServiceResponse.new()
		result.url = url
		result.method = method
		result.code = response_code as HTTPClient.ResponseCode
		result.response_headers = headers
		result.raw_body = body
		var is_json: bool = false
		for h: String in headers:
			if h.to_lower() == "content-type: application/json":
				is_json = true
				break
		if is_json and not body.is_empty():
			result.body = JSON.parse_string(body.get_string_from_utf8())
		result.body.make_read_only()
		_promise.fulfill(result)
	else:
		const RESULTS: Dictionary[Result, String] = {
			RESULT_SUCCESS : "RESULT_SUCCESS",
			RESULT_CHUNKED_BODY_SIZE_MISMATCH : "RESULT_CHUNKED_BODY_SIZE_MISMATCH",
			RESULT_CANT_CONNECT : "RESULT_CANT_CONNECT",
			RESULT_CANT_RESOLVE : "RESULT_CANT_RESOLVE",
			RESULT_CONNECTION_ERROR : "RESULT_CONNECTION_ERROR",
			RESULT_TLS_HANDSHAKE_ERROR : "RESULT_TLS_HANDSHAKE_ERROR",
			RESULT_NO_RESPONSE : "RESULT_NO_RESPONSE",
			RESULT_BODY_SIZE_LIMIT_EXCEEDED : "RESULT_BODY_SIZE_LIMIT_EXCEEDED",
			RESULT_BODY_DECOMPRESS_FAILED : "RESULT_BODY_DECOMPRESS_FAILED",
			RESULT_REQUEST_FAILED : "RESULT_REQUEST_FAILED",
			RESULT_DOWNLOAD_FILE_CANT_OPEN : "RESULT_DOWNLOAD_FILE_CANT_OPEN",
			RESULT_DOWNLOAD_FILE_WRITE_ERROR : "RESULT_DOWNLOAD_FILE_WRITE_ERROR",
			RESULT_REDIRECT_LIMIT_REACHED : "RESULT_REDIRECT_LIMIT_REACHED",
			RESULT_TIMEOUT : "RESULT_TIMEOUT",
		}
		_promise.fail(method + " " + url + " failed with result: " + RESULTS[result_code])
	queue_free()


class ServiceResponse:
	var url: String
	var method: String
	var code := HTTPClient.ResponseCode.RESPONSE_NOT_FOUND
	var raw_body: PackedByteArray
	var body: Dictionary
	var response_headers: PackedStringArray
