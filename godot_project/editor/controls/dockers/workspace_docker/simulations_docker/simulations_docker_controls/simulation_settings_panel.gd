extends DynamicContextControl

const _MENU_ITEM_SHOW_USER_FILES: int = 0

var _force_field_option_button: OptionButton
var _advanced_menu_button: MenuButton
var _extension_option_button: OptionButton
var _extension_advanced_menu_button: MenuButton
var _extensions_info_label: InfoLabel
var _user_forcefield_info_label: InfoLabel


var _workspace_context: WorkspaceContext


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_initialized(in_workspace_context)
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_force_field_option_button = %ForceFieldOptionButton as OptionButton
		_advanced_menu_button = %AdvancedMenuButton as MenuButton
		_extension_option_button = %ExtensionOptionButton as OptionButton
		_extension_advanced_menu_button = %ExtensionAdvancedMenuButton as MenuButton
		_extensions_info_label = %ExtensionsInfoLabel as InfoLabel
		_user_forcefield_info_label = %UserForcefieldInfoLabel as InfoLabel
		_advanced_menu_button.get_popup().id_pressed.connect(_on_advanced_menu_button_id_pressed)
		_extension_advanced_menu_button.get_popup().id_pressed.connect(_on_extension_advanced_menu_button_id_pressed)
		_force_field_option_button.item_selected.connect(_on_force_field_option_button_item_selected)
		_extension_option_button.item_selected.connect(_on_extension_option_button_item_selected)


func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if not is_instance_valid(_workspace_context):
		_workspace_context = in_workspace_context
		_workspace_context.simulation_started.connect(_on_workspace_context_simulation_started)
		_workspace_context.simulation_finished.connect(_on_workspace_context_simulation_finished)
		var forcefield_popup: PopupMenu = _advanced_menu_button.get_popup()
		forcefield_popup.set_item_checked(forcefield_popup.get_item_index(_MENU_ITEM_SHOW_USER_FILES),
					_workspace_context.workspace.simulation_settings_show_user_defined_forcefields)
		ScriptUtils.call_deferred_once(_update_forcefields_list)
		var extension_popup: PopupMenu = _extension_advanced_menu_button.get_popup()
		extension_popup.set_item_checked(extension_popup.get_item_index(_MENU_ITEM_SHOW_USER_FILES),
					_workspace_context.workspace.simulation_settings_show_user_defined_extensions)
		ScriptUtils.call_deferred_once(_update_extensions_list)


func _on_advanced_menu_button_id_pressed(in_item_id: int) -> void:
	if in_item_id == _MENU_ITEM_SHOW_USER_FILES:
		_workspace_context.workspace.simulation_settings_show_user_defined_forcefields = \
				not _workspace_context.workspace.simulation_settings_show_user_defined_forcefields
		if not _workspace_context.workspace.simulation_settings_show_user_defined_forcefields:
			# Because custom fircefields are being disabled lets check if the current forcefield is
			# in the user defined or not. If it is, we switch for the default one
			var is_user_defined_forcefield: bool = OpenMM.utils.is_user_defined_forcefield(_get_selected_forcefield())
			if is_user_defined_forcefield:
				_workspace_context.workspace.simulation_settings_forcefield = OpenMMUtils.DEFAULT_FORCEFIELD
		var forcefield_popup: PopupMenu = _advanced_menu_button.get_popup()
		forcefield_popup.set_item_checked(forcefield_popup.get_item_index(_MENU_ITEM_SHOW_USER_FILES),
					_workspace_context.workspace.simulation_settings_show_user_defined_forcefields)
		ScriptUtils.call_deferred_once(_update_forcefields_list)


func _on_extension_advanced_menu_button_id_pressed(in_item_id: int) -> void:
	if in_item_id == _MENU_ITEM_SHOW_USER_FILES:
		_workspace_context.workspace.simulation_settings_show_user_defined_extensions = \
				not _workspace_context.workspace.simulation_settings_show_user_defined_extensions
		if not _workspace_context.workspace.simulation_settings_show_user_defined_extensions:
			# Because custom fircefields extensions are being disabled lets check if the current extension
			# in the user defined or not. If it is, we switch for the default one
			var is_user_defined_extension: bool = OpenMM.utils.is_user_defined_extension(_get_selected_extension())
			if is_user_defined_extension:
				_workspace_context.workspace.simulation_settings_forcefield_extension = OpenMMUtils.DEFAULT_FORCEFIELD
		var extension_popup: PopupMenu = _extension_advanced_menu_button.get_popup()
		extension_popup.set_item_checked(extension_popup.get_item_index(_MENU_ITEM_SHOW_USER_FILES),
					_workspace_context.workspace.simulation_settings_show_user_defined_extensions)
		ScriptUtils.call_deferred_once(_update_extensions_list)


func _on_force_field_option_button_item_selected(_in_index: int) -> void:
	_workspace_context.workspace.simulation_settings_forcefield = _get_selected_forcefield()
	_update_user_forcefield_info_label()


func _on_extension_option_button_item_selected(_in_index: int) -> void:
	_workspace_context.workspace.simulation_settings_forcefield_extension = _get_selected_extension()
	_update_extensions_info_label()
	_update_user_forcefield_info_label()


func _on_workspace_context_simulation_started() -> void:
	_force_field_option_button.disabled = true
	_advanced_menu_button.disabled = true
	_extension_option_button.disabled = true
	_extension_advanced_menu_button.disabled = true


func _on_workspace_context_simulation_finished() -> void:
	_force_field_option_button.disabled = false
	_advanced_menu_button.disabled = false
	_extension_option_button.disabled = false
	_extension_advanced_menu_button.disabled = false


func _update_forcefields_list() -> void:
	var forcefields: Array = OpenMM.utils.get_all_forcefield_filenames()
	if _workspace_context.workspace.simulation_settings_show_user_defined_forcefields:
		forcefields.append_array(OpenMM.utils.get_user_defined_forcefields())
	var forcefield_map: Dictionary = OpenMM.utils.make_forcefield_descriptions(forcefields)
	_force_field_option_button.set_block_signals(true) # avoid emiting signals while being populated
	_force_field_option_button.clear()
	var idx: int = -1
	for filename: String in forcefield_map.keys():
		idx += 1
		var description: String = forcefield_map[filename]
		_force_field_option_button.add_item(description, idx)
		_force_field_option_button.set_item_metadata(idx, filename)
		if _workspace_context.workspace.simulation_settings_forcefield == filename:
			_force_field_option_button.select(idx)
	_force_field_option_button.set_block_signals(false) # resule emiting signals
	_update_user_forcefield_info_label()


func _update_extensions_list() -> void:
	var extensions: Array = OpenMM.utils.get_all_forcefield_extensions()
	if _workspace_context.workspace.simulation_settings_show_user_defined_extensions:
		extensions.append_array(OpenMM.utils.get_user_defined_forcefield_extensions())
	var extensions_map: Dictionary = OpenMM.utils.make_forcefield_descriptions(extensions)
	_extension_option_button.set_block_signals(true) # avoid emiting signals while being populated
	_extension_option_button.clear()
	var idx: int = -1
	for filename: String in extensions_map.keys():
		idx += 1
		var description: String = extensions_map[filename]
		_extension_option_button.add_item(description, idx)
		_extension_option_button.set_item_metadata(idx, filename)
		if _workspace_context.workspace.simulation_settings_forcefield_extension == filename:
			_extension_option_button.select(idx)
	_extension_option_button.set_block_signals(false) # resule emiting signals
	_update_extensions_info_label()
	_update_user_forcefield_info_label()


func _get_selected_forcefield() -> String:
	var idx: int = _force_field_option_button.selected
	var filename: String = str(_force_field_option_button.get_item_metadata(idx))
	return filename


func _get_selected_extension() -> String:
	var idx: int = _extension_option_button.selected
	var filename: String = str(_extension_option_button.get_item_metadata(idx))
	return filename


func _update_extensions_info_label() -> void:
	var extension: String = _get_selected_extension()
	var extension_in_use: bool = not extension.is_empty() and not OpenMM.utils.is_user_defined_extension(extension)
	_extensions_info_label.visible = extension_in_use


func _update_user_forcefield_info_label() -> void:
	var is_user_defined_forcefield: bool = OpenMM.utils.is_user_defined_forcefield(_get_selected_forcefield())
	var is_user_defined_extension: bool = OpenMM.utils.is_user_defined_extension(_get_selected_extension())
	_user_forcefield_info_label.visible = is_user_defined_forcefield or is_user_defined_extension
