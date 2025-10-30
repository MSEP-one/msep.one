class_name RingActionCommunityShare extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Share"),
		_execute_action,
		tr("Share this project with the Community.")
	)
	with_validation(_is_authenticated)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("uid://yu8yc806jsk3"))


func _is_authenticated() -> bool:
	return MolecularEditorContext.authenticator.is_authenticated()


func _execute_action() -> void:
	_ring_menu.close()
	if _workspace_context.workspace.resource_path.is_empty() or not _workspace_context.workspace.suggested_path.is_empty():
		# File has not been saved
		var promise: Promise = _workspace_context.show_warning_dialog(
			tr(&"Project needs to be saved before it can be shared"),
			tr(&"Save"),
			tr(&"Cancel")
		)
		await promise.wait_for_fulfill()
		if promise.get_result():
			# Save
			Editor_Utils.get_editor().show_save_workspace_dialog(_workspace_context.workspace)
		return
	WorkspaceUtils.open_share_project_dialog(_workspace_context)
