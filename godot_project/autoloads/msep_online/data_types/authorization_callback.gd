class_name AuthorizationCallback extends RefCounted
## Holds the query of the redirect that ends a browser login.


var code: String = ""
var state: String = ""
var error: String = ""
var error_description: String = ""


static func from_query(in_query: Dictionary[String, String]) -> AuthorizationCallback:
	var callback := AuthorizationCallback.new()
	callback.code = in_query.get("code", "")
	callback.state = in_query.get("state", "")
	callback.error = in_query.get("error", "")
	callback.error_description = in_query.get("error_description", "")
	return callback


func has_login_result() -> bool:
	return not code.is_empty() or not error.is_empty()
