class_name SmallMoleculesPicker extends PopupPanel


signal molecule_selected(filepath: String)


const FRAGMENTS_FOLDER: String = "res://chemical_structures/"
const META_PATH: StringName = &"Path"
const META_THUMBNAIL: StringName = &"Thumbnail"

var _search_line_edit: LineEdit
var _preview_texture: TextureRect
var _small_molecules_tree: Tree


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_search_line_edit = %SearchLineEdit as LineEdit
		_preview_texture = %PreviewTexture as TextureRect
		_small_molecules_tree = %SmallMoleculesTree as Tree
		about_to_popup.connect(_search_line_edit.clear)
		about_to_popup.connect(_search_line_edit.grab_focus, CONNECT_DEFERRED)
		_search_line_edit.text_changed.connect(_on_search_line_edit_text_changed)
		_small_molecules_tree.item_selected.connect(_on_small_molecules_tree_item_selected)
		_small_molecules_tree.gui_input.connect(_on_small_molecules_tree_gui_input)
		_small_molecules_tree.mouse_exited.connect(_on_small_molecules_tree_mouse_exited)
		_init_list()
		hide()


func _on_search_line_edit_text_changed(in_text: String) -> void:
	var root: TreeItem = _small_molecules_tree.get_root()
	const COLUMN_0 = 0
	in_text = in_text.to_lower()
	for category: TreeItem in root.get_children():
		var item_text: String = category.get_text(COLUMN_0).to_lower()
		if in_text.is_empty() or item_text.contains(in_text):
			# Show all items in category
			category.visible = true
			for mol: TreeItem in category.get_children():
				mol.visible = true
		else:
			var any_visible: bool = false
			for mol: TreeItem in category.get_children():
				item_text = mol.get_text(COLUMN_0).to_lower()
				var should_show: bool = item_text.contains(in_text)
				mol.visible = should_show
				any_visible = any_visible or should_show
			category.visible = any_visible


func _on_small_molecules_tree_item_selected() -> void:
	var selected: TreeItem = _small_molecules_tree.get_selected()
	var path: String = selected.get_meta(META_PATH, String())
	if not path.is_empty():
		molecule_selected.emit(path)
		hide()


func _on_small_molecules_tree_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseMotion:
		_set_hovered_item(_small_molecules_tree.get_item_at_position(in_event.position))


func _on_small_molecules_tree_mouse_exited() -> void:
	_set_hovered_item(null)


func _set_hovered_item(in_item: TreeItem) -> void:
	var texture: Texture2D = null
	# 1. Retrieve the texture from tree item
	if in_item != null:
		var texture_or_path: Variant = in_item.get_meta(META_THUMBNAIL, String())
		if typeof(texture_or_path) == TYPE_STRING:
			# lazy load the texture on demand, and replace meta with reference
			# Categories have no path asociated, so path will be empty
			var path: String = texture_or_path as String
			if not path.is_empty():
				if ResourceLoader.exists(path):
					texture = load(path)
			in_item.set_meta(META_THUMBNAIL, texture)
		else:
			# Texture was already lazy loaded on a previous hover
			texture = texture_or_path as Texture2D
	# 2. Assign texture to preview
	if texture == null:
		# No texture, use a generic icon
		_preview_texture.texture = preload("uid://njg8vo87cuus")
		_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		_preview_texture.texture = texture
		_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _init_list() -> void:
	_small_molecules_tree.clear()
	var root: TreeItem = _small_molecules_tree.create_item()
	_small_molecules_tree.hide_root = true
	
	var fragment_types: PackedStringArray = DirAccess.get_directories_at(FRAGMENTS_FOLDER)
	fragment_types.sort()
	
	for type in fragment_types:
		var type_path: String = FRAGMENTS_FOLDER.path_join(type)
		var fragment_files: PackedStringArray = Array(DirAccess.get_files_at(type_path)).filter(_filter_mol_files)
		if fragment_files.is_empty():
			continue # Ignore empty folders
		fragment_files.sort()
		
		const COLUMN_0 = 0
		
		# Put every fragments of the same type in a collapsable category
		var category: TreeItem = _small_molecules_tree.create_item(root)
		category.set_text(COLUMN_0, type.capitalize())
		
		for file in fragment_files:
			var base_name: String = file.get_basename()
			var file_path: String = type_path.path_join(file)
			var thumbnail_path: String = type_path.path_join(base_name) + ".png"
			var item: TreeItem = _small_molecules_tree.create_item(category)
			item.set_text(COLUMN_0, base_name.capitalize())
			item.set_meta(META_PATH, file_path)
			item.set_meta(META_THUMBNAIL, thumbnail_path)


func _filter_mol_files(in_path: String) -> bool:
	return in_path.ends_with(".mol")
