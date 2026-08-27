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

var _workspace_context: WorkspaceContext = null
var _selected_fragment_path: String
var _button_group := ButtonGroup.new()

func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_workspace_context = in_workspace_context
	var structure_context: StructureContext = in_workspace_context.get_current_structure_context()
	if !is_instance_valid(structure_context) || !is_instance_valid(structure_context.nano_structure):
		return false

	if not structure_context.nano_structure.can_create_and_delete_atoms():
		return false
	
	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_FRAGMENT:
		return false
	
	return true


func _ready() -> void:
	_init_fragments_ui()
	_search.text_changed.connect(_on_search_text_changed)
	_button_group.pressed.connect(_on_fragment_selected)


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
			picker_button.set_path(file_path)
			picker_button.set_thumbnail(thumbnail_path)
			picker_button.set_group(_button_group)
			var search_formatted_name: String = base_name.capitalize().to_lower()
			_fragment_map[search_formatted_name] = picker_button
			# Create up to 1 item per frame
			await get_tree().process_frame


func _on_fragment_selected(fragment_button: Button) -> void:
	var fragment_path: String = fragment_button.get_meta(&"fragment_path")
	if fragment_path == _selected_fragment_path:
		return
	_selected_fragment_path = fragment_path
	var unpacked_mol_path: String = WorkspaceUtils.unpack_mol_file_and_get_path(fragment_path)
	var absolute_path: String = ProjectSettings.globalize_path(unpacked_mol_path)
	assert(is_instance_valid(_workspace_context))
	var structure: NanoStructure = await WorkspaceUtils.get_nano_structure_from_file(_workspace_context, absolute_path, false, false, false)
	structure.set_structure_name(fragment_path.get_file().get_basename())
	_workspace_context.create_object_parameters.set_new_structure(structure)
	# HACK: for responsivemes, we will "fake" a mouse movement to ensure preview of the molecule will
	# reappear in the desired position only if the mouse is hovering the viewport
	if BusyIndicator.visible:
		# wait for busy indicator to fully dissapear, otherwise will consume the event
		await BusyIndicator.visibility_changed
		await get_tree().process_frame
	var main_viewport: Viewport = get_tree().root
	var mouse_move := InputEventMouseMotion.new()
	mouse_move.position = main_viewport.get_mouse_position()
	mouse_move.relative = Vector2.ZERO
	main_viewport.push_input(mouse_move)


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
