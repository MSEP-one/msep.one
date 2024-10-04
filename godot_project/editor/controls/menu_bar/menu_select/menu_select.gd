extends NanoPopupMenu

enum {
	ID_SELECT_ALL      = 0,
	ID_DESELECT_ALL    = 1,
	ID_SELECT_BY_TYPE  = 2,
	ID_SELECT_CONNECTED= 3,
	ID_GROW_SELECTION  = 4,
	ID_SHRINK_SELECTION= 5,
	ID_INVERT_SELECTION= 6
}

@export var shortcut_select_all: Shortcut
@export var shortcut_deselect_all: Shortcut
@export var shortcut_select_connected: Shortcut
@export var shortcut_grow_selection: Shortcut
@export var shortcut_shrink_selection: Shortcut
@export var shortcut_invert_selection: Shortcut


func _ready() -> void:
	super()
	set_item_shortcut(get_item_index(ID_SELECT_ALL), shortcut_select_all, true)
	set_item_shortcut(get_item_index(ID_DESELECT_ALL), shortcut_deselect_all, true)
	set_item_shortcut(get_item_index(ID_SELECT_CONNECTED), shortcut_select_connected, true)
	set_item_shortcut(get_item_index(ID_GROW_SELECTION), shortcut_grow_selection, true)
	set_item_shortcut(get_item_index(ID_SHRINK_SELECTION), shortcut_shrink_selection, true)
	set_item_shortcut(get_item_index(ID_INVERT_SELECTION), shortcut_invert_selection, true)


func _update_menu() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	var has_visible_structures: bool =  is_instance_valid(workspace_context) \
		and workspace_context.get_visible_structure_contexts(false).size() > 0
	var has_selection: bool = is_instance_valid(workspace_context) \
		and workspace_context.has_selection()
	var can_shrink: bool = is_instance_valid(workspace_context) \
		and workspace_context.has_cached_selection_set()
	set_item_disabled(get_item_index(ID_SELECT_ALL), !has_visible_structures)
	var has_visible_objects: bool = is_instance_valid(workspace_context) \
		and workspace_context.has_visible_objects()
	set_item_disabled(get_item_index(ID_DESELECT_ALL), !has_selection)
	set_item_disabled(get_item_index(ID_SELECT_BY_TYPE), !has_visible_structures)
	set_item_disabled(get_item_index(ID_SELECT_CONNECTED), !has_selection)
	set_item_disabled(get_item_index(ID_GROW_SELECTION), !has_selection)
	set_item_disabled(get_item_index(ID_SHRINK_SELECTION), !can_shrink)
	set_item_disabled(get_item_index(ID_INVERT_SELECTION), !has_visible_objects)


func _on_id_pressed(in_id: int) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	if !is_instance_valid(workspace_context):
		return
	match in_id:
		ID_SELECT_ALL:
			workspace_context.select_all()
		ID_DESELECT_ALL:
			workspace_context.deselect_all()
		ID_SELECT_BY_TYPE:
			MolecularEditorContext.request_workspace_docker_focus(DynamicContextDocker.UNIQUE_DOCKER_NAME, &"Select Atoms by Type")
		ID_SELECT_CONNECTED:
			workspace_context.select_connected()
		ID_GROW_SELECTION:
			workspace_context.grow_selection()
		ID_SHRINK_SELECTION:
			workspace_context.shrink_selection()
		ID_INVERT_SELECTION:
			workspace_context.invert_selection()
