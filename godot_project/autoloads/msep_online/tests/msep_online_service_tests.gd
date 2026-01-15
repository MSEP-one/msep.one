extends RefCounted

func perform_tests(
		test_current_user_endpoints: bool = true,
		test_upload_endpoints: bool = true,
		test_namespace_endpoints: bool = true,
		test_project_endpoints: bool = true,
		test_editors_endpoints: bool = true,
		test_collaborators_endpoints: bool = true,
		test_anticollaborator_endpoints: bool = true,
		test_tags_endpoints: bool = true,
		test_version_endpoints: bool = true,
		test_version_permalink_endpoints: bool = true,
		test_discovery_and_search_endpoints: bool = true,
	) -> void:
	await Engine.get_main_loop().process_frame
	
	var msep_service: MsepOnlineService = MolecularEditorContext.get_node("MsepOnlineService")
	
	if test_current_user_endpoints:
		print_rich("[color=green]  CURRENT USER ENDPOINTS  [/color]")
		await _handle_test_promise(msep_service.get_me())
		await _handle_test_promise(msep_service.put_me(
			OptionalString.new("lool i changed my bio"),
			OptionalString.empty(),
			OptionalPackedStringArray.empty(),
			OptionalString.new("my name is bob now")
			))
		await _handle_test_promise(msep_service.get_me())
		
		await _handle_test_promise(msep_service.get_me_editable())
		await _handle_test_promise(msep_service.get_me_credited())
		await _handle_test_promise(msep_service.get_me_opted_out())
		await _handle_test_promise(msep_service.delete_me("DELETE_MY_ACCOUNT", "Moving to a different platform"))
		await _handle_test_promise(msep_service.get_me())
	
	if test_upload_endpoints:
		print_rich("[color=green]  UPLOAD FILE ENDPOINTS  [/color]")
		await _handle_test_promise(msep_service.post_upload_user_avatar(FileAccess.open("res://icon.png", FileAccess.READ)))
		await _handle_test_promise(msep_service.post_upload_project_avatar("johndoe", "diamondoid-planetary-gear", FileAccess.open("res://icon.png", FileAccess.READ)))
	
	if test_namespace_endpoints:
		print_rich("[color=green]  NAMESPACE ENDPOINTS  [/color]")
		await _handle_test_promise(msep_service.get_namespace("nanoforge"))
		await _handle_test_promise(msep_service.put_namespace("nanoforge",
			OptionalString.new("nanoforge new bio"),
			OptionalString.empty(),
			OptionalPackedStringArray.new(["MSEP.one Community", "Stocks Market"])
			))
	
	if test_project_endpoints:
		print_rich("[color=green]  PROJECT ENDPOINTS  [/color]")
		await _handle_test_promise(msep_service.get_namespace_projects("nanoforge"))
		await _handle_test_promise(msep_service.post_namespace_projects("nanoforge", "my-project", "A test project", [{"name": "Jonathan", "email": "jonathan@msep.com"}], ["fun", "motors"]))
		await _handle_test_promise(msep_service.get_namespace_project("nanoforge", "my-project"))
		await _handle_test_promise(msep_service.put_namespace_project("nanoforge", "my-project",
			OptionalString.new("A test project. Transfered to johndoe"),
			OptionalArrayOfDictionaries.new([]),
			OptionalPackedStringArray.empty(),
			OptionalString.new("johndoe")
		))
		await _handle_test_promise(msep_service.get_namespace_projects("johndoe"))
		await _handle_test_promise(msep_service.delete_namespace_project("johndoe", "my-project", "I didn't make this"))
		await _handle_test_promise(msep_service.get_namespace_projects("johndoe"))
		# see graveyard
		await _handle_test_promise(msep_service.get_namespace_project("johndoe", "my-project"))
	
	if test_editors_endpoints:
		print_rich("[color=green]  EDITORS ENDPOINTS  [/color]")
		print("-----INITIAL LIST-------")
		await _handle_test_promise(msep_service.get_namespace_project_editors("johndoe", "diamondoid-planetary-gear"))
		await _handle_test_promise(msep_service.post_namespace_project_editor("johndoe", "diamondoid-planetary-gear", "nanoforge"))
		print("-----AFTER ADDING EDITOR-------")
		await _handle_test_promise(msep_service.get_namespace_project_editors("johndoe", "diamondoid-planetary-gear"))
		await _handle_test_promise(msep_service.delete_namespace_project_editor("johndoe", "diamondoid-planetary-gear", "nanoforge"))
		print("-----AFTER REMOVING EDITOR-------")
		await _handle_test_promise(msep_service.get_namespace_project_editors("johndoe", "diamondoid-planetary-gear"))
	
	if test_collaborators_endpoints:
		print_rich("[color=green]  EDITORS ENDPOINTS  [/color]")
		print("-----INITIAL LIST-------")
		await _handle_test_promise(msep_service.get_namespace_project_collaborators("johndoe", "diamondoid-planetary-gear"))
		await _handle_test_promise(msep_service.put_namespace_project_replace_collaborators(
				"johndoe", "diamondoid-planetary-gear",[
					{"name" : "Mariano", "email" : "mariano@msep.com"},
					{"name": "Jonathan", "email": "jonathan@msep.com"},
				]))
		print("-----AFTER CHANGE-------")
		await _handle_test_promise(msep_service.get_namespace_project_collaborators("johndoe", "diamondoid-planetary-gear"))
		await _handle_test_promise(msep_service.put_namespace_project_replace_collaborators("johndoe", "diamondoid-planetary-gear",[]))
		print("-----AFTER RESET-------")
		await _handle_test_promise(msep_service.get_namespace_project_collaborators("johndoe", "diamondoid-planetary-gear"))
	
	if test_anticollaborator_endpoints:
		print_rich("[color=green]  OPT-OUT ENDPOINTS  [/color]")
		await _handle_test_promise(msep_service.post_namespace_project_optout("johndoe", "diamondoid-planetary-gear"))
		await _handle_test_promise(msep_service.delete_namespace_project_optout("johndoe", "diamondoid-planetary-gear"))
	
	if test_tags_endpoints:
		print_rich("[color=green]  TAGS ENDPOINTS  [/color]")
		print("-----INITIAL LIST-------")
		await _handle_test_promise(msep_service.get_namespace_project_tags("johndoe", "diamondoid-planetary-gear"))
		await _handle_test_promise(msep_service.post_namespace_add_project_tag("johndoe", "diamondoid-planetary-gear", "springs"))
		print("-----AFTER ADDING ONE-------")
		await _handle_test_promise(msep_service.get_namespace_project_tags("johndoe", "diamondoid-planetary-gear"))
		await _handle_test_promise(msep_service.delete_namespace_project_tag("johndoe", "diamondoid-planetary-gear", "mechanical"))
		print("-----AFTER REVMOVING-------")
		await _handle_test_promise(msep_service.get_namespace_project_tags("johndoe", "diamondoid-planetary-gear"))
		await _handle_test_promise(msep_service.put_namespace_replace_project_tags("johndoe", "diamondoid-planetary-gear", ["gears", "diamondoid", "mechanical", "planetary"]))
		print("-----AFTER REPLACE-------")
		await _handle_test_promise(msep_service.get_namespace_project_tags("johndoe", "diamondoid-planetary-gear"))
	
	if test_version_endpoints:
		await _handle_test_promise(msep_service.get_namespace_project_versions("johndoe", "diamondoid-planetary-gear"))
		var file := FileAccess.open("res://template_library_files/star_gears.msep1", FileAccess.READ)
		var promise: Promise = msep_service.post_namespace_project_version("johndoe", "diamondoid-planetary-gear", "Updated version", file)
		await _handle_test_promise(promise)
		var version_number: int = promise.get_result().body.version_number
		await _handle_test_promise(msep_service.get_namespace_project_version("johndoe", "diamondoid-planetary-gear", version_number))
		await _handle_test_promise(msep_service.put_namespace_project_version("johndoe", "diamondoid-planetary-gear", version_number, "Updated description of version"))
		await _handle_test_promise(msep_service.delete_namespace_project_version("johndoe", "diamondoid-planetary-gear", version_number, "Wrong upload"))
		print("-----AFTER ALL CHANGES-----")
		await _handle_test_promise(msep_service.get_namespace_project_versions("johndoe", "diamondoid-planetary-gear"))
	
	if test_version_permalink_endpoints:
		const uuid: String = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
		await _handle_test_promise(msep_service.get_project_version(uuid))
		await _handle_download_test_promise(msep_service.download_project_version(uuid))
		await _handle_download_test_promise(msep_service.get_project_version_thumbnail(uuid))
	
	if test_discovery_and_search_endpoints:
		await _handle_test_promise(msep_service.get_explore_projects("gear"))
		await _handle_test_promise(msep_service.get_explore_tags())
		await _handle_test_promise(msep_service.get_explore_tag_projects("mechanical"))

func _handle_test_promise(p: Promise) -> void:
	await p.wait_for_fulfill()
	if p.has_error():
		print_rich("[color=red]----", p.get_meta(&"url", ""), " -> ", p.get_error(), "[/color]")
		push_error(p.get_error())
	else:
		var response: MsepOnlineHTTPRequest.ServiceResponse = p.get_result()
		print("----HTTP RESPONSE----")
		print("URL: ", response.method, " : ", response.code, " ", response.url)
		print(JSON.stringify(response.body, "\t"))

func _handle_download_test_promise(p: Promise) -> void:
	await p.wait_for_fulfill()
	if p.has_error():
		print_rich("[color=red]----", p.get_error(), "[/color]")
		push_error(p.get_error())
	else:
		var response: MsepOnlineHTTPRequest.ServiceResponse = p.get_result() as MsepOnlineHTTPRequest.ServiceResponse
		if response.code == 200:
			print("----HTTP RESPONSE----")
			print("URL: ", response.method, " : ", response.code, " ", response.url)
			print("File of ", response.raw_body.size(), " bytes")
		else:
			print_rich("[color=red]----HTTP DOWNLOAD FAILED----")
			print_rich("URL: ", response.method, " : ", response.code, " ", response.url)
			print_rich(JSON.stringify(response.body, "\t"), "[/color]")
