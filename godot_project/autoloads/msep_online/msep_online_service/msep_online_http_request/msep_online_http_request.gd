class_name MsepOnlineHTTPRequest
extends HTTPRequest
## One authenticated call to the MSEP Online API and the promise of its response.


const METHODS: Dictionary[HTTPClient.Method, String] = {
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


var url: String
var method: String

var _promise := DownloadPromise.new(self)


## Sends the request once the session token is valid. The
## node frees itself when the call ends.
func send(in_method: HTTPClient.Method, in_url: String, in_request_body: String,
			in_authenticator: MsepOnlineAuthenticator) -> DownloadPromise:
	var headers: PackedStringArray
	if not in_request_body.is_empty():
		headers.append("Content-Type: application/json")
	url = in_url
	method = METHODS[in_method]
	_promise.set_meta(&"url", "URL: "+ method + " : " + url)
	_send(headers, in_method, in_request_body, in_authenticator)
	return _promise


func _send(in_headers: PackedStringArray, in_method: HTTPClient.Method, in_request_body: String,
			in_authenticator: MsepOnlineAuthenticator) -> void:
	await in_authenticator.ensure_valid_token().wait_for_fulfill()
	var headers: PackedStringArray = in_headers.duplicate()
	headers.append_array(in_authenticator.get_authentication_headers())
	var error: Error = request(url, headers, in_method, in_request_body)
	if error != OK:
		push_error("An %s error occurred in the HTTP request." % error_string(error))
		_promise.fail(tr("An %s error occurred in the HTTP request.") % error_string(error))
		queue_free()


func _on_request_completed(result_code: int, response_code: int, headers: PackedStringArray,
			body: PackedByteArray) -> void:
	if result_code == RESULT_SUCCESS:
		var result := MsepOnlineResponse.new()
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
