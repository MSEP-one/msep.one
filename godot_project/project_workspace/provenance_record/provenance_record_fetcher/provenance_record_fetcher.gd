class_name ProvenanceRecordFetcher extends RefCounted
## Builds a provenance record of an online project version from server data.


var error: String = ""

var _msep_online: MsepOnline
var _organization_by_username: Dictionary[String, String] = {
	# creator_username<String>: comma separated organization_affiliations<String>
	# (...)
}


func _init(in_msep_online: MsepOnline) -> void:
	_msep_online = in_msep_online


## Returns null and sets `error` when any of the server requests fails.
func fetch(in_version_uuid: String) -> ProvenanceRecord:
	error = ""
	var version_body: Dictionary = await _get_body(_msep_online.get_project_version(in_version_uuid))
	if not error.is_empty():
		return null
	var project_summary: Dictionary = version_body.get("project", {})
	var project_namespace: String = project_summary.get("namespace", "")
	var project_name: String = project_summary.get("name", "")
	
	var project_body: Dictionary = await _get_body(
		_msep_online.get_namespace_project(project_namespace, project_name)
	)
	if not error.is_empty():
		return null
	var creator_summary: Dictionary = project_body.get("creator", {})
	var creator_username: String = creator_summary.get("username", "")
	
	var tags_body: Dictionary = await _get_body(
		_msep_online.get_namespace_project_tags(project_namespace, project_name)
	)
	if not error.is_empty():
		return null
	var organization: String = await _get_organization(creator_username)
	if not error.is_empty():
		return null
	
	var record := ProvenanceRecord.new()
	record.version_uuid = in_version_uuid
	record.project_name = project_name
	record.project_namespace = project_namespace
	record.creator = creator_username
	record.organization = organization
	record.description = project_body.get("description", "")
	record.keywords = PackedStringArray(tags_body.get("tags", []))
	record.upload_date = version_body.get("created_at", "")
	record.link = project_summary.get("current_url", "")
	return record


func _get_body(in_promise: DownloadPromise) -> Dictionary:
	await in_promise.wait_for_fulfill()
	if in_promise.has_error():
		error = in_promise.get_error()
		return {}
	var response: MsepOnlineResponse = in_promise.get_result() as MsepOnlineResponse
	if response.code != HTTPClient.RESPONSE_OK:
		error = "%s %s answered with code %d" % [response.method, response.url, response.code]
		return {}
	return response.body


func _get_organization(in_username: String) -> String:
	if _organization_by_username.has(in_username):
		return _organization_by_username[in_username]
	var profile_body: Dictionary = await _get_body(_msep_online.get_namespace(in_username))
	if not error.is_empty():
		return ""
	var affiliations: PackedStringArray = PackedStringArray(
		profile_body.get("organization_affiliations", [])
	)
	var organization: String = ", ".join(affiliations)
	_organization_by_username[in_username] = organization
	return organization
