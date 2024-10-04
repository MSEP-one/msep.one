class_name StructureSelectorButton extends HBoxContainer

## This class represents a button with optional "More Childs" button to display more options.
## It will not make any change by itself, only emit signals, is meant to be used by the user
## to navigate across structure hierarchy


## Emitted when the buttons representing this structure is pressed
signal structure_context_selected(out_structure_context: StructureContext)
## Emited when the "More Children" button is pressed. out_parent_structure_context
## will be [code]null[/code] if this button represents the root workspace
signal more_childs_requested(out_parent_structure_context: StructureContext, clicked_global_button_rect: Rect2)

var _workspace_context: WorkspaceContext
var _structure_context: StructureContext
var _structure_button: Button
var _more_childs_button: Button
var _initialized: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_structure_button = %StructureButton as Button
		_more_childs_button = %MoreChildsButton as Button
		_structure_button.pressed.connect(_on_structure_button_pressed)
		_more_childs_button.pressed.connect(_on_more_childs_button_pressed)


func initialize(out_workspace_context: WorkspaceContext, in_structure_context: StructureContext) -> void:
	assert(is_instance_valid(out_workspace_context), "Invalid workspace context!")
	_initialized = true
	_workspace_context = out_workspace_context
	_structure_context = in_structure_context
	if in_structure_context != null:
		in_structure_context.nano_structure.get_structure_name()
	update_controls()


func update_controls() -> void:
	assert(_initialized, "Atempted to update controls before initialization")
	var is_workspace_root: bool = _structure_context == null
	if is_workspace_root:
		_structure_button.text = tr(&"Workspace")
	else:
		_structure_button.text = _structure_context.nano_structure.get_structure_name()
	if _has_children_not_in_path(null if is_workspace_root else _structure_context.nano_structure):
		_structure_button.theme_type_variation = &"StructureSelectorButton"
		_more_childs_button.show()
	else:
		_structure_button.theme_type_variation = &"CrystalButton"
		_more_childs_button.hide()


func get_structure_context() -> StructureContext:
	return _structure_context


func _on_structure_button_pressed() -> void:
	assert(_initialized, "Button not initialized")
	if _structure_context == null:
		# This button is (in theory) the workspace, it cannot be selected
		# instead we open the list of children
		if _more_childs_button.is_visible_in_tree():
			more_childs_requested.emit(null, get_global_rect())
	else:
		structure_context_selected.emit(_structure_context)


func _on_more_childs_button_pressed() -> void:
	assert(_initialized, "Button not initialized")
	more_childs_requested.emit(_structure_context, get_global_rect())


func _has_children_not_in_path(in_nano_structure: NanoStructure) -> bool:
	var children: Array[NanoStructure]
	if in_nano_structure == null:
		children = _get_workspace().get_root_child_structures()
	else:
		children = _get_workspace().get_child_structures(_structure_context.nano_structure)
	return not children.filter(_is_not_in_path_to_active_structure).is_empty()


func _is_not_in_path_to_active_structure(in_nano_structure: NanoStructure) -> bool:
	# Shapes and Motors are intentionally hidden of the list
	var is_valid_group: bool = not in_nano_structure.is_virtual_object()
	if not is_valid_group:
		return false
	var path: Array[NanoStructure] = _get_path_to_current_structure()
	return not in_nano_structure in path


func _get_path_to_current_structure() -> Array[NanoStructure]:
	var path: Array[NanoStructure] = []
	if _workspace_context.get_current_structure_context() == null:
		return path
	var nano_structure: NanoStructure = \
			_workspace_context.get_current_structure_context().nano_structure
	while nano_structure != null:
		path.push_back(nano_structure)
		nano_structure = _get_workspace().get_parent_structure(nano_structure)
	path.reverse()
	return path


func _get_workspace() -> Workspace:
	return _workspace_context.workspace
