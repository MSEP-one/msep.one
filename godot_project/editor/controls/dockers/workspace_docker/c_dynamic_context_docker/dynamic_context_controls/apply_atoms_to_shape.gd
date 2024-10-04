extends DynamicContextControl


const DELETE_ICON: Texture2D = preload("res://editor/controls/menu_bar/menu_edit/icons/icon_delete.svg")
const NO_ATOM_TYPE_SELECTED: int = -1


var _workspace_context: WorkspaceContext
var _selected_type: int = NO_ATOM_TYPE_SELECTED
var _current_contact_radius: float = -1.0
var _current_atom_radius: float = -1.0


enum _warning_message_keys { 
	NO_WARNING,
	SHORTER_THAN_ATOMIC_RADIUS, 
	SHORTER_THAN_EQUILIBRIUM_DISTANCE, 
}

var _warning_messages : Dictionary = {
	_warning_message_keys.NO_WARNING: "",
	_warning_message_keys.SHORTER_THAN_ATOMIC_RADIUS: "Distance is too short! Atoms will overlap",
	_warning_message_keys.SHORTER_THAN_EQUILIBRIUM_DISTANCE: "Distance is less than equilibrium distance! Only recommended for bonded atoms",
}


@onready var _element_picker: VBoxContainer = %ElementPicker
@onready var _tree: Tree = %Tree
@onready var _button_atomic_radius: Button = $PanelContainerDistance/VBoxContainer/ButtonAtomicRadius
@onready var _button_contact_radius: Button = $PanelContainerDistance/VBoxContainer/ButtonContactRadius
@onready var _spinbox_distance: SpinBoxSlider = $PanelContainerDistance/VBoxContainer/SpinBoxSlider
@onready var _checkbutton_whole_shape: CheckButton = $PanelContainerDistance/VBoxContainer/CheckButtonWholeShape
@onready var _label_warnings: Label = $PanelContainerDistance/VBoxContainer/Label
@onready var _button_cover: Button = %ButtonCover
@onready var _button_fill: Button = %ButtonFill


func _ready() -> void:
	_button_atomic_radius.pressed.connect(_on_atomic_radius_button_pressed)
	_button_contact_radius.pressed.connect(_on_contact_radius_button_pressed)
	_button_cover.pressed.connect(_on_cover_button_pressed)
	_button_fill.pressed.connect(_on_fill_button_pressed)
	_element_picker.atom_type_change_requested.connect(_on_element_picker_atom_type_change_requested)
	_tree.button_clicked.connect(_on_tree_delete_button_clicked)
	_spinbox_distance.value_changed.connect(_refresh_warning_message)
	_refresh_ui()


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_workspace_context = in_workspace_context
	if not _workspace_context.selection_in_structures_changed.is_connected(_on_workspace_context_selection_in_structures_changed):
		_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
		_refresh_ui()
	
	var selected_contexts: Array[StructureContext] = in_workspace_context.get_structure_contexts_with_selection()
	if selected_contexts.is_empty():
		return false
	for selected_context: StructureContext in selected_contexts:
		if selected_context.is_shape_selected():
			return true
	return false


func _refresh_ui() -> void:
	_refresh_tree_selection_filters()
	_refresh_buttons_visibility()
	_refresh_warning_message(_spinbox_distance.value)


func _refresh_tree_selection_filters() -> void:
	_tree.clear()
	assert(_selected_type != 0, "Selected Type value is invalid")
	var atom_type_has_been_selected: bool = _selected_type > NO_ATOM_TYPE_SELECTED
	_tree.visible = atom_type_has_been_selected
	var root: TreeItem = _tree.create_item()
	if atom_type_has_been_selected:
		var tree_item: TreeItem = _tree.create_item(root)
		var element_data: ElementData = PeriodicTable.get_by_atomic_number(_selected_type)
		tree_item.set_text(0, element_data.name)
		tree_item.add_button(0, DELETE_ICON, _selected_type)
	_tree.update_minimum_size()


func _refresh_buttons_visibility() -> void:
	var no_types_selected: bool = _selected_type == NO_ATOM_TYPE_SELECTED
	_button_atomic_radius.disabled = no_types_selected
	_button_contact_radius.disabled = no_types_selected
	_checkbutton_whole_shape.disabled = no_types_selected
	
	if not is_instance_valid(_workspace_context):
		return
	
	var can_fill: bool = false
	var can_cover: bool = false
	for structure_context: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		if not structure_context.nano_structure is NanoShape or not is_instance_valid(structure_context.nano_structure.get_shape()):
			continue
		var shape: PrimitiveMesh = structure_context.nano_structure.get_shape()
		if shape.has_method("get_cover_atoms_positions"):
			can_cover = true
		if shape.has_method("get_fill_atoms_positions"):
			can_fill = true
		if can_cover and can_fill:
			# early stop iteration
			break
	_button_cover.disabled = no_types_selected or not can_cover
	_button_fill.disabled = no_types_selected or not can_fill



func _refresh_warning_message(in_distance_value: float) -> void:
	var msg: String = ""
	var contact_diameter: float = _current_contact_radius * 2.0
	var atom_diameter: float = _current_atom_radius * 2.0
	if in_distance_value >= contact_diameter:
		msg = _warning_messages[_warning_message_keys.NO_WARNING]
	elif in_distance_value >= atom_diameter:
		msg = _warning_messages[_warning_message_keys.SHORTER_THAN_EQUILIBRIUM_DISTANCE]
	elif in_distance_value < atom_diameter:
		msg = _warning_messages[_warning_message_keys.SHORTER_THAN_ATOMIC_RADIUS]
	_label_warnings.text = tr(msg)


func _on_element_picker_atom_type_change_requested(element: int) -> void:
	_selected_type = element
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(_selected_type)
	_current_atom_radius = element_data.get(ElementData.PROPERTY_NAME_RENDER_RADIUS)
	_current_contact_radius = element_data.get(ElementData.PROPERTY_NAME_CONTACT_RADIUS)
	_spinbox_distance.value = _current_contact_radius * 2.0
	_refresh_ui()


func _on_tree_delete_button_clicked(_item: TreeItem, _column: int, id: int, _mouse_button_index: int) -> void:
	if _selected_type == id:
		_selected_type = NO_ATOM_TYPE_SELECTED
		_current_atom_radius = -1.0
		_current_contact_radius = -1.0
		_spinbox_distance.value = 0.0
	_refresh_ui()


func _on_workspace_context_selection_in_structures_changed(_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_refresh_buttons_visibility)


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_refresh_buttons_visibility)


func _on_atomic_radius_button_pressed() -> void:
	_spinbox_distance.value = _current_atom_radius * 2.0


func _on_contact_radius_button_pressed() -> void:
	_spinbox_distance.value = _current_contact_radius * 2.0


func _on_cover_button_pressed() -> void:
	var target_element_data: ElementData = PeriodicTable.get_by_atomic_number(_selected_type)
	
	var editable_structure_contexts: Array[StructureContext] = \
		_workspace_context.get_editable_structure_contexts()
	var selected_shapes_contexts: Array[StructureContext] = \
		_get_selected_shapes_contexts(editable_structure_contexts)
	
	for structure_context: StructureContext in selected_shapes_contexts:
		assert(structure_context.nano_structure is NanoShape, "Selected context is not a shape!")
		var nano_shape: NanoShape = structure_context.nano_structure as NanoShape
		var atom_diameter: float = \
			_get_atom_diameter(target_element_data, nano_shape.get_representation_settings())
		var minimum_distance_between_atoms: float = max(atom_diameter, _spinbox_distance.value)
		_cover_shape_surface(minimum_distance_between_atoms, target_element_data.number, structure_context)
	
	_workspace_context.snapshot_moment("Cover shape with atoms")


func _get_selected_shapes_contexts(in_editable_structure_contexts: Array[StructureContext]) -> Array[StructureContext]:
	var selected_shapes_contexts: Array[StructureContext] = []
	for context in in_editable_structure_contexts:
		if context.is_shape_selected():
			selected_shapes_contexts.push_back(context)
		context.clear_selection()
	return selected_shapes_contexts


func _cover_shape_surface(
	in_minimum_distance_between_atoms: float, 
	in_element_number: int, 
	out_structure_context: StructureContext) -> void:
	assert(out_structure_context.nano_structure is NanoShape, "Selected context is not a shape!")
	var nano_shape: NanoShape = out_structure_context.nano_structure as NanoShape
	var target_context: StructureContext = _get_parent_structure_context(out_structure_context)
	var target_structure: AtomicStructure = target_context.nano_structure
	
	var new_atom_positions: PackedVector3Array = \
		nano_shape.get_shape().get_cover_atoms_positions(
			in_minimum_distance_between_atoms, _checkbutton_whole_shape.button_pressed
		)
	
	var new_atom_ids: PackedInt32Array = \
		_create_atoms(new_atom_positions, in_element_number, nano_shape.get_transform(), target_structure)
	_set_new_selection(new_atom_ids, target_context)


func _get_parent_structure_context(in_structure_context: StructureContext) -> StructureContext:
	var child_structure: NanoStructure = in_structure_context.nano_structure
	var parent_structure: NanoStructure = _workspace_context.workspace.get_parent_structure(child_structure)
	assert(parent_structure is AtomicStructure, "Parent Structure is invalid!")
	var parent_context: StructureContext = _workspace_context.get_nano_structure_context(parent_structure)
	return parent_context


func _get_atom_diameter(in_element_data: ElementData, in_representation_settings: RepresentationSettings) -> float:
	return 2.0 * Representation.get_atom_radius(in_element_data, in_representation_settings) \
		* Representation.get_atom_scale_factor(in_representation_settings)


func _create_atoms(
	in_atom_positions: PackedVector3Array, 
	in_element_number: int, 
	in_nano_shape_transform: Transform3D,
	out_target_structure: NanoStructure) -> PackedInt32Array:
	var add_atom_paramters: Array[NanoMolecularStructure.AddAtomParameters] = []
	for atom_pos: Vector3 in in_atom_positions:
		add_atom_paramters.push_back(
			NanoMolecularStructure.AddAtomParameters.new(
				in_element_number, in_nano_shape_transform * atom_pos
			)
		)
	out_target_structure.start_edit()
	var new_atom_ids: PackedInt32Array = out_target_structure.add_atoms(add_atom_paramters)
	out_target_structure.end_edit()
	EditorSfx.create_object()
	return new_atom_ids


func _set_new_selection(
	in_atom_ids: PackedInt32Array,
	out_target_context: StructureContext) -> void:
	if out_target_context == _workspace_context.get_current_structure_context():
		out_target_context.select_atoms(in_atom_ids)
	else:
		# Handle the case where atoms are added to a subgroup
		# the entire subgroup should be selected as well
		out_target_context.select_all(true)


func _on_fill_button_pressed() -> void:
	var target_element_data: ElementData = PeriodicTable.get_by_atomic_number(_selected_type)
	var editable_structure_contexts: Array[StructureContext] = \
		_workspace_context.get_editable_structure_contexts()
	var selected_shapes_contexts: Array[StructureContext] = \
		_get_selected_shapes_contexts(editable_structure_contexts)
	
	for structure_context: StructureContext in selected_shapes_contexts:
		assert(structure_context.nano_structure is NanoShape, "Selected context is not a shape!")
		var nano_shape: NanoShape = structure_context.nano_structure as NanoShape
		var atom_diameter: float = \
			_get_atom_diameter(target_element_data, nano_shape.get_representation_settings())
		var minimum_distance_between_atoms: float = max(atom_diameter, _spinbox_distance.value)
		_fill_shape(minimum_distance_between_atoms, target_element_data.number, structure_context)
	
	_workspace_context.snapshot_moment("Fill shape with atoms")


func _fill_shape(
	in_minimum_distance_between_atoms: float, 
	in_element_number: int, 
	out_structure_context: StructureContext) -> void:
	assert(out_structure_context.nano_structure is NanoShape, "Selected context is not a shape!")
	var nano_shape: NanoShape = out_structure_context.nano_structure as NanoShape
	var target_context: StructureContext = _get_parent_structure_context(out_structure_context)
	var target_structure: AtomicStructure = target_context.nano_structure
	
	# Fill Shape will fallback to Cover Shape
	# This is because some shapes have no volume and cannot be filled
	var new_atom_positions: PackedVector3Array = \
		nano_shape.get_shape().get_fill_atoms_positions(in_minimum_distance_between_atoms, _checkbutton_whole_shape.button_pressed) \
		if nano_shape.get_shape().has_method("get_fill_atoms_positions") else \
		nano_shape.get_shape().get_cover_atoms_positions(in_minimum_distance_between_atoms, _checkbutton_whole_shape.button_pressed)
	
	var new_atom_ids: PackedInt32Array = \
		_create_atoms(new_atom_positions, in_element_number, nano_shape.get_transform(), target_structure)
	
	_set_new_selection(new_atom_ids, target_context)
