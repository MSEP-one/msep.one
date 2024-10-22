class_name RingActionImportFromLibrary extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null
var _library_dialog: TemplateLibraryDialog


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	var molecular_editor: MolecularEditor = Editor_Utils.get_editor()
	_library_dialog = molecular_editor.template_library_dialog
	_library_dialog.file_selected.connect(_on_library_dialog_file_selected)
	super._init(
		tr("Import from Library"),
		_execute_action,
		tr("Import from a list of interesting samples."),
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_file/icons/import_library.svg"))


func _execute_action() -> void:
	_ring_menu.close()
	if _library_dialog.visible:
		_library_dialog.grab_focus()
		return
	_library_dialog.popup_centered_ratio(0.5)


func _on_library_dialog_file_selected(path: String,
										autogenerate_bonds: bool, add_missing_hydrogens: bool,
										remove_waters: bool, desired_placement: int,
										create_new_group: bool) -> void:
	var active_workspace: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	var is_part_of_active_workspace: bool = _workspace_context == active_workspace
	if not is_part_of_active_workspace:
		return
	var snapshot_name: String = "Import from Library"
	# Forward the event to the import file action
	WorkspaceUtils.import_file(_workspace_context, path, autogenerate_bonds,
					add_missing_hydrogens, remove_waters, desired_placement, create_new_group, snapshot_name)
