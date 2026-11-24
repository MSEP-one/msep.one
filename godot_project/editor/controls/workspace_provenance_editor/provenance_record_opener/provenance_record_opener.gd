class_name ProvenanceRecordOpener extends Node

signal url_opened(url: String)
signal message_shown(title: String, text: String)

const CREATOR_PAGE_URL_TEMPLATE: String = "https://msep.one/placeholder_url/%s"

var msep_online: MsepOnline = null

@onready var _message_dialog: AcceptDialog = %MessageDialog


func _ready() -> void:
	if msep_online == null:
		msep_online = MolecularEditorContext.msep_online


func open_creator_page(in_record: ProvenanceRecord) -> void:
	var creator_url: String = CREATOR_PAGE_URL_TEMPLATE % in_record.creator.uri_encode()
	_open_url(creator_url)


func _open_url(in_url: String) -> void:
	OS.shell_open(in_url)
	url_opened.emit(in_url)


func open_record(in_record: ProvenanceRecord) -> void:
	var version_promise: DownloadPromise = msep_online.get_project_version(in_record.version_uuid)
	await version_promise.wait_for_fulfill()
	if version_promise.has_error():
		_show_server_unavailable(in_record)
		return
	var version_response: MsepOnlineResponse = version_promise.get_result() as MsepOnlineResponse
	var version_body: Dictionary = version_response.body
	var is_ok: bool = version_response.code == HTTPClient.RESPONSE_OK
	var is_retracted: bool = version_body.get("is_retracted", false) == true
	var is_forbidden: bool = version_response.code == HTTPClient.RESPONSE_FORBIDDEN
	if is_ok and not is_retracted:
		var project_data: Dictionary = version_body.get("project", {})
		_open_url(project_data.get("current_url", in_record.link))
	elif is_forbidden or is_retracted:
		_show_retracted(in_record, version_body)
	else:
		await _show_removed_or_missing(in_record)


func _show_server_unavailable(in_record: ProvenanceRecord) -> void:
	var text: String = tr(
		"The server is unavailable, so the current state of this project could not be checked.\n\n"
		+ "Project: %s\nCreator: %s\nLink: %s"
	) % [in_record.project_name, in_record.creator, in_record.link]
	_show_message(in_record.project_name, text)


func _show_message(in_title: String, in_text: String) -> void:
	_message_dialog.title = in_title
	_message_dialog.dialog_text = in_text
	_message_dialog.popup_centered(Vector2i(480, 0))
	message_shown.emit(in_title, in_text)


func _show_retracted(in_record: ProvenanceRecord, in_version_body: Dictionary) -> void:
	var reason: String = in_version_body.get("retraction_reason", "")
	var text: String = tr("This version has been retracted.") + "\n\n" + reason
	_show_message(in_record.project_name, text.strip_edges())


func _show_removed_or_missing(in_record: ProvenanceRecord) -> void:
	var project_promise: DownloadPromise = msep_online.get_namespace_project(
		in_record.project_namespace, in_record.project_name
	)
	await project_promise.wait_for_fulfill()
	if project_promise.has_error():
		_show_server_unavailable(in_record)
		return
	var project_response: MsepOnlineResponse = project_promise.get_result() as MsepOnlineResponse
	var project_body: Dictionary = project_response.body
	var is_removed: bool = project_body.get("is_deleted", false) == true
	if is_removed:
		var reason: String = project_body.get("deletion_reason", "")
		var text: String = tr("This project has been removed by its creator.") + "\n\n" + reason
		_show_message(in_record.project_name, text.strip_edges())
		return
	_show_message(in_record.project_name, tr("This project is no longer available."))
