extends RefCounted
## Runs every MSEP Online endpoint as the logged-in user, on a temporary project in their namespace.


const TEST_VERSION_FILE: String = "res://template_library_files/star_gears.msep1"
const TEST_IMAGE_FILE: String = "res://icon.png"
const TEST_COLLABORATORS: Array[Dictionary] = [
	{"name": "Test Collaborator", "email": "collaborator@example.com"},
	{"name": "Second Collaborator", "email": "second.collaborator@example.com"},
]

var _service: MsepOnlineService
var _username: String = ""
var _project_name: String = ""
var _passed_count: int = 0
var _failures: Array[String] = []


## Every step that changes the account is reverted afterwards; in_second_username enables the
## editor add/remove steps, which need a second existing account.
func perform_tests(
		msep_service: MsepOnlineService,
		test_current_user_endpoints: bool = true,
		test_user_avatar_upload: bool = false,
		test_namespace_endpoints: bool = true,
		test_project_endpoints: bool = true,
		test_editors_endpoints: bool = true,
		test_collaborators_endpoints: bool = true,
		test_anticollaborator_endpoints: bool = true,
		test_tags_endpoints: bool = true,
		test_version_endpoints: bool = true,
		test_discovery_and_search_endpoints: bool = true,
		test_delete_account: bool = false,
		in_second_username: String = "",
	) -> void:
	await Engine.get_main_loop().process_frame
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	if not msep_online.is_authenticated():
		push_error("MSEP Online tests need a logged-in user, log in first")
		return
	_service = msep_service
	_username = msep_online.get_username()
	_project_name = "test-project-%d" % int(Time.get_unix_time_from_system())
	print_rich("[color=green]  TESTING AS %s, PROJECT %s  [/color]" % [_username, _project_name])

	if test_current_user_endpoints:
		await _test_current_user_endpoints(test_user_avatar_upload)
	if test_namespace_endpoints:
		await _test_namespace_endpoints()

	var project_created: bool = await _create_test_project()
	if project_created:
		if test_project_endpoints:
			await _test_project_endpoints()
		if test_editors_endpoints:
			await _test_editors_endpoints(in_second_username)
		if test_collaborators_endpoints:
			await _test_collaborators_endpoints()
		if test_anticollaborator_endpoints:
			await _test_anticollaborator_endpoints()
		if test_tags_endpoints:
			await _test_tags_endpoints()
		if test_version_endpoints:
			await _test_version_endpoints()
		await _delete_test_project()
	else:
		_report_skipped("Creating the test project failed, skipping all project tests")

	if test_discovery_and_search_endpoints:
		await _test_discovery_and_search_endpoints()

	if test_delete_account:
		push_warning("test_delete_account is enabled: deleting the logged-in account")
		await _handle_test_promise(_service.delete_me("DELETE_MY_ACCOUNT", "Moving to a different platform"))
		await _handle_test_promise(_service.get_me())

	_print_summary()


func _test_current_user_endpoints(in_test_avatar_upload: bool) -> void:
	print_rich("[color=green]  CURRENT USER ENDPOINTS  [/color]")
	var me_promise: Promise = _service.get_me()
	var me_loaded: bool = await _handle_test_promise(me_promise)
	if me_loaded:
		var original_profile: Dictionary = me_promise.get_result().body
		await _handle_test_promise(_service.put_me(OptionalString.new("MSEP Online test bio")))
		await _handle_test_promise(_service.get_me())
		await _restore_profile(original_profile)
	await _handle_test_promise(_service.get_me_editable())
	await _handle_test_promise(_service.get_me_credited())
	await _handle_test_promise(_service.get_me_opted_out())
	if in_test_avatar_upload:
		push_warning("test_user_avatar_upload is enabled: replacing the avatar of the logged-in account")
		var avatar_file := FileAccess.open(TEST_IMAGE_FILE, FileAccess.READ)
		await _handle_test_promise(_service.post_upload_user_avatar(avatar_file))


## Returns true when the request succeeded and the server accepted it.
func _handle_test_promise(p: Promise) -> bool:
	await p.wait_for_fulfill()
	var error: String = MsepOnline.get_response_error(p)
	var response: MsepOnlineResponse = p.get_result() as MsepOnlineResponse
	var has_response: bool = response != null
	if has_response:
		print("----HTTP RESPONSE----")
		print("URL: ", response.method, " : ", response.code, " ", response.url)
		print(JSON.stringify(response.body, "\t"))
	var succeeded: bool = error.is_empty()
	_record_result(p, error)
	return succeeded


func _record_result(in_promise: Promise, in_error: String) -> void:
	var succeeded: bool = in_error.is_empty()
	if succeeded:
		_passed_count += 1
		return
	var failure: String = "%s -> %s" % [in_promise.get_meta(&"url", ""), in_error]
	_failures.append(failure)
	print_rich("[color=red]----", failure, "[/color]")
	push_error(in_error)


func _restore_profile(in_original_profile: Dictionary) -> void:
	var original_bio: String = str(in_original_profile.get("bio", ""))
	var original_affiliations := PackedStringArray(in_original_profile.get("organization_affiliations", []))
	await _handle_test_promise(_service.put_me(
		OptionalString.new(original_bio),
		OptionalString.empty(),
		OptionalPackedStringArray.new(original_affiliations)
	))


func _test_namespace_endpoints() -> void:
	print_rich("[color=green]  NAMESPACE ENDPOINTS  [/color]")
	var namespace_promise: Promise = _service.get_namespace(_username)
	var namespace_loaded: bool = await _handle_test_promise(namespace_promise)
	if not namespace_loaded:
		return
	var original_namespace: Dictionary = namespace_promise.get_result().body
	await _handle_test_promise(_service._send(HTTPClient.METHOD_PUT, _username.uri_encode(),
			JSON.stringify({
				"bio": "MSEP Online test namespace bio",
				"organization_affiliations": ["MSEP.one Community"],
			})
			))
	await _handle_test_promise(_service.get_namespace(_username))
	await _handle_test_promise(_service._send(HTTPClient.METHOD_PUT, _username.uri_encode(),
			JSON.stringify({
				"bio": original_namespace.get("bio", ""),
				"organization_affiliations": original_namespace.get("organization_affiliations", []),
			})
			))


func _create_test_project() -> bool:
	print_rich("[color=green]  CREATE TEST PROJECT  [/color]")
	return await _handle_test_promise(_service.post_namespace_projects(_username, _project_name,
			"Temporary project created by the MSEP Online tests", [], ["test"]))


func _test_project_endpoints() -> void:
	print_rich("[color=green]  PROJECT ENDPOINTS  [/color]")
	await _handle_test_promise(_service._send(HTTPClient.METHOD_GET, "%s/projects" % _username.uri_encode()))
	await _handle_test_promise(_service.get_namespace_project(_username, _project_name))
	await _handle_test_promise(_service.put_namespace_project(_username, _project_name,
			OptionalString.new("Temporary project created by the MSEP Online tests, updated")))
	await _handle_test_promise(_service.get_namespace_project(_username, _project_name))
	var avatar_file := FileAccess.open(TEST_IMAGE_FILE, FileAccess.READ)
	await _handle_test_promise(_service.post_upload_project_avatar(_username, _project_name, avatar_file))


func _test_editors_endpoints(in_second_username: String) -> void:
	print_rich("[color=green]  EDITORS ENDPOINTS  [/color]")
	print("-----INITIAL LIST-------")
	await _handle_test_promise(_service.get_namespace_project_editors(_username, _project_name))
	var has_second_user: bool = not in_second_username.is_empty()
	if not has_second_user:
		print("Skipping adding and removing an editor, no second username given")
		return
	await _handle_test_promise(_service.post_namespace_project_editor(_username, _project_name, in_second_username))
	print("-----AFTER ADDING EDITOR-------")
	await _handle_test_promise(_service.get_namespace_project_editors(_username, _project_name))
	await _handle_test_promise(_service.delete_namespace_project_editor(_username, _project_name, in_second_username))
	print("-----AFTER REMOVING EDITOR-------")
	await _handle_test_promise(_service.get_namespace_project_editors(_username, _project_name))


func _test_collaborators_endpoints() -> void:
	print_rich("[color=green]  COLLABORATORS ENDPOINTS  [/color]")
	print("-----INITIAL LIST-------")
	await _handle_test_promise(_service.get_namespace_project_collaborators(_username, _project_name))
	await _handle_test_promise(_service.put_namespace_project_replace_collaborators(
			_username, _project_name, TEST_COLLABORATORS))
	print("-----AFTER CHANGE-------")
	await _handle_test_promise(_service.get_namespace_project_collaborators(_username, _project_name))
	await _handle_test_promise(_service.put_namespace_project_replace_collaborators(_username, _project_name, []))
	print("-----AFTER RESET-------")
	await _handle_test_promise(_service.get_namespace_project_collaborators(_username, _project_name))


func _test_anticollaborator_endpoints() -> void:
	print_rich("[color=green]  OPT-OUT ENDPOINTS  [/color]")
	await _handle_test_promise(_service.post_namespace_project_optout(_username, _project_name))
	await _handle_test_promise(_service.delete_namespace_project_optout(_username, _project_name))


func _test_tags_endpoints() -> void:
	print_rich("[color=green]  TAGS ENDPOINTS  [/color]")
	var tags_path: String = "%s/projects/%s/tags" % [_username.uri_encode(), _project_name.uri_encode()]
	print("-----INITIAL LIST-------")
	await _handle_test_promise(_service.get_namespace_project_tags(_username, _project_name))
	await _handle_test_promise(_service._send(HTTPClient.METHOD_POST, tags_path,
			JSON.stringify({"tag": "springs"})))
	print("-----AFTER ADDING ONE-------")
	await _handle_test_promise(_service.get_namespace_project_tags(_username, _project_name))
	await _handle_test_promise(_service._send(HTTPClient.METHOD_DELETE, tags_path + "/springs"))
	print("-----AFTER REMOVING-------")
	await _handle_test_promise(_service.get_namespace_project_tags(_username, _project_name))
	await _handle_test_promise(_service.put_namespace_replace_project_tags(_username, _project_name,
			["gears", "diamondoid", "mechanical", "planetary"]))
	print("-----AFTER REPLACE-------")
	await _handle_test_promise(_service.get_namespace_project_tags(_username, _project_name))


func _test_version_endpoints() -> void:
	print_rich("[color=green]  VERSION ENDPOINTS  [/color]")
	await _handle_test_promise(_service.get_namespace_project_versions(_username, _project_name))
	var file := FileAccess.open(TEST_VERSION_FILE, FileAccess.READ)
	var upload_promise: Promise = _service.post_namespace_project_version(_username, _project_name,
			"Test version", file)
	var uploaded: bool = await _handle_test_promise(upload_promise)
	if not uploaded:
		_report_skipped("Version upload failed, skipping the version tests that depend on it")
		return
	var version: Dictionary = upload_promise.get_result().body
	var version_number: int = int(version.get("version_number", 0))
	var version_uuid: String = str(version.get("uuid", ""))
	await _handle_test_promise(_service._send(HTTPClient.METHOD_GET, "%s/projects/%s/versions/%d" % [
			_username.uri_encode(), _project_name.uri_encode(), version_number]))
	await _handle_test_promise(_service.put_namespace_project_version(_username, _project_name,
			version_number, "Updated description of test version"))
	await _test_version_permalink_endpoints(version_uuid)
	await _handle_test_promise(_service.delete_namespace_project_version(_username, _project_name,
			version_number, "Test version"))
	print("-----AFTER ALL CHANGES-----")
	await _handle_test_promise(_service.get_namespace_project_versions(_username, _project_name))


func _test_version_permalink_endpoints(in_uuid: String) -> void:
	print_rich("[color=green]  VERSION PERMALINK ENDPOINTS  [/color]")
	await _handle_test_promise(_service.get_project_version(in_uuid))
	await _handle_download_test_promise(_service.download_project_version(in_uuid))
	await _handle_download_test_promise(_service._send(HTTPClient.METHOD_GET, "v/%s/thumbnail" % in_uuid))


func _handle_download_test_promise(p: Promise) -> void:
	await p.wait_for_fulfill()
	var error: String = MsepOnline.get_response_error(p)
	_record_result(p, error)
	var succeeded: bool = error.is_empty()
	if not succeeded:
		return
	var response: MsepOnlineResponse = p.get_result() as MsepOnlineResponse
	print("----HTTP RESPONSE----")
	print("URL: ", response.method, " : ", response.code, " ", response.url)
	print("File of ", response.raw_body.size(), " bytes")


func _delete_test_project() -> void:
	print_rich("[color=green]  DELETE TEST PROJECT  [/color]")
	await _handle_test_promise(_service.delete_namespace_project(_username, _project_name,
			"Temporary project created by the MSEP Online tests"))
	await _handle_test_promise(_service._send(HTTPClient.METHOD_GET, "%s/projects" % _username.uri_encode()))
	# see graveyard
	await _handle_test_promise(_service.get_namespace_project(_username, _project_name))


func _report_skipped(in_reason: String) -> void:
	_failures.append(in_reason)
	push_error(in_reason)


func _test_discovery_and_search_endpoints() -> void:
	print_rich("[color=green]  DISCOVERY AND SEARCH ENDPOINTS  [/color]")
	await _handle_test_promise(_service.get_explore_projects("gear"))
	await _handle_test_promise(_service.get_explore_tags())
	await _handle_test_promise(_service._send(HTTPClient.METHOD_GET, "explore/tags/mechanical"))


func _print_summary() -> void:
	var failed_count: int = _failures.size()
	var all_passed: bool = failed_count == 0
	var color: String = "green" if all_passed else "red"
	print_rich("[color=%s]=====  SUMMARY: %d passed, %d failed  =====[/color]" % [
			color, _passed_count, failed_count])
	for failure: String in _failures:
		print_rich("[color=red]  - %s[/color]" % failure)
