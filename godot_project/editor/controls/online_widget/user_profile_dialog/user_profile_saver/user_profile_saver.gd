class_name UserProfileSaver extends Node
## Responsible for sending the edited profile and avatar of the user to MSEP Online and for deleting
## their account.


## Returns an error message, or an empty string when everything was saved.
func save_online(
		in_username: String, in_email: String, in_bio: String,
		in_affiliations: PackedStringArray, in_avatar_path: String) -> String:
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	var profile: Dictionary = msep_online.get_user_public_data()
	var username_changed: bool = in_username != _text_or_empty(profile.get("username"))
	var email_changed: bool = in_email != _text_or_empty(profile.get("primary_email"))
	var bio_changed: bool = in_bio != _text_or_empty(profile.get("bio"))
	var affiliations_changed: bool = in_affiliations != PackedStringArray(profile.get("organization_affiliations", []))
	var profile_changed: bool = username_changed or email_changed or bio_changed or affiliations_changed
	if profile_changed:
		var profile_promise: DownloadPromise = msep_online.put_me(
			OptionalString.new(in_bio) if bio_changed else OptionalString.empty(),
			OptionalString.new(in_email) if email_changed else OptionalString.empty(),
			OptionalPackedStringArray.new(in_affiliations) if affiliations_changed
					else OptionalPackedStringArray.empty(),
			OptionalString.new(in_username) if username_changed else OptionalString.empty(),
		)
		await profile_promise.wait_for_fulfill()
		var profile_error: String = MsepOnline.get_response_error(profile_promise)
		var profile_rejected: bool = not profile_error.is_empty()
		if profile_rejected:
			return profile_error
	var avatar_selected: bool = not in_avatar_path.is_empty()
	if avatar_selected:
		var avatar_error: String = await _upload_avatar(in_avatar_path)
		var avatar_rejected: bool = not avatar_error.is_empty()
		if avatar_rejected:
			return avatar_error
	var profile_reloaded: bool = await msep_online.reload_profile()
	if not profile_reloaded:
		return tr("Saved, but the updated profile could not be loaded")
	return ""


func _text_or_empty(in_value: Variant) -> String:
	var has_text: bool = in_value is String
	return in_value if has_text else ""


func _upload_avatar(in_avatar_path: String) -> String:
	var avatar_file: FileAccess = FileAccess.open(in_avatar_path, FileAccess.READ)
	var avatar_unreadable: bool = avatar_file == null
	if avatar_unreadable:
		return tr("Could not open the selected avatar file")
	var avatar_promise: Promise = MolecularEditorContext.msep_online.post_upload_user_avatar(avatar_file)
	await avatar_promise.wait_for_fulfill()
	return MsepOnline.get_response_error(avatar_promise)


## Returns an error message, or an empty string when the account was deleted and the user signed out.
func delete_account(in_confirmation: String, in_reason: String) -> String:
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	var promise: DownloadPromise = msep_online.delete_me(in_confirmation, in_reason)
	await promise.wait_for_fulfill()
	var error: String = MsepOnline.get_response_error(promise)
	var rejected: bool = not error.is_empty()
	if rejected:
		return error
	msep_online.logout()
	return ""
