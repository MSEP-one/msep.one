class_name MsepOnlineUploader extends Node
## Waits for the upload URL the API grants, then sends the file to it.


const UploadRequestScene: PackedScene = preload(
		"res://autoloads/msep_online/msep_online_service/msep_online_uploader/msep_online_upload_http_request/msep_online_upload_http_request.tscn")


## Returns a promise fulfilled with the upload response, or failed with the reason the URL was not
## granted or the upload failed.
func upload(in_upload_url_promise: Promise, in_file: FileAccess,
		in_authenticator: MsepOnlineAuthenticator, in_allow_unsafe_tls: bool) -> Promise:
	var promise := Promise.new()
	_upload_when_granted(promise, in_upload_url_promise, in_file, in_authenticator, in_allow_unsafe_tls)
	return promise


func _upload_when_granted(
		out_promise: Promise,
		in_upload_url_promise: Promise,
		in_file: FileAccess,
		in_authenticator: MsepOnlineAuthenticator,
		in_allow_unsafe_tls: bool
	) -> void:
	await in_upload_url_promise.wait_for_fulfill()
	var create_url_error: String = MsepOnline.get_response_error(in_upload_url_promise)
	var create_url_failed: bool = not create_url_error.is_empty()
	if create_url_failed:
		out_promise.fail(create_url_error)
		return
	
	var response: MsepOnlineResponse = in_upload_url_promise.get_result()
	var upload_request: MsepOnlineUploadHTTPRequest = UploadRequestScene.instantiate()
	add_child(upload_request)
	var upload_promise: Promise = upload_request.send_file(response.body.upload_url, in_file,
			in_authenticator, in_allow_unsafe_tls)
	await upload_promise.wait_for_fulfill()
	if upload_promise.has_error():
		out_promise.fail(upload_promise.get_error())
	else:
		out_promise.fulfill(upload_promise.get_result())
