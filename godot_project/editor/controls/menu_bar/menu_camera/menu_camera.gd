extends NanoPopupMenu

signal request_hide


enum {
	ID_CAPTURE_CAMERA_IMAGE            = 0,
}


@export var shortcut_capture_camera_image: Shortcut


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	set_item_shortcut(get_item_index(ID_CAPTURE_CAMERA_IMAGE), shortcut_capture_camera_image, true)


func _update_menu() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	_update_for_context(workspace_context)


func _update_for_context(in_context: WorkspaceContext) -> void:
	var has_context: bool = is_instance_valid(in_context)
	set_item_disabled(get_item_index(ID_CAPTURE_CAMERA_IMAGE), !has_context)
	if has_context:
		var has_visible_objects: bool = in_context.get_visible_structure_contexts().size() > 0
		set_item_disabled(get_item_index(ID_CAPTURE_CAMERA_IMAGE), !has_visible_objects)


func _on_id_pressed(in_id: int) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	match in_id:
		ID_CAPTURE_CAMERA_IMAGE:
			request_hide.emit()
			WorkspaceUtils.open_screen_capture_dialog(workspace_context)

