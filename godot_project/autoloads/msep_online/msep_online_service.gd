class_name MsepOnlineService
extends Node


enum SortType { UPDATED, FIRST_CREATED, AUTHOR, TRENDING, POPULAR }
const SORT_TYPE_STRING: Dictionary[SortType, String] = {
	SortType.UPDATED       : "updated",
	SortType.FIRST_CREATED : "first_created",
	SortType.AUTHOR        : "author",
	SortType.TRENDING      : "trending",
	SortType.POPULAR       : "popular",
}


func _ready() -> void:
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)


func _on_feature_flag_toggled(path: String, new_value: bool) -> void:
	if path != FeatureFlagManager.FEATURE_FLAGS_MSEP_ONLINE_RUN_TESTS or new_value == false:
		return
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_MSEP_ONLINE_STUB_SERVICE) == false:
		MolecularEditorContext.get_current_workspace_context().get_editor_viewport_container().show_warning_in_message_bar(
			"Cannot run tests because FEATURE_FLAGS_MSEP_ONLINE_STUB_SERVICE is disabled"
		)
		return
	_test_msep_online()


func _test_msep_online() -> void:
	var test: RefCounted = load("res://autoloads/msep_online/tests/msep_online_service_tests.gd").new()
	await test.perform_tests()
	print("----DONE----")


#region : Current User Endpoints
## Get current authenticated user metadata
func get_me() -> Promise:
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, "me").get_promise()


## Update own profile
func put_me(
		bio := OptionalString.empty(),
		primary_email := OptionalString.empty(),
		organization_affiliations := OptionalPackedStringArray.empty(),
		username := OptionalString.empty(),
	) -> Promise:
	var body: Dictionary = {}
	if bio.is_set:
		body.bio = bio.value
	if primary_email.is_set:
		body.primary_email = primary_email.value
	if organization_affiliations.is_set:
		body.organization_affiliations = Array(organization_affiliations.value)
	if username.is_set:
		body.username = username.value
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_PUT, "me", JSON.stringify(body)).get_promise()


## List all projects the current user can edit
func get_me_editable() -> Promise:
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, "me/editable").get_promise()


## Projects where the current user is listed as a collaborator
func get_me_credited() -> Promise:
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, "me/credited").get_promise()



## List projects you've opted out of being credited on
func get_me_opted_out() -> Promise:
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, "me/opted-out").get_promise()


## Delete own account
func delete_me(confirmation: String, reason: String) -> Promise:
	var body: Dictionary = {
		"confirmation" : confirmation,
		"reason" : reason,
	}
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_DELETE, "me", JSON.stringify(body)).get_promise()
#endregion : Current User Endpoints


#region : File Upload Endpoints
## Request upload of user avatar
func post_upload_user_avatar(file: FileAccess) -> Promise:
	var file_path: String = file.get_path()
	var extension: String = file_path.get_extension().to_lower()
	if not _is_image_file(extension):
		return _invalid_image_file_promise()
	return _post_uploads("avatar", "user", "image/" + extension, file)


## Request upload of project avatar
func post_upload_project_avatar(in_namespace: String, project_name: String, file: FileAccess) -> Promise:
	var file_path: String = file.get_path()
	var extension: String = file_path.get_extension().to_lower()
	if not _is_image_file(extension):
		return _invalid_image_file_promise()
	var additional_fields: Dictionary[String,String] = {
		"namespace" : in_namespace,
		"project_name" : project_name,
	}
	return _post_uploads("avatar", "user", "image/" + extension, file, additional_fields)



func _is_image_file(in_extension: String) -> bool:
	return in_extension in ["png", "jpg", "jpeg"]


func _invalid_image_file_promise() -> Promise:
	var fail := Promise.new()
	fail.fail("Invalid image file format")
	return fail


## Request an upload URL for any file type
func _post_uploads(
		type: String,
		target: String,
		content_type: String,
		file: FileAccess,
		additional_fields: Dictionary[String, String] = {}
	) -> Promise:
	var promise := Promise.new()
	var body: Dictionary = {
		"type" : type,
		"target" : target,
		"content_type" : content_type,
		"filename" : file.get_path().get_file(),
		"size_bytes" : file.get_length()
	}
	body.merge(additional_fields)
	var create_url_promise: Promise = MsepOnlineHTTPRequest.new(
			HTTPClient.METHOD_POST, "uploads", JSON.stringify(body)).get_promise()
	_handle_upload(promise, create_url_promise, file)
	return promise


func _handle_upload(promise: Promise, create_url_promise: Promise, file: FileAccess) -> void:
	await create_url_promise.wait_for_fulfill()
	if create_url_promise.has_error():
		promise.fail(create_url_promise.get_error())
		return
	
	var response: MsepOnlineHTTPRequest.ServiceResponse = create_url_promise.get_result()
	var upload_promise: Promise = MsepOnlineUploadHTTPRequest.new(response.body.upload_url, file).get_promise()
	await upload_promise.wait_for_fulfill()
	if upload_promise.has_error():
		promise.fail(upload_promise.get_error())
	else:
		promise.fulfill(upload_promise.get_result())
#endregion : File Upload Endpoints


#region : Namespace Endpoints
## Get public profile/landing page for a user or organization
func get_namespace(in_namespace: String) -> Promise:
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, in_namespace).get_promise()


## Update profile (self or org admin)
func put_namespace(
		in_namespace: String,
		bio := OptionalString.empty(),
		primary_email := OptionalString.empty(),
		organization_affiliations := OptionalPackedStringArray.empty()
	) -> Promise:
	var body: Dictionary = {}
	if bio.is_set:
		body.bio = bio.value
	if primary_email.is_set:
		body.primary_email = primary_email.value
	if organization_affiliations.is_set:
		body.organization_affiliations = Array(organization_affiliations.value)
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_PUT, in_namespace, JSON.stringify(body)).get_promise()
#endregion : Namespace Endpoints


#region : Project Endpoints
## List projects in a namespace
func get_namespace_projects(
		in_namespace: String,
		sort:SortType = SortType.UPDATED,
		page:     int = 1,
		per_page: int = 20,
	) -> Promise:
	var url: String = "%s/projects?page=%d&per_page=%d&sort=%s" % [
		in_namespace, page, per_page, SORT_TYPE_STRING[sort]
	]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## Create a new project
func post_namespace_projects(
		in_namespace: String,
		project_name: String,
		description: String,
		collaborators: Array[Dictionary] = [],
		tags: PackedStringArray = []
	) -> Promise:
	_validate_collaborators(collaborators)
	
	var url: String = "%s/projects" % in_namespace
	var body: Dictionary = {
		"name" : project_name,
		"description" : description,
		"collaborators" : collaborators,
		"tags" : tags,
	}
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_POST, url, JSON.stringify(body)).get_promise()


## Get project metadata
func get_namespace_project(in_namespace: String, project_name: String) -> Promise:
	var url: String = "%s/projects/%s" % [in_namespace, project_name]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## Update project metadata (including ownership transfer)
func put_namespace_project(
		in_namespace: String,
		project_name: String,
		description := OptionalString.empty(),
		collaborators := OptionalArrayOfDictionaries.empty(),
		tags := OptionalPackedStringArray.empty(),
		transfer_to_new_owner := OptionalString.empty()
	) -> Promise:
	var url: String = "%s/projects/%s" % [in_namespace, project_name]
	var body: Dictionary = {}
	if description.is_set:
		body.description = description.value
	if collaborators.is_set:
		_validate_collaborators(collaborators.value)
		body.collaborators = collaborators.value
	if tags.is_set:
		body.tags = Array(tags.value)
	if transfer_to_new_owner.is_set:
		body.owner = transfer_to_new_owner.value
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_PUT, url, JSON.stringify(body)).get_promise()


## Soft delete a project (creates tombstone)
func delete_namespace_project(in_namespace: String, project_name: String, reason: String) -> Promise:
	var url: String = "%s/projects/%s" % [in_namespace, project_name]
	var body: Dictionary = {
		"reason" : reason
	}
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_DELETE, url, JSON.stringify(body)).get_promise()
#endregion : Project Endpoints


#region : Project Editors Endpoints
## List project editors
func get_namespace_project_editors(in_namespace: String, project_name: String) -> Promise:
	var url: String = "/%s/projects/%s/editors" % [in_namespace, project_name]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## Add an editor to the project
func post_namespace_project_editor(
		in_namespace: String,
		project_name: String,
		editor_username: String
	) -> Promise:
	var url: String = "/%s/projects/%s/editors" % [in_namespace, project_name]
	var body: Dictionary = {
		"username" : editor_username
	}
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_POST, url, JSON.stringify(body)).get_promise()


## Remove an editor from the project
func delete_namespace_project_editor(
		in_namespace: String,
		project_name: String,
		editor_username: String
	) -> Promise:
	var url: String = "/%s/projects/%s/editors/%s" % [in_namespace, project_name, editor_username]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_DELETE, url).get_promise()
#endregion : Project Editors Endpoints


#region : Project Collaborators Endpoints
## List project collaborators
func get_namespace_project_collaborators(in_namespace: String, project_name: String) -> Promise:
	var url: String = "%s/projects/%s/collaborators" % [in_namespace, project_name]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## Replace entire collaborator list
func put_namespace_project_replace_collaborators(
		in_namespace: String,
		project_name: String,
		new_collaborators: Array[Dictionary]
	) -> Promise:
	var url: String = "%s/projects/%s/collaborators" % [in_namespace, project_name]
	var body: Dictionary = {
		"collaborators" : new_collaborators
	}
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_PUT, url, JSON.stringify(body)).get_promise()
#endregion : Project Collaborators Endpoints


#region : Anti-Collaborator Endpoints
## Opt out of being credited on this project (add yourself as anti-collaborator).
## This endpoint will use bearer authentication to tell the service who are you, so is not
## the anonymous version that would trigger email verification
func post_namespace_project_optout(in_namespace: String, project_name: String) -> Promise:
	var url: String = "%s/projects/%s/opt-out" % [in_namespace, project_name]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_POST, url).get_promise()


## Remove opt-out (allow credit to be shown again)
## This endpoint will use bearer authentication to tell the service who are you, so is not
## the anonymous version that would trigger email verification
func delete_namespace_project_optout(in_namespace: String, project_name: String) -> Promise:
	var url: String = "%s/projects/%s/opt-out" % [in_namespace, project_name]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_DELETE, url).get_promise()
#endregion : Anti-Collaborator Endpoints


#region : Project Tags Endpoints
## List project tags
func get_namespace_project_tags(in_namespace: String, project_name: String) -> Promise:
	var url: String = "%s/projects/%s/tags" % [in_namespace, project_name]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## Replace all tags
func put_namespace_replace_project_tags(
		in_namespace: String,
		project_name: String,
		new_tags: PackedStringArray
	) -> Promise:
	var url: String = "%s/projects/%s/tags" % [in_namespace, project_name]
	var body: Dictionary = {
		"tags" : new_tags,
	}
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_PUT, url, JSON.stringify(body)).get_promise()


## Add a single tag
func post_namespace_add_project_tag(
		in_namespace: String,
		project_name: String,
		new_tag: String
	) -> Promise:
	var url: String = "%s/projects/%s/tags" % [in_namespace, project_name]
	var body: Dictionary = {
		"tag" : new_tag,
	}
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_POST, url, JSON.stringify(body)).get_promise()


## Remove a tag
func delete_namespace_project_tag(
		in_namespace: String,
		project_name: String,
		removed_tag: String
	) -> Promise:
	var url: String = "%s/projects/%s/tags/%s" % [in_namespace, project_name, removed_tag]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_DELETE, url).get_promise()
#endregion : Project Tags Endpoints


#region : Version Endpoints
## List all versions of a project
func get_namespace_project_versions(in_namespace: String, project_name: String) -> Promise:
	var url: String = "%s/projects/%s/versions" % [in_namespace, project_name]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## Initiate a new version upload
func post_namespace_project_version(
		in_namespace: String,
		project_name: String,
		description: String,
		file: FileAccess
	) -> Promise:
	var file_path: String = file.get_path()
	var extension: String = file_path.get_extension().to_lower()
	if not extension in ["msep1"]:
		var fail := Promise.new()
		fail.fail("Invalid file format")
		return fail
	var additional_fields: Dictionary[String,String] = {
		"namespace" : in_namespace,
		"project_name" : project_name,
		"description" : description
	}
	return _post_uploads("avatar", "user", "application/octet-stream", file, additional_fields)


## Get version metadata
func get_namespace_project_version(
		in_namespace: String,
		project_name: String,
		version_number: int,
	) -> Promise:
	var url: String = "%s/projects/%s/versions/%d" % [in_namespace, project_name, version_number]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## Update version description
func put_namespace_project_version(
		in_namespace: String,
		project_name: String,
		version_number: int,
		description: String,
	) -> Promise:
	var url: String = "%s/projects/%s/versions/%d" % [in_namespace, project_name, version_number]
	var body: Dictionary = {
		"description": description,
	}
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_PUT, url, JSON.stringify(body)).get_promise()


## Retract a version (soft delete - file still exists but can't be downloaded)
func delete_namespace_project_version(
		in_namespace: String,
		project_name: String,
		version_number: int,
		reason: String,
	) -> Promise:
	var url: String = "%s/projects/%s/versions/%d" % [in_namespace, project_name, version_number]
	var body: Dictionary = {
		"reason" : reason,
	}
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_DELETE, url, JSON.stringify(body)).get_promise()
#endregion : Version Endpoints


#region : Version Permalink Endpoints
## Get version metadata by UUID (the permanent, provenance-safe link)
func get_project_version(uuid: String) -> Promise:
	var url: String = "v/%s" % uuid
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## Download the .msep1 file
func download_project_version(uuid: String) -> Promise:
	var url: String = "v/%s/download" % uuid
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## Download the version thumbnail
func get_project_version_thumbnail(uuid: String) -> Promise:
	var url: String = "v/%s/thumbnail" % uuid
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()
#endregion : Version Permalink Endpoints


#region : Discovery & Search Endpoints
## Browse/search all public projects
func get_explore_projects(
		search: String,
		tags: PackedStringArray = [],
		sort: SortType = SortType.TRENDING,
		page:      int = 1,
		per_page:  int = 20
	) -> Promise:
	
	var search_querry: String = "?search=" + search
	var tag_query: String = "" 
	for tag in tags:
		tag_query += "&tag=" + tag
	var sort_querry: String = "&sort=" + SORT_TYPE_STRING[sort]
	var page_querry: String = "&page=%d&per_page=%d" % [page, per_page]
	
	var url: String = "explore/projects" + search_querry + tag_query + sort_querry + page_querry
	
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## List all tags with usage counts
func get_explore_tags(sort := SortType.POPULAR, limit: int = 50) -> Promise:
	var url: String = "explore/tags?sort=%s&limit=%d" % [SORT_TYPE_STRING[sort], limit]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()


## Projects with a specific tag
func get_explore_tag_projects(
		tag: String,
		sort: SortType = SortType.UPDATED,
		page:      int = 1,
		per_page:  int = 20,
	) -> Promise:
	
	var url: String = "explore/tags/%s?sort=%s&page=%d&per_page=%d" % [tag, SORT_TYPE_STRING[sort], page, per_page]
	return MsepOnlineHTTPRequest.new(HTTPClient.METHOD_GET, url).get_promise()
#endregion : Discovery & Search Endpoints


func _validate_collaborators(collaborators: Array[Dictionary]) -> void:
	# validate_collaborators
	for colaborator: Dictionary in collaborators:
		assert(not colaborator.is_empty(), "Invalid empty collaborator")
		for key: String in colaborator.keys():
			assert(key in ["name", "email"], "Unknown key '%s' in collaborator dictionary" % key)
			pass


