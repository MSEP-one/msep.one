extends DynamicContextControl

const _THEME_FILEPATH_TO_OPTION_ID: Dictionary = {
	"res://theme/theme_3d/available_themes/modern_theme/modern_theme.tres" = 0,
	"res://theme/theme_3d/available_themes/flat_theme/flat_theme.tres" = 1,
}


var _theme_chooser: OptionButton
var _color_palette_chooser: OptionButton
var _workspace_context: WorkspaceContext = null
var _ignore_select_signal: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_theme_chooser = $PanelContainer/ThemeChooser as OptionButton
		_color_palette_chooser = $PanelContainer2/ColorPaletteChooser as OptionButton
		for theme_filepath: String in _THEME_FILEPATH_TO_OPTION_ID:
			assert(is_instance_valid(load(theme_filepath)))
			pass
		_color_palette_chooser.clear()
		for palette: PeriodicTable.ColorPalette in PeriodicTable.ColorPalette.values():
			var palette_name: String = PeriodicTable.get_color_palette_name(palette)
			_color_palette_chooser.add_item(palette_name, palette)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		load_settings(in_workspace_context.workspace.representation_settings)
		_workspace_context.history_snapshot_applied.connect(_on_workspace_history_snapshot_applied)
	return true


func load_settings(in_settings: RepresentationSettings) -> void:
	_ignore_select_signal = true
	var theme3d: Theme3D = in_settings.get_theme()
	var current_option_id: int = _THEME_FILEPATH_TO_OPTION_ID[theme3d.resource_path]
	var current_option_idx: int = _theme_chooser.get_item_index(current_option_id)
	_theme_chooser.select(current_option_idx)
	current_option_id = in_settings.get_color_palette()
	current_option_idx = _color_palette_chooser.get_item_index(current_option_id)
	_color_palette_chooser.select(current_option_idx)
	_ignore_select_signal = false


func _on_theme_chooser_item_selected(_index: int) -> void:
	if _ignore_select_signal:
		return
	_update_settings(_workspace_context.workspace.representation_settings)


func _update_settings(out_settings: RepresentationSettings) -> void:
	var selected_id: int = _theme_chooser.get_selected_id()
	var theme_filepath: String = _THEME_FILEPATH_TO_OPTION_ID.find_key(selected_id)
	var theme_3d: Theme3D = load(theme_filepath) as Theme3D
	assert(theme_3d != null, "Could not load theme from path '%s'" % theme_filepath)
	if out_settings.get_theme() == theme_3d:
		return
	out_settings.set_theme(theme_3d)
	_workspace_context.snapshot_moment("Theme Changed")


func _on_color_palette_chooser_item_selected(_index: int) -> void:
	if _ignore_select_signal:
		return
	_update_color_palette(_workspace_context.workspace.representation_settings)


func _update_color_palette(out_settings: RepresentationSettings) -> void:
	var selected_palette: PeriodicTable.ColorPalette = _color_palette_chooser.get_selected_id() as PeriodicTable.ColorPalette
	if out_settings.get_color_palette() == selected_palette:
		return
	out_settings.set_color_palette(selected_palette)
	_workspace_context.snapshot_moment("Color Schema Changed")


func _on_workspace_history_snapshot_applied() -> void:
	var current_theme: Theme3D = _workspace_context.workspace.representation_settings.get_theme()
	var theme_path: String = current_theme.resource_path
	var theme_button_id: int = -1
	for filepath: String in _THEME_FILEPATH_TO_OPTION_ID:
		var id: int = _THEME_FILEPATH_TO_OPTION_ID[filepath]
		if filepath == theme_path:
			theme_button_id = id
	assert(theme_button_id != -1, "Theme not found in OptionButton")
	var idx: int = _theme_chooser.get_item_index(theme_button_id)
	_theme_chooser.select(idx)
	var current_palette: PeriodicTable.ColorPalette = \
			_workspace_context.workspace.representation_settings.get_color_palette()
	idx = _color_palette_chooser.get_item_index(current_palette)
	_color_palette_chooser.select(idx)


