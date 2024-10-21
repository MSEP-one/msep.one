extends NanoPopupMenu

signal request_hide

enum {
	POPUP_ID_ABOUT_MSEP_ONE = 0,
	POPUP_ID_DOCUMENTATION = 1,
}

@onready var _is_macos: bool = OS.get_name().to_lower() == "macos"

func _ready() -> void:
	super._ready()
	if _is_macos:
		# MacOS has it's own About MSEP in the Application menu
		# We remove it from the Help menu to avoid having duplicated functionality
		var idx: int = get_item_index(POPUP_ID_ABOUT_MSEP_ONE)
		remove_item(idx)


func _update_menu() -> void:
	if not _is_macos:
		var has_workspace_context: bool = MolecularEditorContext.get_current_workspace_context() != null
		var can_show_about: bool = not has_workspace_context or not BusyIndicator.is_active()
		set_item_disabled(get_item_index(POPUP_ID_ABOUT_MSEP_ONE), !can_show_about)
	set_item_disabled(get_item_index(POPUP_ID_DOCUMENTATION), false)


func _on_id_pressed(id: int) -> void:
	request_hide.emit()
	match id:
		POPUP_ID_ABOUT_MSEP_ONE:
			get_tree().notification(NOTIFICATION_WM_ABOUT)
		POPUP_ID_DOCUMENTATION:
			var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
			if workspace_context != null:
				workspace_context.action_documentation.execute()
