extends DynamicContextControl


const DELETE_ICON: Texture2D = preload("res://editor/controls/menu_bar/menu_edit/icons/icon_delete.svg")
const NO_ATOM_TYPE_SELECTED: int = 0


var _workspace_context: WorkspaceContext
var _selected_type: int = NO_ATOM_TYPE_SELECTED
var _selected_small_molecule: AtomicStructure = null
var _current_contact_radius: float = -1.0
var _current_atom_radius: float = -1.0


enum ApplyingWhat {
	ATOMS,
	SMALL_MOLECULES,
}


enum _warning_message_keys { 
	NO_CONTENT_SELECTED,
	NO_WARNING,
	SHORTER_THAN_ATOMIC_RADIUS, 
	SHORTER_THAN_EQUILIBRIUM_DISTANCE, 
}

var _small_molecules_warning_messages : Dictionary = {
	_warning_message_keys.NO_CONTENT_SELECTED: "[color=tomato]Select a molecule to fill the shape first[/color]",
	_warning_message_keys.NO_WARNING: "Distance is additional separation between molecules",
}

var _atom_warning_messages : Dictionary = {
	_warning_message_keys.NO_CONTENT_SELECTED: "[color=tomato]Select an atom to fill the shape first[/color]",
	_warning_message_keys.NO_WARNING: "Distance is adequate for [color=green][b]unbonded[/b][/color] atoms",
	_warning_message_keys.SHORTER_THAN_ATOMIC_RADIUS: "[color=tomato]Distance is too short! [b]Atoms will overlap[/b][/color]",
	_warning_message_keys.SHORTER_THAN_EQUILIBRIUM_DISTANCE: "Distance is adequate for [color=green][b]bonded[/b][/color] atoms",
}


@onready var _apply_atoms_button: Button = %ApplyAtomsButton
@warning_ignore("unused_private_class_variable")
@onready var _apply_small_molecules_button: Button = %ApplySmallMoleculesButton
@onready var _element_preview: AspectRatioContainer = %ElementPreview
@onready var _small_molecules_preview: TextureRect = %SmallMoleculesPreview
@onready var _tree: Tree = %Tree
@onready var _select_popup_menu_button: Button = %SelectPopupMenuButton
@onready var _small_molecules_picker: SmallMoleculesPicker = %SmallMoleculesPicker
@onready var _compact_element_picker_popup: CompactElementPickerPopup = %CompactElementPickerPopup
@onready var _element_picker: ElementPickerBase = _compact_element_picker_popup.get_element_picker()
@onready var _reset_distance_button: Button = %ResetDistanceButton as Button
@onready var _spinbox_distance: SpinBoxSlider = $PanelContainerDistance/VBoxContainer/HBoxContainer/SpinBoxSlider
@onready var _label_warnings: RichTextLabel = $PanelContainerDistance/VBoxContainer/Label
@onready var _occupied_space_check_button: CheckButton = %OccupiedSpaceCheckButton
@onready var _occupied_space_margin_spin_box: SpinBoxSlider = %OccupiedSpaceMarginSpinBox
@onready var _button_cover: Button = %ButtonCover
@onready var _button_fill: Button = %ButtonFill


var _applying_what: ApplyingWhat:
	set = _set_apply_type


func _ready() -> void:
	_apply_atoms_button.button_group.pressed.connect(_on_what_to_apply_button_pressed)
	_reset_distance_button.pressed.connect(_on_atomic_radius_button_pressed)
	_button_cover.pressed.connect(_on_cover_button_pressed)
	_button_fill.pressed.connect(_on_fill_button_pressed)
	_tree.button_clicked.connect(_on_tree_delete_button_clicked)
	_element_picker.atom_type_change_requested.connect(_on_element_picker_atom_type_change_requested)
	_small_molecules_picker.molecule_selected.connect(_on_small_molecules_picker_molecule_selected)
	_select_popup_menu_button.pressed.connect(_on_select_popup_menu_button_pressed)
	_spinbox_distance.value_changed.connect(_refresh_warning_message)
	_element_preview.set_element_number(_selected_type)
	_small_molecules_preview.texture = preload("uid://njg8vo87cuus")
	_small_molecules_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_refresh_ui()


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_workspace_context = in_workspace_context
	if not _workspace_context.selection_in_structures_changed.is_connected(_on_workspace_context_selection_in_structures_changed):
		_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
		_workspace_context.history_changed.connect(_on_workspace_context_history_changed)
		_refresh_ui()
	
	var selected_contexts: Array[StructureContext] = in_workspace_context.get_structure_contexts_with_selection()
	if selected_contexts.is_empty():
		return false
	for selected_context: StructureContext in selected_contexts:
		if selected_context.is_shape_selected():
			return true
	return false


func _on_what_to_apply_button_pressed(in_button: BaseButton) -> void:
	_applying_what = (
		ApplyingWhat.ATOMS
		if in_button == _apply_atoms_button
		else ApplyingWhat.SMALL_MOLECULES
	)


func _set_apply_type(in_what_to_apply: ApplyingWhat) -> void:
	if in_what_to_apply == _applying_what:
		return
	_applying_what = in_what_to_apply
	_clear_selected_object()
	match _applying_what:
		ApplyingWhat.ATOMS:
			_element_preview.show()
			_small_molecules_preview.hide()
		ApplyingWhat.SMALL_MOLECULES:
			_small_molecules_preview.show()
			_element_preview.hide()


func _refresh_ui() -> void:
	_refresh_tree_selection_filters()
	_refresh_buttons_visibility()
	_refresh_warning_message(_spinbox_distance.value)


func _refresh_tree_selection_filters() -> void:
	_tree.clear()
	var atom_type_has_been_selected: bool = _selected_type > NO_ATOM_TYPE_SELECTED
	var small_molecule_has_been_selected: bool = _selected_small_molecule != null
	_tree.visible = atom_type_has_been_selected or small_molecule_has_been_selected
	var root: TreeItem = _tree.create_item()
	if atom_type_has_been_selected:
		var tree_item: TreeItem = _tree.create_item(root)
		var element_data: ElementData = PeriodicTable.get_by_atomic_number(_selected_type)
		tree_item.set_text(0, element_data.name)
		tree_item.add_button(0, DELETE_ICON, _selected_type)
	if small_molecule_has_been_selected:
		var tree_item: TreeItem = _tree.create_item(root)
		tree_item.set_text(0, _selected_small_molecule.get_structure_name())
		tree_item.add_button(0, DELETE_ICON)
	_tree.update_minimum_size()


func _refresh_buttons_visibility() -> void:
	var no_types_selected: bool
	if _applying_what == ApplyingWhat.ATOMS:
		no_types_selected = _selected_type == NO_ATOM_TYPE_SELECTED
	elif _applying_what == ApplyingWhat.SMALL_MOLECULES:
		no_types_selected = _selected_small_molecule == null
	_reset_distance_button.disabled = no_types_selected
	_spinbox_distance.editable = not no_types_selected
	if no_types_selected:
		_spinbox_distance.value = _spinbox_distance.min_value
	
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
	if _applying_what == ApplyingWhat.ATOMS:
		if _selected_type == NO_ATOM_TYPE_SELECTED:
			msg = _atom_warning_messages[_warning_message_keys.NO_CONTENT_SELECTED]
		elif in_distance_value >= contact_diameter:
			msg = _atom_warning_messages[_warning_message_keys.NO_WARNING]
		elif in_distance_value >= atom_diameter:
			msg = _atom_warning_messages[_warning_message_keys.SHORTER_THAN_EQUILIBRIUM_DISTANCE]
		elif in_distance_value < atom_diameter:
			msg = _atom_warning_messages[_warning_message_keys.SHORTER_THAN_ATOMIC_RADIUS]
	elif _applying_what == ApplyingWhat.SMALL_MOLECULES:
		if _selected_small_molecule == null:
			msg = _small_molecules_warning_messages[_warning_message_keys.NO_CONTENT_SELECTED]
		else:
			msg = _small_molecules_warning_messages[_warning_message_keys.NO_WARNING]
	else:
		assert(false, "Untracked content type " + ApplyingWhat.find_key(_applying_what))
		msg = ""
	_label_warnings.text = tr(msg)


func _on_element_picker_atom_type_change_requested(element: int) -> void:
	_selected_type = element
	_element_preview.set_element_number(_selected_type)
	_compact_element_picker_popup.hide()
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(_selected_type)
	_current_atom_radius = element_data.get(ElementData.PROPERTY_NAME_RENDER_RADIUS)
	_current_contact_radius = element_data.get(ElementData.PROPERTY_NAME_CONTACT_RADIUS)
	_spinbox_distance.value = _current_contact_radius * 2.0
	_refresh_ui()


func _on_small_molecules_picker_molecule_selected(in_path: String, in_preview: Texture2D) -> void:
	_small_molecules_preview.texture = in_preview
	_small_molecules_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	assert(is_instance_valid(_workspace_context))
	var unpacked_mol_path: String = WorkspaceUtils.unpack_mol_file_and_get_path(in_path)
	var absolute_path: String = ProjectSettings.globalize_path(unpacked_mol_path)
	_selected_small_molecule = await WorkspaceUtils.get_nano_structure_from_file(_workspace_context, absolute_path, false, false, false)
	_center_template_on_origin(_selected_small_molecule)
	_selected_small_molecule.set_structure_name(in_path.get_file().get_basename().capitalize())
	_refresh_ui()


func _center_template_on_origin(out_template: AtomicStructure) -> void:
	var center: Vector3 = out_template.get_aabb().get_center()
	if center.is_equal_approx(Vector3.ZERO):
		return
	var atoms: PackedInt32Array = out_template.get_valid_atoms()
	var positions: PackedVector3Array = []
	for atom_id: int in atoms:
		var new_pos: Vector3 = out_template.atom_get_position(atom_id) - center
		positions.push_back(new_pos)
	out_template.start_edit()
	out_template.atoms_set_positions(atoms, positions)
	out_template.end_edit()


func _on_tree_delete_button_clicked(_item: TreeItem, _column: int, id: int, _mouse_button_index: int) -> void:
	if _applying_what == ApplyingWhat.ATOMS and _selected_type == id:
		_clear_selected_object()
	elif _applying_what == ApplyingWhat.SMALL_MOLECULES \
			and _selected_small_molecule != null:
		_clear_selected_object()


func _clear_selected_object() -> void:
	_selected_type = NO_ATOM_TYPE_SELECTED
	_element_preview.set_element_number(_selected_type)
	_selected_small_molecule = null
	_small_molecules_preview.texture = preload("uid://njg8vo87cuus")
	_small_molecules_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_current_atom_radius = -1.0
	_current_contact_radius = -1.0
	_spinbox_distance.value = 0.0
	_refresh_ui()


func _on_select_popup_menu_button_pressed() -> void:
	if _applying_what == ApplyingWhat.ATOMS:
		_compact_element_picker_popup.popup_attached_to_control(_select_popup_menu_button)
	else:
		_small_molecules_picker.popup_attached_to_control(_select_popup_menu_button)


func _on_workspace_context_selection_in_structures_changed(_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_refresh_buttons_visibility)


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_refresh_buttons_visibility)


func _on_workspace_context_history_changed() -> void:
	ScriptUtils.call_deferred_once(_refresh_buttons_visibility)


func _on_atomic_radius_button_pressed() -> void:
	_spinbox_distance.value = _current_atom_radius * 2.0


func _on_cover_button_pressed() -> void:
	if _applying_what == ApplyingWhat.ATOMS:
		_cover_shape_with_atoms()
	elif _applying_what == ApplyingWhat.SMALL_MOLECULES:
		_cover_shape_with_molecules()


func _cover_shape_with_atoms() -> void:
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
		_cover_shape_surface(minimum_distance_between_atoms, structure_context)
	
	EditorSfx.create_object()
	_workspace_context.snapshot_moment("Cover shape with atoms")


func _cover_shape_with_molecules() -> void:
	var molecule_aabb: AABB = _selected_small_molecule.get_aabb(AtomicStructure.AABB_BoundsType.ContactRadius)
	molecule_aabb = molecule_aabb.grow(_spinbox_distance.value)
	var molecule_diameter: float = molecule_aabb.get_longest_axis_size()
	
	var editable_structure_contexts: Array[StructureContext] = \
		_workspace_context.get_editable_structure_contexts()
	var selected_shapes_contexts: Array[StructureContext] = \
		_get_selected_shapes_contexts(editable_structure_contexts)
	
	for structure_context: StructureContext in selected_shapes_contexts:
		assert(structure_context.nano_structure is NanoShape, "Selected context is not a shape!")
		_cover_shape_surface(molecule_diameter, structure_context)
	
	EditorSfx.create_object()
	_workspace_context.snapshot_moment("Cover shape with molecules")


func _get_selected_shapes_contexts(in_editable_structure_contexts: Array[StructureContext]) -> Array[StructureContext]:
	var selected_shapes_contexts: Array[StructureContext] = []
	for context in in_editable_structure_contexts:
		if context.is_shape_selected():
			selected_shapes_contexts.push_back(context)
		context.clear_selection()
	return selected_shapes_contexts


func _cover_shape_surface(
	in_minimum_distance_between_atoms: float, 
	out_structure_context: StructureContext) -> void:
	assert(out_structure_context.nano_structure is NanoShape, "Selected context is not a shape!")
	var nano_shape: NanoShape = out_structure_context.nano_structure as NanoShape
	var target_context: StructureContext = _get_parent_structure_context(out_structure_context)
	var target_structure: AtomicStructure = target_context.nano_structure
	const FILL_WHOLE_SHAPE: bool = true
	var new_atom_positions: PackedVector3Array = \
		nano_shape.get_shape().get_cover_atoms_positions(
			in_minimum_distance_between_atoms, FILL_WHOLE_SHAPE
		)
	
	var new_atom_ids: PackedInt32Array
	if _applying_what == ApplyingWhat.ATOMS:
		new_atom_ids = _create_atoms(new_atom_positions, _selected_type, nano_shape.get_transform(), target_structure)
	elif _applying_what == ApplyingWhat.SMALL_MOLECULES:
		new_atom_ids = _create_molecules(new_atom_positions, _selected_small_molecule, nano_shape.get_transform(), target_structure)
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
	out_atom_positions: PackedVector3Array, 
	in_element_number: int, 
	in_nano_shape_transform: Transform3D,
	out_target_structure: NanoStructure) -> PackedInt32Array:
	for i in out_atom_positions.size():
		out_atom_positions[i] = in_nano_shape_transform * out_atom_positions[i]
	_apply_occupied_space_policy(out_atom_positions)
	var add_atom_paramters: Array[NanoMolecularStructure.AddAtomParameters] = []
	for atom_pos: Vector3 in out_atom_positions:
		add_atom_paramters.push_back(
			NanoMolecularStructure.AddAtomParameters.new(
				in_element_number, atom_pos
			)
		)
	out_target_structure.start_edit()
	var new_atom_ids: PackedInt32Array = out_target_structure.add_atoms(add_atom_paramters)
	out_target_structure.end_edit()
	return new_atom_ids


func _create_molecules(
	out_centroid_positions: PackedVector3Array, 
	in_template: AtomicStructure, 
	in_nano_shape_transform: Transform3D,
	out_target_structure: AtomicStructure) -> PackedInt32Array:
	for i in out_centroid_positions.size():
		out_centroid_positions[i] = in_nano_shape_transform * out_centroid_positions[i]
	_apply_occupied_space_policy(out_centroid_positions)
	out_target_structure.start_edit()
	var new_atom_ids: PackedInt32Array = []
	for mol_pos: Vector3 in out_centroid_positions:
		var mol_instance_atom_map: Dictionary[int, int] = {}
		for atom_id: int in in_template.get_valid_atoms():
			var atomic_number: int = in_template.atom_get_atomic_number(atom_id)
			var atom_pos: Vector3 = mol_pos + in_template.atom_get_position(atom_id)
			var new_atom_id: int = out_target_structure.add_atom(
				NanoMolecularStructure.AddAtomParameters.new(
					atomic_number, atom_pos
				)
			)
			mol_instance_atom_map[atom_id] = new_atom_id
			new_atom_ids.push_back(new_atom_id)
		for bond_id: int in in_template.get_valid_bonds():
			var bond_data: Vector3i = in_template.get_bond(bond_id)
			var atom_a: int = mol_instance_atom_map[bond_data[0]]
			var atom_b: int = mol_instance_atom_map[bond_data[1]]
			var bond_order: int = bond_data[2]
			out_target_structure.add_bond(atom_a, atom_b, bond_order)
	out_target_structure.end_edit()
	return new_atom_ids
	


func _set_new_selection(
	in_atom_ids: PackedInt32Array,
	out_target_context: StructureContext) -> void:
	if out_target_context == _workspace_context.get_current_structure_context():
		out_target_context.select_atoms_and_get_auto_selected_bonds(in_atom_ids)
	else:
		# Handle the case where atoms are added to a subgroup
		# the entire subgroup should be selected as well
		out_target_context.select_all(true)


func _on_fill_button_pressed() -> void:
	if _applying_what == ApplyingWhat.ATOMS:
		_fill_shape_with_atoms()
	elif _applying_what == ApplyingWhat.SMALL_MOLECULES:
		_fill_shape_with_molecules()


func _fill_shape_with_atoms() -> void:
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
		_fill_shape(minimum_distance_between_atoms, structure_context)
	
	EditorSfx.create_object()
	_workspace_context.snapshot_moment("Fill shape with atoms")


func _fill_shape_with_molecules() -> void:
	var molecule_aabb: AABB = _selected_small_molecule.get_aabb(AtomicStructure.AABB_BoundsType.ContactRadius)
	molecule_aabb = molecule_aabb.grow(_spinbox_distance.value)
	var molecule_diameter: float = molecule_aabb.get_longest_axis_size()
	
	var editable_structure_contexts: Array[StructureContext] = \
		_workspace_context.get_editable_structure_contexts()
	var selected_shapes_contexts: Array[StructureContext] = \
		_get_selected_shapes_contexts(editable_structure_contexts)
	
	for structure_context: StructureContext in selected_shapes_contexts:
		assert(structure_context.nano_structure is NanoShape, "Selected context is not a shape!")
		_fill_shape(molecule_diameter, structure_context)
	
	EditorSfx.create_object()
	_workspace_context.snapshot_moment("Fill shape with molecules")


func _fill_shape(
	in_minimum_distance_between_atoms: float,
	out_structure_context: StructureContext) -> void:
	assert(out_structure_context.nano_structure is NanoShape, "Selected context is not a shape!")
	var nano_shape: NanoShape = out_structure_context.nano_structure as NanoShape
	var target_context: StructureContext = _get_parent_structure_context(out_structure_context)
	var target_structure: AtomicStructure = target_context.nano_structure
	
	# Fill Shape will fallback to Cover Shape
	# This is because some shapes have no volume and cannot be filled
	const FILL_WHOLE_SHAPE: bool = true
	var new_atom_positions: PackedVector3Array = \
		nano_shape.get_shape().get_fill_atoms_positions(in_minimum_distance_between_atoms, FILL_WHOLE_SHAPE) \
		if nano_shape.get_shape().has_method("get_fill_atoms_positions") else \
		nano_shape.get_shape().get_cover_atoms_positions(in_minimum_distance_between_atoms, FILL_WHOLE_SHAPE)
	
	var new_atom_ids: PackedInt32Array = []
	if _applying_what == ApplyingWhat.ATOMS:
		new_atom_ids = _create_atoms(new_atom_positions, _selected_type, nano_shape.get_transform(), target_structure)
	elif _applying_what == ApplyingWhat.SMALL_MOLECULES:
		new_atom_ids = _create_molecules(new_atom_positions, _selected_small_molecule, nano_shape.get_transform(), target_structure)
	
	_set_new_selection(new_atom_ids, target_context)


func _apply_occupied_space_policy(out_positions: PackedVector3Array) -> void:
	if _occupied_space_check_button.button_pressed == false:
		return
	var margin: float = _occupied_space_margin_spin_box.value
	var margin_squared: float = margin * margin
	var occupied_space := SpatialHashGrid.new(_occupied_space_margin_spin_box.value * 2)
	for structure_context in _workspace_context.get_editable_structure_contexts():
		var atomic_structure := structure_context.nano_structure as AtomicStructure
		if atomic_structure == null or atomic_structure is DnaStructure:
			continue
		var all_atoms: PackedInt32Array = atomic_structure.get_valid_atoms()
		for atom_id: int in all_atoms:
			occupied_space.add_item(atomic_structure.atom_get_position(atom_id))
	for i in range(out_positions.size()-1, -1, -1):
		var neighbors: Array[SpatialHashGrid.Item] = occupied_space.get_items_around(out_positions[i], margin)
		for n: SpatialHashGrid.Item in neighbors:
			if n.position.distance_squared_to(out_positions[i]) < margin_squared:
				out_positions.remove_at(i)
