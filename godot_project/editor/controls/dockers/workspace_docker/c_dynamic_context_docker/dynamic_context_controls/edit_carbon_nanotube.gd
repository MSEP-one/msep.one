extends DynamicContextControl


var _n_spin_box_slider: SpinBoxSlider
var _m_spin_box_slider: SpinBoxSlider
var _graphene_lattice_preview: GrapheneLatticePreview
var _diameter_label: Label
var _circumference_label: Label
var _trim_invalid_valence_carbons_check_button: CheckButton
var _length_spin_box_slider: SpinBoxSlider
var _convert_to_atoms_button: Button
var _change_representation_button: RichTextLabel


var _workspace_context: WorkspaceContext
var _edited_nanotube: CarbonNanotubeStructure


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_initialized(in_workspace_context)
	var count: int = 0
	var select_ctx: StructureContext = null
	for ctx: StructureContext in in_workspace_context.get_structure_contexts_with_selection():
		if ctx.nano_structure is CarbonNanotubeStructure:
			count += 1
			select_ctx = ctx
	_set_selected_context(select_ctx.nano_structure if count == 1 else null)
	return count > 0


func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == null:
		_workspace_context = in_workspace_context


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_n_spin_box_slider = %NSpinBoxSlider as SpinBoxSlider
		_m_spin_box_slider = %MSpinBoxSlider as SpinBoxSlider
		_graphene_lattice_preview = %GrapheneLatticePreview as GrapheneLatticePreview
		_diameter_label = %DiameterLabel as Label
		_circumference_label = %CircumferenceLabel as Label
		_trim_invalid_valence_carbons_check_button = %TrimInvalidValenceCarbonsCheckButton as CheckButton
		_length_spin_box_slider = %LengthSpinBoxSlider as SpinBoxSlider
		_convert_to_atoms_button = %ConvertToAtomsButton as Button
		_change_representation_button = %ChangeRepresentationButton as RichTextLabel
		
		_n_spin_box_slider.value_changed.connect(_on_n_spin_box_slider_value_changed)
		_m_spin_box_slider.value_changed.connect(_on_m_spin_box_slider_value_changed)
		_n_spin_box_slider.value_confirmed.connect(_on_n_spin_box_slider_value_confirmed)
		_m_spin_box_slider.value_confirmed.connect(_on_m_spin_box_slider_value_confirmed)
		_trim_invalid_valence_carbons_check_button.toggled.connect(_on_trim_invalid_valence_carbons_check_button_toggled)
		_length_spin_box_slider.value_confirmed.connect(_on_length_spin_box_slider_value_confirmed)
		_convert_to_atoms_button.pressed.connect(_on_convert_to_atoms_button_pressed)
		_change_representation_button.meta_clicked.connect(_on_change_representation_button_meta_clicked)


func _set_selected_context(out_nanotube_or_null: CarbonNanotubeStructure) -> void:
	%SelectOneInfoLabel.visible = out_nanotube_or_null == null
	%EditorContainer.visible = not out_nanotube_or_null == null
	if _edited_nanotube and _edited_nanotube.path_changed.is_connected(_on_edited_nanotube_path_changed):
		_edited_nanotube.path_changed.disconnect(_on_edited_nanotube_path_changed)
	_edited_nanotube = out_nanotube_or_null
	if _edited_nanotube != null:
		_graphene_lattice_preview.n = _edited_nanotube.get_chiral_index_n()
		_graphene_lattice_preview.m = _edited_nanotube.get_chiral_index_m()
		_n_spin_box_slider.set_value_no_signal(_graphene_lattice_preview.n)
		_m_spin_box_slider.set_value_no_signal(_graphene_lattice_preview.m)
		_trim_invalid_valence_carbons_check_button.set_pressed_no_signal(
			_edited_nanotube.is_trim_invalid_valence_carbons_enabled()
		)
		_length_spin_box_slider.set_value_no_signal(_edited_nanotube.get_tube_length())
		if not _edited_nanotube.path_changed.is_connected(_on_edited_nanotube_path_changed):
			_edited_nanotube.path_changed.connect(_on_edited_nanotube_path_changed.unbind(2))
		_update_estimates()


func _on_n_spin_box_slider_value_changed(in_value: int) -> void:
	_graphene_lattice_preview.n = in_value
	_update_estimates()


func _on_m_spin_box_slider_value_changed(in_value: int) -> void:
	_graphene_lattice_preview.m = in_value
	_update_estimates()
	

func _on_n_spin_box_slider_value_confirmed(in_value: int) -> void:
	if _edited_nanotube:
		_edited_nanotube.start_edit()
		_edited_nanotube.set_chiral_index_n(in_value)
		_edited_nanotube.end_edit()
		_workspace_context.snapshot_moment("Set: Nanotube Chiral Index")


func _on_m_spin_box_slider_value_confirmed(in_value: int) -> void:
	if _edited_nanotube:
		_edited_nanotube.start_edit()
		_edited_nanotube.set_chiral_index_m(in_value)
		_edited_nanotube.end_edit()
		_workspace_context.snapshot_moment("Set: Nanotube Chiral Index")


func _on_trim_invalid_valence_carbons_check_button_toggled(in_button_pressed: bool) -> void:
	if _edited_nanotube:
		_edited_nanotube.start_edit()
		_edited_nanotube.set_trim_invalid_valence_carbons(in_button_pressed)
		_edited_nanotube.end_edit()
		_workspace_context.snapshot_moment("Set: Trim Invalid Valence Atoms")


func _on_length_spin_box_slider_value_confirmed(in_value: float) -> void:
	if _edited_nanotube:
		_edited_nanotube.start_edit()
		_edited_nanotube.set_tube_length(in_value)
		_edited_nanotube.end_edit()
		_workspace_context.snapshot_moment("Set: Nanotube Length")


func _on_edited_nanotube_path_changed() -> void:
	if _edited_nanotube:
		_length_spin_box_slider.set_value_no_signal(_edited_nanotube.get_tube_length())


func _on_convert_to_atoms_button_pressed() -> void:
	assert(_edited_nanotube != null, "Invalid ui state")
	# We need to make atoms available, but no bother other parts of the editor
	_edited_nanotube.set_block_signals(true)
	_edited_nanotube.set_force_track_atoms(true)
	var parent_group: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_edited_nanotube.int_parent_guid)
	var new_group: AtomicStructure = AtomicStructure.create()
	new_group.set_structure_name(_edited_nanotube.get_structure_name() + "'s atoms")
	_workspace_context.workspace.add_structure(new_group, parent_group)
	new_group.start_edit()
	var atom_map: Dictionary[int, int]
	for atom_id: int in _edited_nanotube.get_valid_atoms():
		var atomic_number: int = _edited_nanotube.atom_get_atomic_number(atom_id)
		var pos: Vector3 = _edited_nanotube.atom_get_position(atom_id)
		atom_map[atom_id] = new_group.add_atom(AtomicStructure.AddAtomParameters.new(atomic_number, pos))
	for bond_id: int in _edited_nanotube.get_bonds_ids():
		var bond_data: Vector3i = _edited_nanotube.get_bond(bond_id)
		# remap atom ids
		new_group.add_bond(atom_map[bond_data.x], atom_map[bond_data.y], bond_data.z)
	new_group.end_edit()
	# Done polling atoms, back to normal
	_edited_nanotube.set_force_track_atoms(false)
	_edited_nanotube.set_block_signals(false)
	_workspace_context.workspace.remove_structure(_edited_nanotube)
	var new_context: StructureContext = _workspace_context.get_structure_context(new_group.int_guid)
	new_context.select_all()
	_workspace_context.snapshot_moment("Convert Carbon Nanotube to Atoms and Bonds")


func _on_change_representation_button_meta_clicked(_meta: Variant) -> void:
	MolecularEditorContext.request_workspace_docker_focus(
		WorkspaceSettingsDocker.UNIQUE_DOCKER_NAME,
		&"Representation Settings",
		[^"VisibilitySettings", ^"%NanotubeRepresentationOptionButton/.."]
		)


func _update_estimates() -> void:
	_circumference_label.text = tr(&"%.3f nm") % _graphene_lattice_preview.get_estimated_circumference()
	_diameter_label.text = tr(&"%.3f nm") % _graphene_lattice_preview.get_estimated_diameter()
