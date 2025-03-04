class_name TemplateLibraryDialog extends ConfirmationDialog

const LIBRARY_PATH: String = "res://template_library_files/"
const LIBRARY_EXTENSIONS: PackedStringArray = ["pdb", "msep1"]
const THUMBNAIL_EXTENSION: String = "png"
const THUMBNAIL_FALLBACK: Texture2D = preload("res://splash.png")
const FIXED_ICON_SIZE := Vector2i(160, 120)
const ImportSettingsUI := preload("res://editor/controls/import_file_dialog/import_settings.gd")

signal file_selected(path: String,
					autogenerate_bonds: bool,
					add_missing_hydrogens: bool,
					remove_waters: bool,
					desired_placement: int,
					create_group: bool)


@onready var _item_list_library: ItemList = %ItemListLibrary
@onready var _import_settings: ImportSettingsUI = %ImportSettings


func _init() -> void:
	EditorSfx.register_window(self, true)
	hide()


func _notification(what: int) -> void:
	if what != NOTIFICATION_SCENE_INSTANTIATED:
		return
	_item_list_library = %ItemListLibrary
	_import_settings = %ImportSettings
	_item_list_library.fixed_icon_size = FIXED_ICON_SIZE
	
	window_input.connect(_on_window_input)
	about_to_popup.connect(_on_about_to_popup)
	visibility_changed.connect(_on_visibility_changed)
	_item_list_library.empty_clicked.connect(_on_item_list_library_empty_clicked)
	_item_list_library.item_selected.connect(_on_item_list_library_item_selected)
	_item_list_library.item_activated.connect(_on_item_list_library_item_activated)
	confirmed.connect(_on_confirmed)
	
	_load_library_contents()


func _load_library_contents() -> void:
	var files_in_library_dir: PackedStringArray = DirAccess.get_files_at(LIBRARY_PATH)
	
	var content_in_library: PackedStringArray = Array(files_in_library_dir).filter(_is_valid_content)
	content_in_library.sort()
	for filename in content_in_library:
		var basename: = filename.get_basename()
		var icon_path: = LIBRARY_PATH.path_join(basename) + "." + THUMBNAIL_EXTENSION
		var item_icon: Texture2D = THUMBNAIL_FALLBACK
		if ResourceLoader.exists(icon_path):
			item_icon = load(icon_path)
		var idx: int = _item_list_library.add_item(basename.capitalize(), item_icon, true)
		var path: String = LIBRARY_PATH.path_join(filename)
		_item_list_library.set_item_metadata(idx, path)


func _is_valid_content(in_filepath: String) -> bool:
	return in_filepath.get_extension().to_lower() in LIBRARY_EXTENSIONS


func _on_window_input(in_event: InputEvent) -> void:
	if Editor_Utils.process_quit_request(in_event, self):
		return
	if in_event.is_action_pressed(&"close_view", false, true):
		hide()


func _on_about_to_popup() -> void:
	_clear_selection()


func _on_visibility_changed() -> void:
	if visible:
		# WORKAROUND: List text appears aligned to the left until the
		#+window is resized. This workaround simulates that resize to force
		#+redraw with the text centered
		await get_tree().process_frame
		size.x += 1
		await get_tree().process_frame
		size.x -= 1


func _on_item_list_library_empty_clicked(
		_in_at_position: Vector2,
		in_mouse_button_index: int) -> void:
	if in_mouse_button_index == MOUSE_BUTTON_LEFT:
		_clear_selection()


func _clear_selection() -> void:
	for index in _item_list_library.get_selected_items():
		_item_list_library.deselect(index)
	get_ok_button().disabled = true


func _on_item_list_library_item_selected(_in_index: int) -> void:
	get_ok_button().disabled = false


func _on_item_list_library_item_activated(_in_index: int) -> void:
	get_ok_button().disabled = false
	_on_confirmed()

func _on_confirmed() -> void:
	assert(_item_list_library.get_selected_items().size() == 1)
	var selected: int = _item_list_library.get_selected_items()[0]
	var path: String = _item_list_library.get_item_metadata(selected)
	hide()
	file_selected.emit(path,
						is_autogenerate_bonds_enabled(),
						is_add_missing_hydrogens_enabled(),
						is_remove_waters_enabled(),
						get_desired_placement(),
						is_create_new_group_enabled())

func is_autogenerate_bonds_enabled() -> bool:
	return _import_settings.is_autogenerate_bonds_enabled()


func is_add_missing_hydrogens_enabled() -> bool:
	return _import_settings.is_add_missing_hydrogens_enabled()


func is_remove_waters_enabled() -> bool:
	return _import_settings.is_remove_waters_enabled()


func is_create_new_group_enabled() -> bool:
	return _import_settings.is_create_new_group_enabled()


func get_desired_placement() -> int:
	return _import_settings.get_desired_placement()
