class_name OnlineWidget extends HBoxContainer


enum MenuID{
	USER_PROFILE = 0,
	PROJECTS = 1,
	SIGN_OFF = 2,
	CREDITS = 3,
}


const MENU_ICON_MAX_WIDTH: int = 16
const MENU_EXTRA_HEIGHT: int = 8


@onready var _sign_in_container: PanelContainer = %SignInContainer
@onready var _sign_in_button: Button = %SignInButton
@onready var _sign_in_with_code_button: Button = %SignInWithCodeButton
@onready var _device_code_dialog: DeviceCodeDialog = %DeviceCodeDialog
@onready var _user_profile_dialog: UserProfileDialog = %UserProfileDialog
@onready var _credits_dialog: CreditsDialog = %CreditsDialog
@onready var _error_dialog: NanoAcceptDialog = %ErrorDialog


@onready var _signed_in_container: PanelContainer = %SignedInContainer
@onready var _avatar_mask_texture_rect: TextureRect = %AvatarMaskTextureRect
@onready var _avatar_texture_rect: TextureRect = %AvatarTextureRect
@onready var _capitals: Label = %Capitals
@onready var _username: Label = %Username
@onready var _user_menu_button: MenuButton = %UserMenuButton


func _ready() -> void:
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_MSEP_ONLINE) == false:
		hide()
		return
	_initialize()


func _on_feature_flag_toggled(in_path: String, in_value: bool) -> void:
	if in_path != FeatureFlagManager.FEATURE_FLAGS_MSEP_ONLINE:
		return
	if in_value:
		_initialize()
	else:
		hide()


func _initialize() -> void:
	show()
	if MolecularEditorContext.msep_online.is_authenticated():
		_setup_authenticated()
	else:
		_setup_unauthenticated()
	if _sign_in_button.pressed.is_connected(_on_sign_in_button_pressed):
		return
	MolecularEditorContext.msep_online.logged_in.connect(_setup_authenticated)
	MolecularEditorContext.msep_online.logged_out.connect(_setup_unauthenticated)
	MolecularEditorContext.msep_online.avatar_loaded.connect(_update_avatar)
	MolecularEditorContext.msep_online.profile_reloaded.connect(_on_msep_online_profile_reloaded)
	MolecularEditorContext.msep_online.authentication_failed.connect(_on_msep_online_authentication_failed)
	MolecularEditorContext.msep_online.device_code_issued.connect(_on_msep_online_device_code_issued)
	_sign_in_button.pressed.connect(_on_sign_in_button_pressed)
	var user_menu_popup: PopupMenu = _user_menu_button.get_popup()
	user_menu_popup.add_theme_constant_override(&"icon_max_width", MENU_ICON_MAX_WIDTH)
	user_menu_popup.about_to_popup.connect(_on_user_menu_button_popup_about_to_popup)
	user_menu_popup.id_pressed.connect(_on_user_menu_button_popup_id_pressed)


func _setup_authenticated() -> void:
	_device_code_dialog.hide()
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	assert(msep_online.is_authenticated(), "Function _setup_authenticated was triggered when user is not authenticated")
	_sign_in_container.hide()
	_sign_in_with_code_button.hide()
	_signed_in_container.show()
	_username.text = msep_online.get_username()
	var profile_index: int = _user_menu_button.get_popup().get_item_index(MenuID.USER_PROFILE)
	_user_menu_button.get_popup().set_item_text(profile_index, _username.text)
	_update_avatar()


func _setup_unauthenticated() -> void:
	_sign_in_container.show()
	_sign_in_with_code_button.show()
	_signed_in_container.hide()


func _update_avatar() -> void:
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	assert(msep_online.is_authenticated(), "Function _setup_authenticated was triggered when user is not authenticated")
	_avatar_mask_texture_rect.self_modulate = msep_online.get_avatar_background_color()
	var avatar: Texture2D = msep_online.get_avatar()
	if avatar == null:
		_avatar_texture_rect.hide()
		_capitals.show()
		_capitals.text = ""
		var capitalized_username: String = msep_online.get_username().capitalize()
		for c: String in capitalized_username:
			if c >= "A" and c <= "Z":
				_capitals.text += c
				if _capitals.text.length() >= 2:
					break
	else:
		_avatar_texture_rect.show()
		_capitals.hide()
		_avatar_texture_rect.texture = avatar


func _on_sign_in_button_pressed() -> void:
	MolecularEditorContext.msep_online.login()


func _on_sign_in_with_code_button_pressed() -> void:
	MolecularEditorContext.msep_online.login(true)


func _on_msep_online_authentication_failed(in_error: String) -> void:
	_device_code_dialog.hide()
	_error_dialog.title = tr("Failed")
	_error_dialog.dialog_text = in_error
	_error_dialog.popup_centered()


func _on_msep_online_profile_reloaded() -> void:
	_setup_authenticated()


func _on_msep_online_device_code_issued(in_user_code: String, in_verification_uri: String) -> void:
	_device_code_dialog.show_code(in_user_code, in_verification_uri)


func open_user_profile() -> void:
	_user_profile_dialog.open()


func _on_user_menu_button_popup_about_to_popup() -> void:
	var user_menu_popup: PopupMenu = _user_menu_button.get_popup()
	user_menu_popup.min_size.y = int(user_menu_popup.get_contents_minimum_size().y) + MENU_EXTRA_HEIGHT


func _on_user_menu_button_popup_id_pressed(in_id: int) -> void:
	match in_id:
		MenuID.SIGN_OFF:
			MolecularEditorContext.msep_online.logout()
		MenuID.USER_PROFILE:
			open_user_profile()
		MenuID.CREDITS:
			_credits_dialog.open()
		_:
			DisplayServer.dialog_show(
				"Unimplemented",
				"Unimplemented option: " + MenuID.find_key(in_id),
				["OK"], Callable())

