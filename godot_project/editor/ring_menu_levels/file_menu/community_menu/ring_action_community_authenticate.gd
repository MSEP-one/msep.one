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
		DisplayServer.dialog_input_text.call_deferred("Log In (Temporal UI)", "Email", "", _on_email_entered.call_deferred)


func _on_email_entered(in_email: String) -> void:
	const EMAIL_REGEX: StringName = "/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$/"
	var regex := RegEx.new()
	regex.compile(EMAIL_REGEX)
	var result: RegExMatch = regex.search(in_email)
	if in_email.is_empty() or result == null or result.get_string() != in_email:
		_on_authentication_failed("Invalid username or password")
		return
	var username: String = in_email.get_slice("@", 0).replace(".", "_")
	MolecularEditorContext.authenticator.login(username, in_email)


func _on_authentication_failed(in_error: String) -> void:
	DisplayServer.dialog_show("Failed", in_error, ["OK"], Callable())
