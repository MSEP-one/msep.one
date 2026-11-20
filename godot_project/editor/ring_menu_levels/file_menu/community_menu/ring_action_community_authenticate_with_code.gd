class_name RingActionCommunityAuthenticateWithCode extends RingMenuAction

const RingMenuSpriteIconScn = preload(
		"res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Sign In with Code"),
		_execute_action,
		tr("Sign in by entering a code in any browser, for when the regular sign in cannot return to the app.")
	)
	with_validation(_is_signed_out)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("uid://cnudgevu20a6g"))


func _is_signed_out() -> bool:
	return not MolecularEditorContext.msep_online.is_authenticated()


func _execute_action() -> void:
	_ring_menu.close()
	MolecularEditorContext.msep_online.login(true)
