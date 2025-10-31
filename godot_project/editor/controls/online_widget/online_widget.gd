extends HBoxContainer


enum MenuID{
	USER_PROFILE = 0,
	PROJECTS = 1,
	EDIT_PROFILE = 2,
	SIGN_OFF = 3,
}


@onready var _sign_in_container: PanelContainer = %SignInContainer
@onready var _sign_in_button: Button = %SignInButton


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
	if MolecularEditorContext.authenticator.is_authenticated():
		_setup_authenticated()
	else:
		_setup_unauthenticated()
	if _sign_in_button.pressed.is_connected(_on_sign_in_button_pressed):
		return
	MolecularEditorContext.authenticator.logged_in.connect(_setup_authenticated)
	MolecularEditorContext.authenticator.logged_out.connect(_setup_unauthenticated)
	MolecularEditorContext.authenticator.avatar_loaded.connect(_update_avatar)
	MolecularEditorContext.authenticator.authentication_failed.connect(_on_authentication_failed)
	_sign_in_button.pressed.connect(_on_sign_in_button_pressed)
	_user_menu_button.get_popup().id_pressed.connect(_on_user_menu_button_popup_id_pressed)


func _setup_authenticated() -> void:
	var auth: MsepOnlineAuthenticator = MolecularEditorContext.authenticator
	assert(auth.is_authenticated(), "Function _setup_authenticated was triggered when user is not authenticated")
	_sign_in_container.hide()
	_signed_in_container.show()
	_username.text = auth.get_username()
	var profile_index: int = _user_menu_button.get_popup().get_item_index(MenuID.USER_PROFILE)
	_user_menu_button.get_popup().set_item_text(profile_index, _username.text)
	_update_avatar()


func _setup_unauthenticated() -> void:
	_sign_in_container.show()
	_signed_in_container.hide()


func _update_avatar() -> void:
	var auth: MsepOnlineAuthenticator = MolecularEditorContext.authenticator
	assert(auth.is_authenticated(), "Function _setup_authenticated was triggered when user is not authenticated")
	_avatar_mask_texture_rect.self_modulate = auth.get_avatar_background_color()
	var avatar: Texture2D = auth.get_avatar()
	if avatar == null:
		_avatar_texture_rect.hide()
		_capitals.show()
		_capitals.text = ""
		var capitalized_username: String = auth.get_username().capitalize()
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
	if !OS.is_debug_build():
		push_error("Login is unimplemented!")
		return
	# This is a dummy implementation of login, will be replaced in the future
	DisplayServer.dialog_input_text("Log In (Temporal UI)", "Username", "", _on_username_entered.call_deferred)


func _on_username_entered(in_username: String) -> void:
	if in_username.is_empty():
		_on_authentication_failed()
		return
	DisplayServer.dialog_input_text("Log In (Temporal UI)", "Password", "", _on_password_entered.bind(in_username).call_deferred)


func _on_password_entered(in_password: String, in_username: String) -> void:
	if in_password.is_empty():
		_on_authentication_failed()
		return
	MolecularEditorContext.authenticator.login(in_username, in_password)


func _on_authentication_failed() -> void:
	DisplayServer.dialog_show("Failed", "Invalid username or password", ["OK"], Callable())


func _on_user_menu_button_popup_id_pressed(in_id: int) -> void:
	match in_id:
		MenuID.SIGN_OFF:
			MolecularEditorContext.authenticator.logout()
		_:
			DisplayServer.dialog_show(
				"Unimplemented",
				"Unimplemented option: " + MenuID.find_key(in_id),
				["OK"], Callable())
