class_name MsepOnlineUploadHTTPRequest
extends MsepOnlineHTTPRequest


# OVERRIDE
func _init(upload_url: String, file: FileAccess) -> void:
	Engine.get_main_loop().root.add_child(self)
	request_completed.connect(_on_request_completed)
	
	var headers: PackedStringArray = [
		"Content-Type: application/octet-stream",
		"Content-Length: %d" % file.get_length()
	]
	var authenticator: MsepOnlineAuthenticator = MolecularEditorContext.authenticator
	headers.append_array(authenticator.get_authentication_headers())
	file.seek(0)
	_promise.set_meta(&"url", "URL: "+ method + " : " + upload_url)
	if _is_using_stub_service() and get_base_url().find("http://") == 0:
		# Test server doesn't use a certificate
		set_tls_options(TLSOptions.client_unsafe())
	var error: Error = request_raw(
		upload_url,
		headers,
		HTTPClient.METHOD_PUT,
		file.get_buffer(file.get_length())
	)
	if error != OK:
		_promise.fail("Upload failed with error: " + error_string(error))
		queue_free()
		return
