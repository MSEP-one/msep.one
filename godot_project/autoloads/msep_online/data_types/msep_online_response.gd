class_name MsepOnlineResponse extends RefCounted
## Responsible for holding one answer of the MSEP Online server: status code, headers and body.


var url: String
var method: String
var code := HTTPClient.ResponseCode.RESPONSE_NOT_FOUND
var raw_body: PackedByteArray
var body: Dictionary = {
	# Errors (any endpoint):
	# message<String>: error_text<String>
	# error<String>: error_code<String>
	# detail<String>: error_text<String>
	# error_description<String>: error_text<String>
	#
	# OAuth device flow / tokens:
	# device_code<String>: polling_secret<String>
	# user_code<String>: code_typed_by_user<String>
	# verification_uri<String>: url<String>
	# verification_uri_complete<String>: url_with_user_code<String>
	# interval<String>: seconds<int>
	# expires_in<String>: seconds<int>
	# access_token<String>: token<String>
	# refresh_token<String>: token<String>
	#
	# Profile (me / namespace):
	# username<String>: username_also_namespace<String>
	# auth_uuid<String>: account_id<String>
	# avatar<String>: image_url<String>
	# organization_affiliations<String>: [organization_name<String>, (...)]
	#
	# Project search / listings:
	# projects<String>: [project_entry<Dictionary>, (...)]
	# opted_out_projects<String>: [project_entry<Dictionary>, (...)]
	# editors<String>: [{username<String>: username<String>}, (...)]
	# editors<String>: [username<String>, (...)]
	# pagination<String>: {
	#	total_pages<String>: count<int>
	#	(...)
	# }
	# tags<String>: [{name<String>: tag<String>, count<String>: usage_count<int>}, (...)]
	#
	# Project entry:
	# namespace<String>: owner_name<String>
	# name<String>: project_name<String>
	# description<String>: text<String>
	# current_url<String>: project_page_url<String>
	# owner<String>: {
	#	username<String>: username<String>
	#	profile_url<String>: url<String>
	# }
	# creator<String>: {
	#	username<String>: username<String>
	# }
	# collaborators<String>: [{name<String>: name<String>, email<String>: email<String>}, (...)]
	# tags<String>: [tag<String>, (...)]
	# role<String>: role_in_credited_project<String>
	# download_count<String>: count<int>
	# latest_version<String>: project_version<Dictionary>
	# latest_version_info<String>: project_version_preferred_over_latest_version<Dictionary>
	# is_deleted<String>: true/false
	# deleted_at<String>: iso_date<String>
	# deletion_reason<String>: text<String>
	# opted_out_at<String>: iso_date<String>
	#
	# Project version:
	# uuid<String>: version_uuid<String>
	# version_number<String>: number<int>
	# created_at<String>: iso_date<String>
	# description<String>: text<String>
	# thumbnail<String>: image_url<String>
	# project<String>: {
	#	namespace<String>: owner_name<String>
	#	name<String>: project_name<String>
	#	current_url<String>: project_page_url<String>
	# }
	# is_retracted<String>: true/false
	# retraction_reason<String>: text<String>
	#
	# Upload request:
	# upload_url<String>: url<String>
}
var response_headers: PackedStringArray
