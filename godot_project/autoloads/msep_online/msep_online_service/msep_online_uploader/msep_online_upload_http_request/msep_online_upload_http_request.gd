class_name MsepOnlineUploadHTTPRequest
extends MsepOnlineHTTPRequest
## Sends a file to an upload URL that the MSEP Online API granted.


## Sends the file once the session token is valid and returns the promise of the response. The node
## frees itself when the call ends.
func send_file(in_upload_url: String, in_file: FileAccess,
		in_authenticator: MsepOnlineAuthenticator, in_allow_unsafe_tls: bool) -> DownloadPromise:
	method = "PUT"
	url = in_upload_url
	_promise.set_meta(&"url", "URL: "+ method + " : " + url)
	if in_allow_unsafe_tls:
		# Test server doesn't use a certificate
		set_tls_options(TLSOptions.client_unsafe())
	_upload(in_upload_url, in_file, in_authenticator)
	return _promise


func _upload(in_upload_url: String, in_file: FileAccess, in_authenticator: MsepOnlineAuthenticator) -> void:
	var headers: PackedStringArray = [
		"Content-Type: application/octet-stream",
		"Content-Length: %d" % in_file.get_length()
	]
	await in_authenticator.ensure_valid_token().wait_for_fulfill()
	headers.append_array(in_authenticator.get_authentication_headers())
	in_file.seek(0)
	var error: Error = request_raw(
		in_upload_url,
		headers,
		HTTPClient.METHOD_PUT,
		in_file.get_buffer(in_file.get_length())
	)
	if error != OK:
		_promise.fail("Upload failed with error: " + error_string(error))
		queue_free()
		return
