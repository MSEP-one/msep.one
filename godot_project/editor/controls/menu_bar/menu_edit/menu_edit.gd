extends NanoPopupMenu

enum {
	ID_UNDO            = 0,
	ID_REDO            = 1,
#   separator          = 2,
	ID_DELETE          = 3,
	ID_COPY            = 4,
	ID_CUT             = 5,
	ID_PASTE           = 6,
	ID_BONDED_PASTE    = 7,
}

@export var shortcut_undo: Shortcut
@export var shortcut_redo: Shortcut
@export var shortcut_copy: Shortcut
@export var shortcut_cut: Shortcut
@export var shortcut_paste: Shortcut
@export var shortcut_bonded_paste: Shortcut
@export var shortcut_delete: Shortcut
@export var shortcut_delete_macos: Shortcut


func _ready() -> void:
	super()
	set_item_shortcut(ID_UNDO, shortcut_undo, true)
	set_item_shortcut(ID_REDO, shortcut_redo, true)
	set_item_shortcut(ID_COPY, shortcut_copy, true)
	set_item_shortcut(ID_CUT, shortcut_cut, true)
	set_item_shortcut(ID_PASTE, shortcut_paste, true)
	set_item_shortcut(ID_BONDED_PASTE, shortcut_bonded_paste, true)
	if OS.get_name().to_lower() == "macos":
		set_item_shortcut(ID_DELETE, shortcut_delete_macos)
	else:
		set_item_shortcut(ID_DELETE, shortcut_delete)


func _update_menu() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	# 1. Undo/Redo
	var can_undo: bool = is_instance_valid(workspace_context) and workspace_context.can_undo()
	var can_redo: bool = is_instance_valid(workspace_context) and workspace_context.can_redo()
	set_item_disabled(ID_UNDO, !can_undo)
	set_item_disabled(ID_REDO, !can_redo)
	if is_instance_valid(workspace_context):
		var undo_description: String = workspace_context.get_undo_name()
		undo_description = undo_description if undo_description.is_empty() else "'" + undo_description + "'"
		var redo_description: String = workspace_context.get_redo_name()
		redo_description = redo_description if redo_description.is_empty() else "'" + redo_description + "'"
		set_item_text(ID_UNDO, "Undo " + undo_description)
		set_item_text(ID_REDO, "Redo " + redo_description)
	else:
		set_item_text(ID_UNDO, tr("Undo"))
		set_item_text(ID_REDO, tr("Redo"))
	set_item_disabled(ID_DELETE, !_can_delete())
	# 2. Copy
	var can_copy: bool = is_instance_valid(workspace_context) \
			and workspace_context.action_copy.can_copy()
	set_item_disabled(ID_COPY, !can_copy)
	# 3. Cut
	var can_cut: bool = is_instance_valid(workspace_context) \
			and workspace_context.action_cut.can_cut()
	set_item_disabled(ID_CUT, !can_cut)
	# 4. Paste
	var can_paste: bool = is_instance_valid(workspace_context) \
			and workspace_context.action_paste.can_paste()
	set_item_disabled(ID_PASTE, !can_paste)
	set_item_disabled(ID_BONDED_PASTE, !can_paste)


func _on_id_pressed(in_id: int) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	if !is_instance_valid(workspace_context):
		return
	match in_id:
		ID_UNDO:
			workspace_context.action_undo.execute()
		ID_REDO:
			workspace_context.action_redo.execute()
		ID_DELETE:
			workspace_context.action_delete.execute()
		ID_COPY:
			workspace_context.action_copy.execute()
			var can_paste: bool = workspace_context.action_paste.can_paste()
			set_item_disabled(ID_PASTE, !can_paste)
			set_item_disabled(ID_BONDED_PASTE, !can_paste)
		ID_CUT:
			workspace_context.action_cut.execute()
		ID_PASTE:
			workspace_context.action_paste.execute()
		ID_BONDED_PASTE:
			workspace_context.action_bonded_paste.execute()


func _can_delete() -> bool:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	if !is_instance_valid(workspace_context):
		return false
	var action_delete: RingActionDelete = workspace_context.action_delete
	if action_delete != null:
		return action_delete.can_delete()
	return false
