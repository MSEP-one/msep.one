class_name RingActionCommunityAuthenticate extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("OVERRIDEN"),
		_execute_action,
		tr("OVERRIDEN")
	)


func get_icon() -> RingMenuIcon:
	if MolecularEditorContext.authenticator.is_authenticated():
		return RingMenuSpriteIconScn.instantiate().init(preload("uid://drrewdy8nf4vu"))
	else:
		return RingMenuSpriteIconScn.instantiate().init(preload("uid://cnudgevu20a6g"))


func get_title() -> String:
	if MolecularEditorContext.authenticator.is_authenticated():
		return tr(&"Sign Off")
	else:
		return tr(&"Sign In")


func get_description() -> String:
	if MolecularEditorContext.authenticator.is_authenticated():
		return tr(&"Close session of your MSEP Community user account.")
	else:
		return tr(&"Open session of your MSEP Community user account.")


func _execute_action() -> void:
	_ring_menu.close()
	if !OS.is_debug_build():
		push_error("Login is unimplemented!")
		return
	# This is a dummy implementation of login, will be replaced in the future
	if MolecularEditorContext.authenticator.is_authenticated():
		MolecularEditorContext.authenticator.logout()
	else:
		DisplayServer.dialog_input_text.call_deferred("Log In (Temporal UI)", "Username", "", _on_username_entered.call_deferred)


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
