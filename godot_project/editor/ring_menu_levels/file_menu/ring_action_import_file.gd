class_name RingActionImportFile extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")
const OpenmmWarningDialog = preload("res://autoloads/openmm/alert_controls/openmm_alert_dialog.tscn")
const _ARMSTRONGS_TO_NANOMETERS: float = 0.1
# Set this constant to false if need to debug [ProteinDataBaseFormatLoader]
const _LOAD_FILE_IN_THREAD: bool = true

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null
var _import_dialog: ImportFileDialog = null

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	var molecular_editor: MolecularEditor = Editor_Utils.get_editor()
	_import_dialog = molecular_editor.import_file_dialog
	_import_dialog.file_selected.connect(_on_file_dialog_file_selected)
	super._init(
		tr("Import File"),
		_execute_action,
		tr("Import a Protein File."),
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_file/icons/import_file.svg"))


func _execute_action() -> void:
	if _import_dialog.visible:
		_import_dialog.grab_focus()
		return
	_ring_menu.close()
	_import_dialog.popup_centered_ratio(0.5)


func _on_file_dialog_file_selected(path: String) -> void:
	var active_workspace: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	var is_part_of_active_workspace: bool = _workspace_context == active_workspace and is_instance_valid(active_workspace)
	if not is_part_of_active_workspace:
		return
	
	_ring_menu.close()
	
	var is_valid_extension: bool = FileUtils.file_has_valid_extension(path, _import_dialog.filters)
	if not is_valid_extension:
		var extension: String = path.get_extension()
		var message: String = tr(&"Cannot import {0}\n\nFile has an unsupported extension '{1}' and cannot be imported.")
		message = message.format([path, extension])
		_workspace_context.show_warning_dialog(message, tr(&"OK"))
		return
	
	var generate_bonds: bool = _import_dialog.is_autogenerate_bonds_enabled()
	var add_hydrogens: bool = _import_dialog.is_add_missing_hydrogens_enabled()
	var remove_waters: bool = _import_dialog.is_remove_waters_enabled()
	var placement: ImportFileDialog.Placement = _import_dialog.get_desired_placement()
	var create_new_group: bool = _import_dialog.is_create_new_group_enabled()
	WorkspaceUtils.import_file(_workspace_context, path, generate_bonds, add_hydrogens, remove_waters, placement, create_new_group)
