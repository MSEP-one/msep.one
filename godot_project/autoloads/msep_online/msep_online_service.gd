"@abstract_class"
class_name MsepOnlineService
extends Node


enum SortType { UPDATED, FIRST_CREATED, AUTHOR, TRENDING, POPULAR}


class ServiceResponse:
	var code := HTTPClient.ResponseCode.RESPONSE_NOT_FOUND
	var body: Dictionary
	var response_headers: PackedStringArray


var authenticator: MsepOnlineAuthenticator:
	get():
		return MolecularEditorContext.authenticator


@warning_ignore_start("unused_parameter")


#region : Current User Endpoints
## Get current authenticated user metadata
func get_me() -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Update own profile
func put_me(
		username := OptionalString.empty(),
		bio := OptionalString.empty(),
		primary_email := OptionalString.empty(),
		organization_affiliations := OptionalPackedStringArray.empty()
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## List all projects the current user can edit
func get_me_editable() -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Projects where the current user is listed as a collaborator
func get_me_credited() -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## List projects you've opted out of being credited on
func get_me_opted_out() -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Delete own account
func delete_me(confirmation: String, reason: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
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
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
#endregion : File Upload Endpoints


#region : Namespace Endpoints
## Get public profile/landing page for a user or organization
func get_namespace(in_namespace: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Update profile (self or org admin)
func put_namespace(
		in_namespace: String,
		bio := OptionalString.empty(),
		primary_email := OptionalString.empty(),
		organization_affiliations := OptionalPackedStringArray.empty()
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
#endregion : Namespace Endpoints


#region : Project Endpoints
## List projects in a namespace
func get_namespace_projects(
		in_namespace: String,
		sort:SortType = SortType.UPDATED,
		page:     int = 1,
		per_page: int = 20,
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Create a new project
func post_namespace_projects(
		project_name: String,
		description: String,
		collaborators: Array[Dictionary] = [],
		tags: PackedStringArray = []
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Get project metadata
func get_namespace_project(in_namespace: String, project_name: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Update project metadata (including ownership transfer)
func put_namespace_project(
		in_namespace: String,
		project_name: String,
		description := OptionalString.empty(),
		collaborators := OptionalArrayOfDictionaries.empty(),
		tags := OptionalPackedStringArray.empty(),
		transfer_to_new_owner := OptionalString.empty()
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Soft delete a project (creates tombstone)
func delete_namespace_project(in_namespace: String, project_name: String, reason: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
#endregion : Project Endpoints


#region : Project Editors Endpoints
## List project editors
func get_namespace_project_editors(in_namespace: String, project_name: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Add an editor to the project
func post_namespace_project_editor(
		in_namespace: String,
		project_name: String,
		editor_username: String
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Remove an editor from the project
func delete_namespace_project_editor(
		in_namespace: String,
		project_name: String,
		editor_username: String
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
#endregion : Project Editors Endpoints


#region : Project Collaborators Endpoints
## List project collaborators
func get_namespace_project_collaborators(in_namespace: String, project_name: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Replace entire collaborator list
func put_namespace_project_replace_collaborators(
		in_namespace: String,
		project_name: String,
		new_collaborators: Array[Dictionary]
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
#endregion : Project Collaborators Endpoints


#region : Anti-Collaborator Endpoints
## Opt out of being credited on this project (add yourself as anti-collaborator).
## This endpoint will use bearer authentication to tell the service who are you, so is not
## the anonymous version that would trigger email verification
func post_namespace_project_optout(in_namespace: String, project_name: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Remove opt-out (allow credit to be shown again)
## This endpoint will use bearer authentication to tell the service who are you, so is not
## the anonymous version that would trigger email verification
func delete_namespace_project_optout(in_namespace: String, project_name: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
#endregion : Anti-Collaborator Endpoints


#region : Project Tags Endpoints
## List project tags
func get_namespace_project_tags(in_namespace: String, project_name: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Replace all tags
func put_namespace_replace_project_tags(
		in_namespace: String,
		project_name: String,
		new_tags: PackedStringArray
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Add a single tag
func post_namespace_add_project_tag(
		in_namespace: String,
		project_name: String,
		new_tag: String
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Remove a tag
func delete_namespace_project_tag(
		in_namespace: String,
		project_name: String,
		removed_tag: String
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
#endregion : Project Tags Endpoints


#region : Version Endpoints
## List all versions of a project
func get_namespace_project_versions(in_namespace: String, project_name: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


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
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Update version description
func put_namespace_project_version(
		in_namespace: String,
		project_name: String,
		version_number: int,
		description: String,
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Retract a version (soft delete - file still exists but can't be downloaded)
func delete_namespace_project_version(
		in_namespace: String,
		project_name: String,
		version_number: int,
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
#endregion : Version Endpoints


#region : Version Permalink Endpoints
## Get version metadata by UUID (the permanent, provenance-safe link)
func get_project_version(uuid: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Download the .msep1 file
func download_project_version(uuid: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Download the version thumbnail
func get_project_version_thumbnail(uuid: String) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
#endregion : Version Permalink Endpoints


#region : Discovery & Search Endpoints
## Browse/search all public projects
func get_explore_projects(
		search: String,
		tags: PackedStringArray,
		sort: SortType = SortType.TRENDING,
		page:      int = 1,
		per_page:  int = 20
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## List all tags with usage counts
func get_explore_tags(sort := SortType.POPULAR, limit: int = 50) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## Projects with a specific tag
func get_explore_tag_projects(
		tag: String,
		sort: SortType = SortType.UPDATED,
		page:      int = 1,
		per_page:  int = 20,
	) -> Promise:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null
#endregion : Discovery & Search Endpoints


@warning_ignore_restore("unused_parameter")

