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
	if MolecularEditorContext.msep_online.is_authenticated():
		return RingMenuSpriteIconScn.instantiate().init(preload("uid://drrewdy8nf4vu"))
	else:
		return RingMenuSpriteIconScn.instantiate().init(preload("uid://cnudgevu20a6g"))


func get_title() -> String:
	if MolecularEditorContext.msep_online.is_authenticated():
		return tr(&"Sign Off")
	else:
		return tr(&"Sign In")


func get_description() -> String:
	if MolecularEditorContext.msep_online.is_authenticated():
		return tr(&"Close session of your MSEP Community user account.")
	else:
		return tr(&"Open session of your MSEP Community user account.")


func _execute_action() -> void:
	_ring_menu.close()
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	var is_signed_in: bool = msep_online.is_authenticated()
	if is_signed_in:
		msep_online.logout()
	else:
		msep_online.login()
