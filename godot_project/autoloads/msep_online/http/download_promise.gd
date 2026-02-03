class_name DownloadPromise
extends Promise

var _request: MsepOnlineHTTPRequest


func _init(http_request: MsepOnlineHTTPRequest) -> void:
	_request = http_request


func get_progress() -> Vector2i:
	return Vector2i(_request.get_downloaded_bytes(), _request.get_body_size())
