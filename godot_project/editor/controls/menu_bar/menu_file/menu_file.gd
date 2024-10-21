extends NanoPopupMenu

signal request_hide

enum {
	POPUP_ID_NEW_WORKSPACE = 0,
	POPUP_ID_OPEN_WORKSPACE = 1,
	POPUP_ID_SAVE_WORKSPACE = 2,
	POPUP_ID_SAVE_WORKSPACE_AS = 3,
	POPUP_ID_IMPORT_PDB = 4,
	POPUP_ID_IMPORT_FROM_LIBRARY = 5,
	POPUP_ID_LOAD_FRAGMENT = 6,
	POPUP_ID_CLOSE_WORKSPACE = 7,
	POPUP_ID_EXPORT_FILE = 9,
}


@export var shortcut_new: Shortcut = null
@export var shortcut_open: Shortcut = null
@export var shortcut_save: Shortcut = null
@export var shortcut_save_as: Shortcut = null
@export var shortcut_import_pdb: Shortcut = null
@export var shortcut_export_file: Shortcut = null
@export var shortcut_close_workspace: Shortcut = null
@export var shortcut_close_workspace_macos: Shortcut = null


var _last_workspace_frame: int = 0

signal file_popup_requested


func _ready() -> void:
	super._ready()
	set_item_shortcut(
		get_item_index(POPUP_ID_NEW_WORKSPACE),
		shortcut_new
	)
	set_item_shortcut(
		get_item_index(POPUP_ID_OPEN_WORKSPACE),
		shortcut_open
	)
	set_item_shortcut(
		get_item_index(POPUP_ID_SAVE_WORKSPACE),
		shortcut_save
	)
	set_item_shortcut(
		get_item_index(POPUP_ID_SAVE_WORKSPACE_AS),
		shortcut_save_as
	)
	set_item_shortcut(
		get_item_index(POPUP_ID_IMPORT_PDB),
		shortcut_import_pdb
	)
	set_item_shortcut(
		get_item_index(POPUP_ID_EXPORT_FILE),
		shortcut_export_file
	)
	set_item_shortcut(
		get_item_index(POPUP_ID_CLOSE_WORKSPACE),
		shortcut_close_workspace_macos if OS.get_name().to_lower() == "macos" else shortcut_close_workspace
	)


func _update_menu() -> void:
	var has_workspace: bool = MolecularEditorContext.get_current_workspace_context() != null
	set_item_disabled(get_item_index(POPUP_ID_IMPORT_FROM_LIBRARY), !has_workspace)
	set_item_disabled(get_item_index(POPUP_ID_LOAD_FRAGMENT), !has_workspace)
	var can_save: bool = MolecularEditorContext.get_current_workspace() != null
	set_item_disabled(get_item_index(POPUP_ID_SAVE_WORKSPACE), !can_save)
	set_item_disabled(get_item_index(POPUP_ID_SAVE_WORKSPACE_AS), !can_save)
	set_item_disabled(get_item_index(POPUP_ID_CLOSE_WORKSPACE), !can_save)
	set_item_disabled(get_item_index(POPUP_ID_EXPORT_FILE), !can_save)


func _on_id_pressed(id: int) -> void:
	request_hide.emit()
	match id:
		POPUP_ID_NEW_WORKSPACE:
			var frame: int = Engine.get_frames_drawn()
			if _last_workspace_frame == frame:
				# Dont allow to create more than 1 workspace per frame
				return
			_last_workspace_frame = frame
			MolecularEditorContext.create_workspace()
		POPUP_ID_OPEN_WORKSPACE:
			Editor_Utils.get_editor().show_open_workspace_dialog()
		POPUP_ID_SAVE_WORKSPACE:
			var workspace: Workspace = MolecularEditorContext.get_current_workspace()
			assert(workspace)
			MolecularEditorContext.save_workspace(workspace, workspace.resource_path)
		POPUP_ID_SAVE_WORKSPACE_AS:
			var workspace: Workspace = MolecularEditorContext.get_current_workspace()
			assert(workspace)
			Editor_Utils.get_editor().show_save_workspace_dialog(workspace)
		POPUP_ID_IMPORT_PDB:
			file_popup_requested.emit()
		POPUP_ID_EXPORT_FILE:
			var workspace: Workspace = MolecularEditorContext.get_current_workspace()
			assert(workspace)
			MolecularEditorContext.export_workspace(workspace)
		POPUP_ID_IMPORT_FROM_LIBRARY:
			var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
			if workspace_context != null:
				workspace_context.action_import_from_library.execute()
		POPUP_ID_CLOSE_WORKSPACE:
			if not get_viewport().is_input_handled():
				get_viewport().set_input_as_handled()
			var workspace: Workspace = MolecularEditorContext.get_current_workspace()
			if workspace == null:
				return
			MolecularEditorContext.request_close_workspace(workspace)
		POPUP_ID_LOAD_FRAGMENT:
			var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
			if workspace_context != null:
				workspace_context.action_load_fragment.execute()
