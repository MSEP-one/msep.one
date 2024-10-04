class_name RingActionWorkspaceSettings extends RingMenuAction


var _workspace_context: WorkspaceContext = null
var _menu: NanoRingMenu = null

func _init(in_workspace_context: WorkspaceContext, out_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_menu = out_menu
	assert(_workspace_context)
	super._init(
			tr("Workspace Settings"),
			_execute_action,
			tr("Show workspace settings.")
	)
	with_validation(can_show_settings)


# This class does not overrides get_icon() because it is not
# used as a button for the ring menu, it is only used in the
# space bar menu
#func get_icon() -> RingMenuIcon:


func can_show_settings() -> bool:
	return _workspace_context != null


func _execute_action() -> void:
	if can_show_settings():
		MolecularEditorContext.request_workspace_docker_focus(WorkspaceSettingsDocker.UNIQUE_DOCKER_NAME)
		_menu.hide()
