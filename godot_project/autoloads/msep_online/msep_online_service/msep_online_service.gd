class_name MsepOnlineService
extends Node
## Calls to the MSEP Online API: one method per endpoint.


const HttpRequestScene: PackedScene = preload("res://autoloads/msep_online/msep_online_service/msep_online_http_request/msep_online_http_request.tscn")

@onready var _requests: Node = %Requests
@onready var _msep_online_uploader: MsepOnlineUploader = %MsepOnlineUploader

@export var authenticator: MsepOnlineAuthenticator


static func get_base_url() -> String:
	if _is_using_stub_service():
		return ProjectSettings.get_setting_with_override("msep/msep_online/test_baseurl") + "/"
	return ProjectSettings.get_setting_with_override("msep/msep_online/baseurl") + "/"


static func _is_using_stub_service() -> bool:
	return FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_MSEP_ONLINE_STUB_SERVICE)


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
	await test.perform_tests(self)
	print("----DONE----")

#region : Current User Endpoints
## Get current authenticated user metadata
func get_me()-> DownloadPromise:
	return _send(HTTPClient.METHOD_GET, "me")


func _send(in_method: HTTPClient.Method, in_subpath: String, in_request_body: String = "") -> DownloadPromise:
	var request: MsepOnlineHTTPRequest = HttpRequestScene.instantiate()
	_requests.add_child(request)
	return request.send(in_method, _url_for(in_subpath), in_request_body, authenticator)


func _url_for(in_subpath: String) -> String:
	var is_full_url: bool = in_subpath.begins_with("http://") or in_subpath.begins_with("https://")
	if is_full_url:
		# In example the url of an image or binary file
		return in_subpath
	return get_base_url().path_join(in_subpath)


## Update own profile
func put_me(
		bio := OptionalString.empty(),
		primary_email := OptionalString.empty(),
		organization_affiliations := OptionalPackedStringArray.empty(),
		username := OptionalString.empty(),
	)-> DownloadPromise:
	var body: Dictionary = {}
	if bio.is_set:
		body.bio = bio.value
	if primary_email.is_set:
		body.primary_email = primary_email.value
	if organization_affiliations.is_set:
		body.organization_affiliations = Array(organization_affiliations.value)
	if username.is_set:
		body.username = username.value
	return _send(HTTPClient.METHOD_PUT, "me", JSON.stringify(body))


## List all projects the current user can edit
func get_me_editable()-> DownloadPromise:
	return _send(HTTPClient.METHOD_GET, "me/editable")


## Projects where the current user is listed as a collaborator
func get_me_credited()-> DownloadPromise:
	return _send(HTTPClient.METHOD_GET, "me/credited")



## List projects you've opted out of being credited on
func get_me_opted_out()-> DownloadPromise:
	return _send(HTTPClient.METHOD_GET, "me/opted-out")


## Delete own account
func delete_me(confirmation: String, reason: String)-> DownloadPromise:
	var body: Dictionary = {
		"confirmation" : confirmation,
		"reason" : reason,
	}
	return _send(HTTPClient.METHOD_DELETE, "me", JSON.stringify(body))
#endregion : Current User Endpoints


#region : File Upload Endpoints
## Request upload of user avatar
func post_upload_user_avatar(file: FileAccess)-> Promise:
	var file_path: String = file.get_path()
	var extension: String = file_path.get_extension().to_lower()
	if not _is_image_file(extension):
		return _invalid_image_file_promise()
	return _post_uploads("avatar", "user", "image/" + extension, file)


## Request upload of project avatar
func post_upload_project_avatar(in_namespace: String, project_name: String, file: FileAccess)-> Promise:
	var file_path: String = file.get_path()
	var extension: String = file_path.get_extension().to_lower()
	if not _is_image_file(extension):
		return _invalid_image_file_promise()
	var additional_fields: Dictionary[String,String] = {
		"namespace" : in_namespace,
		"project_name" : project_name,
	}
	return _post_uploads("avatar", "project", "image/" + extension, file, additional_fields)



func _is_image_file(in_extension: String) -> bool:
	return in_extension in ["png", "jpg", "jpeg"]


func _invalid_image_file_promise()-> Promise:
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
	)-> Promise:
	var body: Dictionary = {
		"type" : type,
		"target" : target,
		"content_type" : content_type,
		"filename" : file.get_path().get_file(),
		"size_bytes" : file.get_length()
	}
	body.merge(additional_fields)
	var create_url_promise: Promise = _send(HTTPClient.METHOD_POST, "uploads", JSON.stringify(body))
	var allow_unsafe_tls: bool = _is_using_stub_service() and get_base_url().find("http://") == 0
	return _msep_online_uploader.upload(create_url_promise, file, authenticator, allow_unsafe_tls)
#endregion : File Upload Endpoints


#region : Namespace Endpoints
## Get public profile/landing page for a user or organization
func get_namespace(in_namespace: String)-> DownloadPromise:
	return _send(HTTPClient.METHOD_GET, in_namespace.uri_encode())
#endregion : Namespace Endpoints


#region : Project Endpoints
## Create a new project
func post_namespace_projects(
		in_namespace: String,
		project_name: String,
		description: String,
		collaborators: Array[Dictionary] = [],
		tags: PackedStringArray = []
	)-> DownloadPromise:
	_validate_collaborators(collaborators)
	
	var url: String = "%s/projects" % in_namespace.uri_encode()
	var body: Dictionary = {
		"name" : project_name,
		"description" : description,
		"collaborators" : collaborators,
		"tags" : tags,
	}
	return _send(HTTPClient.METHOD_POST, url, JSON.stringify(body))


## Get project metadata
func get_namespace_project(in_namespace: String, project_name: String)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name)
	return _send(HTTPClient.METHOD_GET, url)


## Update project metadata (including ownership transfer)
func put_namespace_project(
		in_namespace: String,
		project_name: String,
		description := OptionalString.empty(),
		transfer_to_new_owner := OptionalString.empty()
	)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name)
	var body: Dictionary = {}
	if description.is_set:
		body.description = description.value
	if transfer_to_new_owner.is_set:
		body.owner = transfer_to_new_owner.value
	return _send(HTTPClient.METHOD_PUT, url, JSON.stringify(body))


func delete_namespace_project(in_namespace: String, project_name: String, reason: String)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name)
	var body: Dictionary = {
		"reason" : reason
	}
	return _send(HTTPClient.METHOD_DELETE, url, JSON.stringify(body))
#endregion : Project Endpoints


#region : Project Editors Endpoints
## List project editors
func get_namespace_project_editors(in_namespace: String, project_name: String)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/editors"
	return _send(HTTPClient.METHOD_GET, url)


## Add an editor to the project
func post_namespace_project_editor(
		in_namespace: String,
		project_name: String,
		editor_username: String
	)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/editors"
	var body: Dictionary = {
		"username" : editor_username
	}
	return _send(HTTPClient.METHOD_POST, url, JSON.stringify(body))


## Remove an editor from the project
func delete_namespace_project_editor(
		in_namespace: String,
		project_name: String,
		editor_username: String
	)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/editors/" + editor_username.uri_encode()
	return _send(HTTPClient.METHOD_DELETE, url)
#endregion : Project Editors Endpoints


#region : Project Collaborators Endpoints
## List project collaborators
func get_namespace_project_collaborators(in_namespace: String, project_name: String)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/collaborators"
	return _send(HTTPClient.METHOD_GET, url)


## Replace entire collaborator list
func put_namespace_project_replace_collaborators(
		in_namespace: String,
		project_name: String,
		new_collaborators: Array[Dictionary]
	)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/collaborators"
	var body: Dictionary = {
		"collaborators" : new_collaborators
	}
	return _send(HTTPClient.METHOD_PUT, url, JSON.stringify(body))
#endregion : Project Collaborators Endpoints


#region : Anti-Collaborator Endpoints
## Opt out of being credited on this project (add yourself as anti-collaborator).
## This endpoint will use bearer authentication to tell the service who are you, so is not
## the anonymous version that would trigger email verification
func post_namespace_project_optout(in_namespace: String, project_name: String)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/opt-out"
	return _send(HTTPClient.METHOD_POST, url)


## Remove opt-out (allow credit to be shown again)
## This endpoint will use bearer authentication to tell the service who are you, so is not
## the anonymous version that would trigger email verification
func delete_namespace_project_optout(in_namespace: String, project_name: String)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/opt-out"
	return _send(HTTPClient.METHOD_DELETE, url)
#endregion : Anti-Collaborator Endpoints


#region : Project Tags Endpoints
## List project tags
func get_namespace_project_tags(in_namespace: String, project_name: String)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/tags"
	return _send(HTTPClient.METHOD_GET, url)


## Replace all tags
func put_namespace_replace_project_tags(
		in_namespace: String,
		project_name: String,
		new_tags: PackedStringArray
	)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/tags"
	var body: Dictionary = {
		"tags" : new_tags,
	}
	return _send(HTTPClient.METHOD_PUT, url, JSON.stringify(body))
#endregion : Project Tags Endpoints


#region : Version Endpoints
## List all versions of a project
func get_namespace_project_versions(in_namespace: String, project_name: String)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/versions"
	return _send(HTTPClient.METHOD_GET, url)


## Initiate a new version upload
func post_namespace_project_version(
		in_namespace: String,
		project_name: String,
		description: String,
		file: FileAccess
	)-> Promise:
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
	return _post_uploads("version", "user", "application/octet-stream", file, additional_fields)


## Update version description
func put_namespace_project_version(
		in_namespace: String,
		project_name: String,
		version_number: int,
		description: String,
	)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/versions/%d" % version_number
	var body: Dictionary = {
		"description": description,
	}
	return _send(HTTPClient.METHOD_PUT, url, JSON.stringify(body))


## Retract a version (soft delete - file still exists but can't be downloaded)
func delete_namespace_project_version(
		in_namespace: String,
		project_name: String,
		version_number: int,
		reason: String,
	)-> DownloadPromise:
	var url: String = _project_path(in_namespace, project_name) + "/versions/%d" % version_number
	var body: Dictionary = {
		"reason" : reason,
	}
	return _send(HTTPClient.METHOD_DELETE, url, JSON.stringify(body))
#endregion : Version Endpoints


#region : Version Permalink Endpoints
## Get version metadata by UUID (the permanent, provenance-safe link)
func get_project_version(uuid: String)-> DownloadPromise:
	var url: String = "v/%s" % uuid
	return _send(HTTPClient.METHOD_GET, url)


## Download the .msep1 file
func download_project_version(uuid: String)-> DownloadPromise:
	var url: String = "v/%s/download" % uuid
	return _send(HTTPClient.METHOD_GET, url)


## A generic endpoint for downloading an image to ram
func download_image(url: String)-> DownloadPromise:
	return _send(HTTPClient.METHOD_GET, url)
#endregion : Version Permalink Endpoints


#region : Discovery & Search Endpoints
## Browse/search all public projects
func get_explore_projects(
		search: String,
		tags: PackedStringArray = [],
		sort: MsepOnline.SortType = MsepOnline.SortType.TRENDING,
		page:      int = 1,
		per_page:  int = 20
	)-> DownloadPromise:
	
	var search_querry: String = "?search=" + search.uri_encode()
	var tag_query: String = "" 
	for tag in tags:
		tag_query += "&tag=" + tag.uri_encode()
	var sort_querry: String = "&sort=" + MsepOnline.SORT_TYPE_STRING[sort]
	var page_querry: String = "&page=%d&per_page=%d" % [page, per_page]
	
	var url: String = "explore/projects" + search_querry + tag_query + sort_querry + page_querry
	
	return _send(HTTPClient.METHOD_GET, url)


## List all tags with usage counts
func get_explore_tags(sort := MsepOnline.SortType.POPULAR, limit: int = 50)-> DownloadPromise:
	var url: String = "explore/tags?sort=%s&limit=%d" % [MsepOnline.SORT_TYPE_STRING[sort], limit]
	return _send(HTTPClient.METHOD_GET, url)
#endregion : Discovery & Search Endpoints


func _project_path(in_namespace: String, in_project_name: String) -> String:
	return "%s/projects/%s" % [in_namespace.uri_encode(), in_project_name.uri_encode()]


func _validate_collaborators(collaborators: Array[Dictionary]) -> void:
	# validate_collaborators
	for colaborator: Dictionary in collaborators:
		assert(not colaborator.is_empty(), "Invalid empty collaborator")
		for key: String in colaborator.keys():
			assert(key in ["name", "email"], "Unknown key '%s' in collaborator dictionary" % key)
			pass
