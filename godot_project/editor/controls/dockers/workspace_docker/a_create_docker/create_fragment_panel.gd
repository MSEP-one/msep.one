extends DynamicContextControl


const FRAGMENTS_FOLDER: String = "res://chemical_structures/"
const CategoryContainer: PackedScene = preload("res://editor/controls/category_container/CategoryContainer.tscn")
const FragmentPickerButton: PackedScene = preload("./controls/fragment_picker_button.tscn")


var _fragment_map: Dictionary = {
#	search_formatted_name<String> = picker_button<FragmentPickerButton>
}

@onready var _fragments_container: VBoxContainer = %FragmentsContainer
@onready var _search: LineEdit = %Search
@onready var _no_search_result_found: Label = %NoSearchResultFound
@onready var _group_check_box: CheckBox = %GroupCheckBox


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	var structure_context: StructureContext = in_workspace_context.get_current_structure_context()
	if !is_instance_valid(structure_context) || !is_instance_valid(structure_context.nano_structure):
		return false

	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_FRAGMENT:
		return false
	
	if not in_workspace_context.create_object_parameters.create_small_molecule_in_subgroup_changed.is_connected(
			_on_create_small_molecule_in_subgroup_changed):
		in_workspace_context.create_object_parameters.create_small_molecule_in_subgroup_changed.connect(
			_on_create_small_molecule_in_subgroup_changed)
		_group_check_box.set_pressed_no_signal(in_workspace_context.create_object_parameters.get_create_small_molecule_in_subgroup())
	
	return true


func _ready() -> void:
	_init_fragments_ui()
	_search.text_changed.connect(_on_search_text_changed)
	_group_check_box.toggled.connect(_on_group_check_box_toggled)
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	_update_group_checkbox_visibility()


## Creates the UI controls for each fragment found in the fragments folder.
## Every folder on the root level is a type of fragment. These folders should
## contain .mol files and their associated .png thumbnails.
## If the thumbnail is missing or invalid, a default icon will be displayed.
func _init_fragments_ui() -> void:
	# Start next frame, we want to initialize workspace as fast as possible
	await get_tree().process_frame
	_fragment_map.clear()
	var fragment_types: PackedStringArray = DirAccess.get_directories_at(FRAGMENTS_FOLDER)
	
	for type in fragment_types:
		var type_path: String = FRAGMENTS_FOLDER.path_join(type)
		var fragment_files: PackedStringArray = DirAccess.get_files_at(type_path)
		if fragment_files.is_empty():
			continue # Ignore empty folders
		
		# Put every fragments of the same type in a collapsable category
		var category: Control = CategoryContainer.instantiate()
		category.title = type.capitalize().to_upper()
		_fragments_container.add_child(category)
		
		for file in fragment_files:
			if not file.ends_with(".mol"):
				continue # Ignore the thumbnails
			var base_name: String = file.get_basename()
			var file_path: String = type_path.path_join(file)
			var thumbnail_path: String = type_path.path_join(base_name) + ".png"
			var picker_button := FragmentPickerButton.instantiate()
			category.add_control(picker_button)
			picker_button.set_text(base_name.capitalize())
			picker_button.set_thumbnail(thumbnail_path)
			picker_button.selected.connect(_on_fragment_selected.bind(file_path))
			var search_formatted_name: String = base_name.capitalize().to_lower()
			_fragment_map[search_formatted_name] = picker_button
			# Create up to 1 item per frame
			await get_tree().process_frame


func _on_fragment_selected(fragment_path: String) -> void:
	var unpacked_mol_path: String = _unpack_mol_file_and_get_path(fragment_path)
	var absolute_path: String = ProjectSettings.globalize_path(unpacked_mol_path)
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	assert(is_instance_valid(workspace_context))
	var structure: NanoStructure = await WorkspaceUtils.get_nano_structure_from_file(workspace_context, absolute_path, false, false, false)
	structure.set_structure_name(fragment_path.get_file().get_basename())
	workspace_context.create_object_parameters.set_new_structure(structure)


func _unpack_mol_file_and_get_path(fragment_path: String) -> String:
	assert(fragment_path.begins_with("res://"), "Unexpected file path")
	var unpacked_path: String = fragment_path.replace("res://", "user://")
	if FileAccess.file_exists(unpacked_path):
		# Check if has changed
		var local_fragment_md5: String = FileAccess.get_md5(fragment_path)
		var user_fragment_md5: String = FileAccess.get_md5(unpacked_path)
		if local_fragment_md5 == user_fragment_md5:
			# file is up to date
			return unpacked_path
	var dir_path: String = ProjectSettings.globalize_path(unpacked_path).get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file: FileAccess = FileAccess.open(unpacked_path, FileAccess.WRITE)
	assert(file != null, "Could not initialize FileAccess on path " + unpacked_path)
	file.store_buffer(FileAccess.get_file_as_bytes(fragment_path))
	file.close()
	return unpacked_path


func _update_group_checkbox_visibility() -> void:
	var can_create_in_new_group: bool = FeatureFlagManager.get_flag_value( \
			FeatureFlagManager.FEATURE_FLAGS_ALLOW_CREATE_SMALL_MOLECULES_IN_NEW_GROUP)
	_group_check_box.visible = can_create_in_new_group
	if not can_create_in_new_group:
		_group_check_box.set_pressed_no_signal(false)


func _on_search_text_changed(text: String) -> void:
	text = text.capitalize().to_lower().strip_edges()
	if text.is_empty():
		# Search is empty, show everything
		for fragment: String in _fragment_map:
			_fragment_map[fragment].visible = true
		for category in _fragments_container.get_children():
			category.visible = true
			category.expanded = false
		_no_search_result_found.hide()
		return
	
	# Only show matching fragments
	for id: String in _fragment_map:
		_fragment_map[id].visible = id.contains(text) or id.similarity(text) >= 0.5
	
	# Hide empty categories
	var has_visible_results: bool = false
	for category in _fragments_container.get_children():
		if category.has_visible_content():
			category.visible = true
			category.expanded = true
			has_visible_results = true
		else:
			category.visible = false
	
	# Show a warning if nothing matches the search query
	_no_search_result_found.visible = not has_visible_results


func _on_group_check_box_toggled(in_pressed: bool) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	workspace_context.create_object_parameters.set_create_small_molecule_in_subgroup(in_pressed)


func _on_create_small_molecule_in_subgroup_changed(in_enabled: bool) -> void:
	_group_check_box.set_pressed_no_signal(in_enabled)


func _on_feature_flag_toggled(in_path: String, _in_value: bool) -> void:
	if in_path != FeatureFlagManager.FEATURE_FLAGS_ALLOW_CREATE_SMALL_MOLECULES_IN_NEW_GROUP:
		return
	_update_group_checkbox_visibility()
