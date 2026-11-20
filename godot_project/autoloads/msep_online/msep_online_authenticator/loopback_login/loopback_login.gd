class_name LoopbackLogin extends Node
## Responsible for running a browser login whose result is redirected back to a local loopback port.


const LOOPBACK_PORTS: Array[int] = [45100, 45101, 45102, 45103, 45104]
const LOGIN_TIMEOUT_MSEC: int = 300000
const LOGIN_SUCCESS_PAGE: String = (
		"<html><body><h2>Login successful.</h2>"
		+ "<p>You can close this window and return to the app.</p></body></html>")
const LOGIN_FAILURE_PAGE: String = "<html><body><h2>Login failed.</h2></body></html>"


var _attempt: int = 0


## Opens in the browser the login url that in_url_for_redirect_uri returns for the loopback redirect
## uri, then waits for the redirect.
## A newer run or cancel() ends the wait.
func run(in_url_for_redirect_uri: Callable) -> Result:
	_attempt += 1
	var attempt: int = _attempt
	var result := Result.new()
	var server := TCPServer.new()
	var port: int = _listen_on_loopback(server)
	var found_no_free_port: bool = port < 0
	if found_no_free_port:
		return result
	var redirect_uri: String = "http://127.0.0.1:%d/callback" % port
	var auth_url: String = in_url_for_redirect_uri.call(redirect_uri)
	var browser_failed_to_open: bool = OS.shell_open(auth_url) != OK
	if browser_failed_to_open:
		server.stop()
		return result
	result.redirect_uri = redirect_uri
	result.callback = await _wait_for_callback(server, attempt)
	server.stop()
	return result


## Binds the first free port from LOOPBACK_PORTS. Returns -1 if none is free.
func _listen_on_loopback(in_server: TCPServer) -> int:
	for port: int in LOOPBACK_PORTS:
		var bound_successfully: bool = in_server.listen(port, "127.0.0.1") == OK
		if bound_successfully:
			return port
	return -1


## Returns the final redirect, or an empty one on timeout or when the attempt is no longer the current one.
func _wait_for_callback(in_server: TCPServer, in_attempt: int) -> AuthorizationCallback:
	var deadline: int = Time.get_ticks_msec() + LOGIN_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline and in_attempt == _attempt:
		var connection_available: bool = in_server.is_connection_available()
		if connection_available:
			var peer: StreamPeerTCP = in_server.take_connection()
			var callback: AuthorizationCallback = await _read_callback_request(peer)
			_send_browser_page(peer, callback)
			if callback.has_login_result():
				return callback
		await get_tree().process_frame
	return AuthorizationCallback.new()


func _read_callback_request(in_peer: StreamPeerTCP) -> AuthorizationCallback:
	var read_deadline: int = Time.get_ticks_msec() + 2000
	while in_peer.get_available_bytes() == 0 and Time.get_ticks_msec() < read_deadline:
		await get_tree().process_frame
	var available: int = in_peer.get_available_bytes()
	var received_nothing: bool = available == 0
	if received_nothing:
		return AuthorizationCallback.new()
	var result: Array = in_peer.get_partial_data(available)
	var read_failed: bool = result[0] != OK
	if read_failed:
		return AuthorizationCallback.new()
	var request_line: String = (result[1] as PackedByteArray).get_string_from_utf8().get_slice("\r\n", 0)
	var target: String = request_line.get_slice(" ", 1)
	return AuthorizationCallback.from_query(_parse_query(target.get_slice("?", 1)))


func _parse_query(in_query: String) -> Dictionary[String, String]:
	var params: Dictionary[String, String] = {
		# query_key<String>: decoded_value<String>
		# (...)
	}
	for pair: String in in_query.split("&", false):
		var key_value: PackedStringArray = pair.split("=", true, 1)
		var has_key_and_value: bool = key_value.size() == 2
		if has_key_and_value:
			params[key_value[0].uri_decode()] = key_value[1].uri_decode()
	return params


func _send_browser_page(in_peer: StreamPeerTCP, in_callback: AuthorizationCallback) -> void:
	var is_success: bool = not in_callback.code.is_empty()
	var body: String = LOGIN_SUCCESS_PAGE if is_success else LOGIN_FAILURE_PAGE
	var content_length: int = body.to_utf8_buffer().size()
	var response: String = ("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n"
			+ "Content-Length: %d\r\n\r\n%s") % [content_length, body]
	in_peer.put_data(response.to_utf8_buffer())
	in_peer.disconnect_from_host()


func cancel() -> void:
	_attempt += 1


class Result:
	var redirect_uri: String = ""
	var callback: AuthorizationCallback = AuthorizationCallback.new()
	
	
	func has_started() -> bool:
		return not redirect_uri.is_empty()
