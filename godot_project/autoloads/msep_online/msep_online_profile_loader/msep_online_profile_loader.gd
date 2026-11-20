class_name MsepOnlineProfileLoader extends Node
## Responsible for loading the signed-in user's profile and avatar from the MSEP Online API into the
## authenticator.


## Loads the profile again. Returns false if it could not be loaded.
func reload_profile(out_authenticator: MsepOnlineAuthenticator, in_service: MsepOnlineService) -> bool:
	var me: Dictionary = await _fetch_profile(in_service)
	var signed_out_meanwhile: bool = not out_authenticator.is_authenticated()
	if signed_out_meanwhile:
		return false
	var profile_replaced: bool = out_authenticator.replace_profile(me)
	if profile_replaced:
		_load_avatar(out_authenticator, in_service)
	return profile_replaced


## Returns the profile of the signed-in user in the shape of MsepOnline.get_user_public_data(), or an
## empty dictionary when it could not be loaded.
func _fetch_profile(in_service: MsepOnlineService) -> Dictionary:
	var profile_promise: DownloadPromise = in_service.get_me()
	await profile_promise.wait_for_fulfill()
	var profile_failed: bool = profile_promise.has_error()
	if profile_failed:
		return {}
	return profile_promise.get_result().body


## Downloads the avatar referenced by the profile, if it has one.
func _load_avatar(out_authenticator: MsepOnlineAuthenticator, in_service: MsepOnlineService) -> void:
	var avatar_url: String = out_authenticator.get_avatar_url()
	var has_avatar_url: bool = not avatar_url.is_empty()
	if not has_avatar_url:
		return
	var avatar_promise: DownloadPromise = in_service.download_image(avatar_url)
	await avatar_promise.wait_for_fulfill()
	var download_failed: bool = avatar_promise.has_error()
	var signed_out_meanwhile: bool = not out_authenticator.is_authenticated()
	if download_failed or signed_out_meanwhile:
		return
	var image: Image = DownloadableTexture.image_from_response(avatar_url, avatar_promise.get_result().raw_body)
	var image_decoded: bool = image != null and not image.is_empty()
	if not image_decoded:
		return
	out_authenticator.set_avatar_image(image)


## Loads the profile of a freshly opened session
func load_login_profile(out_authenticator: MsepOnlineAuthenticator,
		in_service: MsepOnlineService) -> void:
	var profile_promise: DownloadPromise = in_service.get_me()
	await profile_promise.wait_for_fulfill()
	var failure: String = _describe_profile_failure(profile_promise)
	var request_failed: bool = not failure.is_empty()
	if request_failed:
		out_authenticator.fail_login(failure)
		return
	var me: Dictionary = (profile_promise.get_result() as MsepOnlineResponse).body
	var login_completed: bool = out_authenticator.complete_login(me)
	if login_completed:
		_load_avatar(out_authenticator, in_service)


## Returns why the profile request did not succeed, or an empty string
func _describe_profile_failure(in_promise: DownloadPromise) -> String:
	if in_promise.has_error():
		return tr("Could not reach the MSEP Online server: %s") % in_promise.get_error()
	var status: int = (in_promise.get_result() as MsepOnlineResponse).code
	var is_server_error: bool = status >= 500
	var is_rejected: bool = status >= 300
	if is_server_error:
		return tr("The MSEP Online server is unavailable (HTTP %d), try again later") % status
	if is_rejected:
		return tr("The MSEP Online server rejected the profile request (HTTP %d)") % status
	return ""
