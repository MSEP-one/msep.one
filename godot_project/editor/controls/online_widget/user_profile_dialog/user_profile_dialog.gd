class_name UserProfileDialog extends ConfirmationDialog


const DELETE_ACCOUNT_CONFIRMATION: String = "DELETE_MY_ACCOUNT"
const FALLBACK_AVATAR: Texture2D = preload("uid://b4bvg32woh5d3")


@onready var _avatar_texture_rect: TextureRect = %AvatarTextureRect
@onready var _allow_edits_check_button: CheckButton = %AllowEditsCheckButton
@onready var _username_line_edit: LineEdit = %UsernameLineEdit
@onready var _email_line_edit: LineEdit = %EmailLineEdit
@onready var _affiliations_line_edit: LineEdit = %AffiliationsLineEdit
@onready var _bio_text_edit: TextEdit = %BioTextEdit
@onready var _avatar_picker: AvatarPicker = %AvatarPicker
@onready var _error_label: Label = %ErrorLabel
@onready var _delete_account_button: Button = %DeleteAccountButton
@onready var _delete_account_dialog: DestructiveConfirmDialog = %DeleteAccountDialog
@onready var _saver: UserProfileSaver = %UserProfileSaver

var _avatar_path: String = ""


func _ready() -> void:
	MolecularEditorContext.msep_online.avatar_loaded.connect(_on_msep_online_avatar_loaded)


func open() -> void:
	_allow_edits_check_button.set_pressed_no_signal(false)
	_error_label.text = ""
	_set_editing(false)
	popup_centered()


func _set_editing(in_editing: bool) -> void:
	_username_line_edit.editable = in_editing
	_email_line_edit.editable = in_editing
	_affiliations_line_edit.editable = in_editing
	_bio_text_edit.editable = in_editing
	_avatar_picker.visible = in_editing
	_delete_account_button.visible = in_editing
	ok_button_text = tr("Save") if in_editing else tr("Close")
	get_cancel_button().visible = in_editing
	_fill_fields()
	reset_size()


func _fill_fields() -> void:
	var profile: Dictionary = MolecularEditorContext.msep_online.get_user_public_data()
	_username_line_edit.text = _text_or_empty(profile.get("username"))
	_email_line_edit.text = _text_or_empty(profile.get("primary_email"))
	_bio_text_edit.text = _text_or_empty(profile.get("bio"))
	_affiliations_line_edit.text = ", ".join(PackedStringArray(profile.get("organization_affiliations", [])))
	_avatar_path = ""
	_avatar_picker.reset()
	_update_avatar()


func _text_or_empty(in_value: Variant) -> String:
	var has_text: bool = in_value is String
	return in_value if has_text else ""


func _on_msep_online_avatar_loaded() -> void:
	_update_avatar()


func _update_avatar() -> void:
	var is_signed_in: bool = MolecularEditorContext.msep_online.is_authenticated()
	if not is_signed_in:
		return
	var avatar: Texture2D = MolecularEditorContext.msep_online.get_avatar()
	_avatar_texture_rect.texture = avatar if avatar != null else FALLBACK_AVATAR


func _on_allow_edits_check_button_toggled(in_toggled_on: bool) -> void:
	_error_label.text = ""
	_set_editing(in_toggled_on)


func _on_avatar_picker_avatar_selected(in_path: String) -> void:
	_avatar_path = in_path
	var image: Image = Image.load_from_file(in_path)
	var image_loaded: bool = image != null
	if image_loaded:
		_avatar_texture_rect.texture = ImageTexture.create_from_image(image)


func _on_confirmed() -> void:
	var is_editing: bool = _allow_edits_check_button.button_pressed
	if not is_editing:
		hide()
		return
	get_ok_button().disabled = true
	_error_label.text = ""
	var error: String = await _save()
	get_ok_button().disabled = false
	var saved: bool = error.is_empty()
	if saved:
		_allow_edits_check_button.set_pressed_no_signal(false)
		_set_editing(false)
	else:
		_error_label.text = error


## Returns an error message, or an empty string when everything was saved.
func _save() -> String:
	var new_username: String = _username_line_edit.text.strip_edges()
	var new_email: String = _email_line_edit.text.strip_edges()
	var new_affiliations: PackedStringArray = _parse_affiliations(_affiliations_line_edit.text)
	return await _saver.save_online(
			new_username, new_email, _bio_text_edit.text, new_affiliations, _avatar_path)


func _parse_affiliations(in_text: String) -> PackedStringArray:
	var affiliations: PackedStringArray = []
	for affiliation: String in in_text.split(","):
		var trimmed: String = affiliation.strip_edges()
		var is_empty: bool = trimmed.is_empty()
		if not is_empty:
			affiliations.append(trimmed)
	return affiliations


func _on_delete_account_button_pressed() -> void:
	_delete_account_dialog.ask(
		tr("Delete account"),
		tr("This permanently deletes your MSEP Community account. This cannot be undone."),
		tr("Delete account"),
		DELETE_ACCOUNT_CONFIRMATION
	)


func _on_delete_account_dialog_confirmed_with_reason(in_reason: String) -> void:
	_error_label.text = ""
	var error: String = await _saver.delete_account(DELETE_ACCOUNT_CONFIRMATION, in_reason)
	var rejected: bool = not error.is_empty()
	if rejected:
		_error_label.text = error
		return
	hide()
