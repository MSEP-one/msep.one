class_name ProjectManageRequests extends Node
## Responsible for the MSEP Online requests that load, change and delete a project in the project
## manage dialog.


## Returns the usernames of the project editors, or an error message when they could not be loaded.
func load_editors(in_namespace: String, in_name: String) -> EditorsResponse:
	var promise: DownloadPromise = MolecularEditorContext.msep_online.get_namespace_project_editors(
			in_namespace, in_name)
	await promise.wait_for_fulfill()
	var editors_response := EditorsResponse.new()
	var error: String = MsepOnline.get_response_error(promise)
	var load_failed: bool = not error.is_empty()
	if load_failed:
		editors_response.error = error
		return editors_response
	var response: MsepOnlineResponse = promise.get_result()
	for entry: Variant in response.body.get("editors", []):
		var username: String = _get_editor_username(entry)
		var has_username: bool = not username.is_empty()
		if has_username:
			editors_response.usernames.append(username)
	return editors_response


func _get_editor_username(in_entry: Variant) -> String:
	var is_dictionary: bool = in_entry is Dictionary
	if is_dictionary:
		return str(in_entry.get("username", ""))
	return str(in_entry)


## Returns an error message, or an empty string when the avatar was uploaded.
func upload_avatar(in_namespace: String, in_name: String, in_avatar_path: String) -> String:
	var avatar_file: FileAccess = FileAccess.open(in_avatar_path, FileAccess.READ)
	var avatar_unreadable: bool = avatar_file == null
	if avatar_unreadable:
		return tr("Could not open the selected avatar file")
	var promise: Promise = MolecularEditorContext.msep_online.post_upload_project_avatar(
			in_namespace, in_name, avatar_file)
	await promise.wait_for_fulfill()
	return MsepOnline.get_response_error(promise)


## Returns an error message, or an empty string when the editor was added.
func add_editor(in_namespace: String, in_name: String, in_username: String) -> String:
	var promise: DownloadPromise = MolecularEditorContext.msep_online.post_namespace_project_editor(
			in_namespace, in_name, in_username)
	await promise.wait_for_fulfill()
	var error: String = MsepOnline.get_response_error(promise)
	var rejected: bool = not error.is_empty()
	if rejected:
		return tr("Could not add editor %s: %s") % [in_username, error]
	return ""


## Returns an error message, or an empty string when the editor was removed.
func remove_editor(in_namespace: String, in_name: String, in_username: String) -> String:
	var promise: DownloadPromise = MolecularEditorContext.msep_online.delete_namespace_project_editor(
			in_namespace, in_name, in_username)
	await promise.wait_for_fulfill()
	var error: String = MsepOnline.get_response_error(promise)
	var rejected: bool = not error.is_empty()
	if rejected:
		return tr("Could not remove editor %s: %s") % [in_username, error]
	return ""


## Returns an error message, or an empty string when the project was deleted.
func delete_project(in_namespace: String, in_name: String, in_reason: String) -> String:
	var promise: DownloadPromise = MolecularEditorContext.msep_online.delete_namespace_project(
			in_namespace, in_name, in_reason)
	await promise.wait_for_fulfill()
	return MsepOnline.get_response_error(promise)


class EditorsResponse:
	var usernames: PackedStringArray = []
	var error: String = ""
