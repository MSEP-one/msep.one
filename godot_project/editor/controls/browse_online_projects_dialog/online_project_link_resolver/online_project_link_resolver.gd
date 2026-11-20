class_name OnlineProjectLinkResolver extends Node
## Responsible for loading the project, and the version, that a pasted MSEP Online link points to.


const ISO_DATE_LENGTH: int = 10


var _request_count: int = 0


## A newer resolve or cancel makes a running resolve report itself as superseded.
func resolve(in_link: MsepOnlineLink) -> Resolution:
	_request_count += 1
	var request: int = _request_count
	var version_data: Dictionary = {}
	var project_namespace: String = in_link.project_namespace
	var project_name: String = in_link.project_name
	var is_version_link: bool = in_link.kind == MsepOnlineLink.Kind.VERSION
	if is_version_link:
		var version_promise: Promise = MolecularEditorContext.msep_online.get_project_version(
				in_link.version_uuid)
		var version_answer: Resolution = await _wait_for_body(version_promise, request)
		if version_answer.has_ended():
			return version_answer
		version_data = version_answer.project_data
		var version_project: Dictionary = version_data.get("project", {})
		project_namespace = version_project.get("namespace", "")
		project_name = version_project.get("name", "")
	return await _resolve_project(project_namespace, project_name, version_data, request)


func cancel() -> void:
	_request_count += 1


func _resolve_project(
		in_namespace: String, in_project_name: String, in_version_data: Dictionary,
		in_request: int) -> Resolution:
	var project_promise: Promise = MolecularEditorContext.msep_online.get_namespace_project(
			in_namespace, in_project_name)
	var project_answer: Resolution = await _wait_for_body(project_promise, in_request)
	if project_answer.has_ended():
		return project_answer
	# Responses are read-only, and the opened version is added below
	var project_data: Dictionary = project_answer.project_data.duplicate()
	var is_deleted: bool = project_data.get("is_deleted", false)
	if is_deleted:
		return Resolution.failed(_get_deleted_project_message(project_data))
	var has_version: bool = not in_version_data.is_empty()
	if has_version:
		project_data["latest_version_info"] = in_version_data
	return Resolution.found(project_data, in_version_data.get("version_number", -1))


## Returns the body of the answer as project_data, or a resolution that has ended with an error or as superseded.
func _wait_for_body(in_promise: Promise, in_request: int) -> Resolution:
	await in_promise.wait_for_fulfill()
	var is_superseded: bool = in_request != _request_count
	if is_superseded:
		return Resolution.superseded()
	var error: String = MsepOnline.get_response_error(in_promise)
	var has_error: bool = not error.is_empty()
	if has_error:
		return Resolution.failed(error)
	var body: Dictionary = in_promise.get_result().body
	var body_empty: bool = body.is_empty()
	if body_empty:
		return Resolution.superseded()
	return Resolution.found(body, -1)


func _get_deleted_project_message(in_project_data: Dictionary) -> String:
	var full_name: String = "%s/%s" % [in_project_data.get("namespace", ""), in_project_data.get("name", "")]
	var reason: String = in_project_data.get("deletion_reason", "")
	var deleted_at: String = str(in_project_data.get("deleted_at", "")).left(ISO_DATE_LENGTH)
	var message: String = tr("The project %s was deleted") % full_name
	if not deleted_at.is_empty():
		message += " (%s)" % deleted_at
	if not reason.is_empty():
		message += ": " + reason
	return message


class Resolution:
	var project_data: Dictionary = {}
	var version_number: int = -1
	var error: String = ""
	var is_superseded: bool = false
	
	
	static func found(in_project_data: Dictionary, in_version_number: int) -> Resolution:
		var resolution := Resolution.new()
		resolution.project_data = in_project_data
		resolution.version_number = in_version_number
		return resolution
	
	
	static func failed(in_error: String) -> Resolution:
		var resolution := Resolution.new()
		resolution.error = in_error
		return resolution
	
	
	static func superseded() -> Resolution:
		var resolution := Resolution.new()
		resolution.is_superseded = true
		return resolution
	
	
	func has_failed() -> bool:
		return not error.is_empty()
	
	
	func has_ended() -> bool:
		return is_superseded or has_failed()
