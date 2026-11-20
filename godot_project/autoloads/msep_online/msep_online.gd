class_name MsepOnline extends Node
## Entry point to MSEP Online logic

signal logged_in()
signal avatar_loaded()
signal authentication_failed(error: String)
signal device_code_issued(user_code: String, verification_uri: String)
signal logged_out()
signal profile_reloaded()


enum SortType { UPDATED, CREATED, TRENDING, POPULAR }
const SORT_TYPE_STRING: Dictionary[SortType, String] = {
	SortType.UPDATED  : "updated",
	SortType.CREATED  : "created",
	SortType.TRENDING : "trending",
	SortType.POPULAR  : "popular",
}


@onready var _msep_online_authenticator: MsepOnlineAuthenticator = %MsepOnlineAuthenticator
@onready var _msep_online_service: MsepOnlineService = %MsepOnlineService


## Returns an empty string when the request succeeded, otherwise the reason it failed or was rejected.
static func get_response_error(in_promise: Promise) -> String:
	var request_failed: bool = in_promise.has_error()
	if request_failed:
		return str(in_promise.get_error())
	var response: Variant = in_promise.get_result()
	var has_status_code: bool = response is MsepOnlineResponse
	if not has_status_code:
		return ""
	var service_response: MsepOnlineResponse = response
	var rejected_by_server: bool = service_response.code >= 400
	if not rejected_by_server:
		return ""
	var body: Dictionary = service_response.body
	var fallback: String = str(TranslationServer.translate("Server answered with HTTP %d")) % service_response.code
	var message: Variant = body.get("message", body.get("error", body.get("detail", fallback)))
	return str(message)


## Returns the address of the MSEP Online API
static func get_base_url() -> String:
	return MsepOnlineService.get_base_url()


#region : Session
func is_authenticated() -> bool:
	return _msep_online_authenticator.is_authenticated()


func get_username() -> String:
	return _msep_online_authenticator.get_username()


func get_avatar() -> Texture2D:
	return _msep_online_authenticator.get_avatar()


func get_avatar_background_color() -> Color:
	return _msep_online_authenticator.get_avatar_background_color()


## Returns the profile as the server returned it, or an empty dictionary when signed out.
## It holds username, auth_uuid, avatar (url, null when none), bio (null when empty), primary_email,
## email_visibility and organization_affiliations (names).
func get_user_public_data() -> Dictionary:
	return _msep_online_authenticator.get_user_public_data()


## Logs in through the browser and stores the resulting session.
## With in_use_device_code the user approves a code on any device instead of being redirected back to this app.
func login(in_use_device_code: bool = false) -> void:
	_msep_online_authenticator.login(in_use_device_code)


func logout() -> void:
	_msep_online_authenticator.logout()


func _on_msep_online_authenticator_logged_in() -> void:
	logged_in.emit()


func _on_msep_online_authenticator_avatar_loaded() -> void:
	avatar_loaded.emit()


func _on_msep_online_authenticator_authentication_failed(in_error: String) -> void:
	authentication_failed.emit(in_error)


func _on_msep_online_authenticator_device_code_issued(in_user_code: String, in_verification_uri: String) -> void:
	device_code_issued.emit(in_user_code, in_verification_uri)


func _on_msep_online_authenticator_logged_out() -> void:
	logged_out.emit()


func _on_msep_online_authenticator_profile_reloaded() -> void:
	profile_reloaded.emit()
#endregion : Session


#region : Current User Endpoints
## Get current authenticated user metadata
func get_me() -> DownloadPromise:
	return _msep_online_service.get_me()


## Update own profile
func put_me(
		in_bio := OptionalString.empty(),
		in_primary_email := OptionalString.empty(),
		in_organization_affiliations := OptionalPackedStringArray.empty(),
		in_username := OptionalString.empty(),
	) -> DownloadPromise:
	return _msep_online_service.put_me(in_bio, in_primary_email, in_organization_affiliations, in_username)


## List all projects the current user can edit
func get_me_editable() -> DownloadPromise:
	return _msep_online_service.get_me_editable()


## Projects where the current user is listed as a collaborator
func get_me_credited() -> DownloadPromise:
	return _msep_online_service.get_me_credited()


## List projects you've opted out of being credited on
func get_me_opted_out() -> DownloadPromise:
	return _msep_online_service.get_me_opted_out()


## Delete own account
func delete_me(in_confirmation: String, in_reason: String) -> DownloadPromise:
	return _msep_online_service.delete_me(in_confirmation, in_reason)
#endregion : Current User Endpoints


#region : File Upload Endpoints
## Request upload of user avatar
func post_upload_user_avatar(in_file: FileAccess) -> Promise:
	return _msep_online_service.post_upload_user_avatar(in_file)


## Request upload of project avatar
func post_upload_project_avatar(in_namespace: String, in_project_name: String, in_file: FileAccess) -> Promise:
	return _msep_online_service.post_upload_project_avatar(in_namespace, in_project_name, in_file)
#endregion : File Upload Endpoints


#region : Namespace Endpoints
## Get public profile/landing page for a user or organization
func get_namespace(in_namespace: String) -> DownloadPromise:
	return _msep_online_service.get_namespace(in_namespace)
#endregion : Namespace Endpoints


#region : Project Endpoints
## Create a new project
func post_namespace_projects(
		in_namespace: String,
		in_project_name: String,
		in_description: String,
		in_collaborators: Array[Dictionary] = [],
		in_tags: PackedStringArray = []
	) -> DownloadPromise:
	return _msep_online_service.post_namespace_projects(in_namespace, in_project_name, in_description,
			in_collaborators, in_tags)


## Get project metadata
func get_namespace_project(in_namespace: String, in_project_name: String) -> DownloadPromise:
	return _msep_online_service.get_namespace_project(in_namespace, in_project_name)


## Update project metadata (including ownership transfer)
func put_namespace_project(
		in_namespace: String,
		in_project_name: String,
		in_description := OptionalString.empty(),
		in_transfer_to_new_owner := OptionalString.empty()
	) -> DownloadPromise:
	return _msep_online_service.put_namespace_project(in_namespace, in_project_name, in_description,
			in_transfer_to_new_owner)


func delete_namespace_project(in_namespace: String, in_project_name: String, in_reason: String) -> DownloadPromise:
	return _msep_online_service.delete_namespace_project(in_namespace, in_project_name, in_reason)
#endregion : Project Endpoints


#region : Project Editors Endpoints
## List project editors
func get_namespace_project_editors(in_namespace: String, in_project_name: String) -> DownloadPromise:
	return _msep_online_service.get_namespace_project_editors(in_namespace, in_project_name)


## Add an editor to the project
func post_namespace_project_editor(in_namespace: String, in_project_name: String,
		in_editor_username: String) -> DownloadPromise:
	return _msep_online_service.post_namespace_project_editor(in_namespace, in_project_name, in_editor_username)


## Remove an editor from the project
func delete_namespace_project_editor(in_namespace: String, in_project_name: String,
		in_editor_username: String) -> DownloadPromise:
	return _msep_online_service.delete_namespace_project_editor(in_namespace, in_project_name, in_editor_username)
#endregion : Project Editors Endpoints


#region : Project Collaborators Endpoints
## List project collaborators
func get_namespace_project_collaborators(in_namespace: String, in_project_name: String) -> DownloadPromise:
	return _msep_online_service.get_namespace_project_collaborators(in_namespace, in_project_name)


## Replace entire collaborator list
func put_namespace_project_replace_collaborators(
		in_namespace: String,
		in_project_name: String,
		in_new_collaborators: Array[Dictionary]
	) -> DownloadPromise:
	return _msep_online_service.put_namespace_project_replace_collaborators(in_namespace,
			in_project_name, in_new_collaborators)
#endregion : Project Collaborators Endpoints


#region : Anti-Collaborator Endpoints
## Opt out of being credited on this project (add yourself as anti-collaborator).
func post_namespace_project_optout(in_namespace: String, in_project_name: String) -> DownloadPromise:
	return _msep_online_service.post_namespace_project_optout(in_namespace, in_project_name)


## Remove opt-out (allow credit to be shown again)
func delete_namespace_project_optout(in_namespace: String, in_project_name: String) -> DownloadPromise:
	return _msep_online_service.delete_namespace_project_optout(in_namespace, in_project_name)
#endregion : Anti-Collaborator Endpoints


#region : Project Tags Endpoints
## List project tags
func get_namespace_project_tags(in_namespace: String, in_project_name: String) -> DownloadPromise:
	return _msep_online_service.get_namespace_project_tags(in_namespace, in_project_name)


## Replace all tags
func put_namespace_replace_project_tags(in_namespace: String, in_project_name: String,
		in_new_tags: PackedStringArray) -> DownloadPromise:
	return _msep_online_service.put_namespace_replace_project_tags(in_namespace, in_project_name, in_new_tags)
#endregion : Project Tags Endpoints


#region : Version Endpoints
## List all versions of a project
func get_namespace_project_versions(in_namespace: String, in_project_name: String) -> DownloadPromise:
	return _msep_online_service.get_namespace_project_versions(in_namespace, in_project_name)


## Initiate a new version upload
func post_namespace_project_version(
		in_namespace: String,
		in_project_name: String,
		in_description: String,
		in_file: FileAccess
	) -> Promise:
	return _msep_online_service.post_namespace_project_version(in_namespace, in_project_name, in_description, in_file)


## Update version description
func put_namespace_project_version(
		in_namespace: String,
		in_project_name: String,
		in_version_number: int,
		in_description: String,
	) -> DownloadPromise:
	return _msep_online_service.put_namespace_project_version(in_namespace, in_project_name,
			in_version_number, in_description)


## Retract a version (soft delete - file still exists but can't be downloaded)
func delete_namespace_project_version(
		in_namespace: String,
		in_project_name: String,
		in_version_number: int,
		in_reason: String,
	) -> DownloadPromise:
	return _msep_online_service.delete_namespace_project_version(in_namespace, in_project_name,
			in_version_number, in_reason)
#endregion : Version Endpoints


#region : Version Permalink Endpoints
## Get version metadata by UUID (the permanent, provenance-safe link)
func get_project_version(in_uuid: String) -> DownloadPromise:
	return _msep_online_service.get_project_version(in_uuid)


## Download the .msep1 file
func download_project_version(in_uuid: String) -> DownloadPromise:
	return _msep_online_service.download_project_version(in_uuid)


## A generic endpoint for downloading an image to ram
func download_image(in_url: String) -> DownloadPromise:
	return _msep_online_service.download_image(in_url)
#endregion : Version Permalink Endpoints


#region : Discovery & Search Endpoints
## Browse/search all public projects
func get_explore_projects(
		in_search: String,
		in_tags: PackedStringArray = [],
		in_sort: SortType = SortType.TRENDING,
		in_page: int = 1,
		in_per_page: int = 20
	) -> DownloadPromise:
	return _msep_online_service.get_explore_projects(in_search, in_tags, in_sort, in_page, in_per_page)


## List all tags with usage counts
func get_explore_tags(in_sort: SortType = SortType.POPULAR, in_limit: int = 50) -> DownloadPromise:
	return _msep_online_service.get_explore_tags(in_sort, in_limit)
#endregion : Discovery & Search Endpoints
