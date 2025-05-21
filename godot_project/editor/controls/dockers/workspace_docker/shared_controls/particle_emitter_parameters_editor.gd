class_name ParticleEmitterParametersEditor extends VBoxContainer


var _initial_delay_time_picker: TimeSpanPicker
var _molecules_per_instance_spin_box: SpinBoxSlider
var _instance_rate_time_picker: TimeSpanPicker
var _initial_speed_spin_box: SpinBoxSlider
var _spread_angle_spin_box: SpinBoxSlider
var _stop_never_button: Button
var _stop_count_button: Button
var _stop_time_button: Button
var _limit_label: Label
var _limit_instances_spin_box: SpinBoxSlider
var _limit_nanoseconds_time_picker: TimeSpanPicker
var _molecule_preview: AspectRatioContainer
var _load_molecule_from_selection_button: Button
var _load_molecule_from_library_button: Button
var _small_molecules_picker: SmallMoleculesPicker:
	get = _get_small_molecules_picker

# when not null an snapshot in this workspace will be taken on change from UI
var _workspace_snapshot_target: WorkspaceContext = null
var _current_molecule_template: AtomicStructure = null
var _dummy_structure_context: StructureContext = null
var _parameters_wref: WeakRef = weakref(null) # WeakRef<NanoParticleEmitterParameters>


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_initial_delay_time_picker = %InitialDelayTimePicker as TimeSpanPicker
		_molecules_per_instance_spin_box = %MoleculesPerInstanceSpinBox as SpinBoxSlider
		_instance_rate_time_picker = %InstanceRateTimePicker as TimeSpanPicker
		_initial_speed_spin_box = %InitialSpeedSpinBox as SpinBoxSlider
		_spread_angle_spin_box = %SpreadAngleSpinBox as SpinBoxSlider
		_stop_never_button = %StopNeverButton as Button
		_stop_count_button = %StopCountButton as Button
		_stop_time_button = %StopTimeButton as Button
		_limit_label = %LimitLabel as Label
		_limit_instances_spin_box = %LimitInstancesSpinBox as SpinBoxSlider
		_limit_nanoseconds_time_picker = %LimitNanosecondsTimePicker as TimeSpanPicker
		_molecule_preview = %MoleculePreview as AspectRatioContainer
		_load_molecule_from_selection_button = %LoadMoleculeFromSelectionButton as Button
		_load_molecule_from_library_button = %LoadMoleculeFromLibraryButton as Button
		_initial_delay_time_picker.time_span_changed.connect(_on_initial_delay_time_picker_time_span_changed)
		_molecules_per_instance_spin_box.value_confirmed.connect(_on_molecules_per_instance_spin_box_value_confirmed)
		_instance_rate_time_picker.time_span_changed.connect(_on_instance_rate_time_picker_time_span_changed)
		_initial_speed_spin_box.value_confirmed.connect(_on_initial_speed_spin_box_value_confirmed)
		_spread_angle_spin_box.value_confirmed.connect(_on_spread_angle_spin_box_value_confirmed)
		_stop_never_button.button_group.pressed.connect(_on_stop_condition_button_group_pressed)
		_limit_instances_spin_box.value_confirmed.connect(_on_limit_instances_spin_box_value_confirmed)
		_limit_nanoseconds_time_picker.time_span_changed.connect(_on_limit_nanoseconds_time_picker_time_span_changed)
		_load_molecule_from_selection_button.pressed.connect(_on_load_molecule_from_selection_button_pressed)
		_load_molecule_from_library_button.pressed.connect(_on_load_molecule_from_library_button_pressed)
	if what == NOTIFICATION_READY:
		_molecule_preview.get_structure_preview().enable_on_preview_viewport()
		_molecule_preview.get_structure_preview().set_transparency(0)


func _get_small_molecules_picker() -> SmallMoleculesPicker:
	if _small_molecules_picker == null:
		# lazy loading on demand
		var scene: PackedScene = load("uid://dp606sfgxdepk") as PackedScene
		_small_molecules_picker = scene.instantiate()
		_small_molecules_picker.set_meta(&"base_height", _small_molecules_picker.size.y)
		_small_molecules_picker.molecule_selected.connect(_on_small_molecules_picker_molecule_selected)
		add_child(_small_molecules_picker)
	return _small_molecules_picker


func track_parameters(out_emitter_parameters: NanoParticleEmitterParameters) -> void:
	var old_parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	if is_instance_valid(old_parameters):
		old_parameters.changed.disconnect(_on_emitter_parameters_changed)
	_parameters_wref = weakref(out_emitter_parameters)
	if out_emitter_parameters != null:
		out_emitter_parameters.changed.connect(_on_emitter_parameters_changed)
		_on_emitter_parameters_changed()
	else:
		# clear reference to current structure
		_update_template_preview(null)


func ensure_undo_redo_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_snapshot_target != in_workspace_context:
		_workspace_snapshot_target = in_workspace_context
		_workspace_snapshot_target.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)


func _take_snapshot_if_configured(in_modified_property: String) -> void:
	if is_instance_valid(_workspace_snapshot_target):
		_workspace_snapshot_target.snapshot_moment("Set: " + in_modified_property)


func _on_workspace_context_history_snapshot_applied() -> void:
	if is_instance_valid(_get_emitter_parameters()):
		# if instance is still valid refresh the UI
		_on_emitter_parameters_changed()


func _get_emitter_parameters() -> NanoParticleEmitterParameters:
	return _parameters_wref.get_ref() as NanoParticleEmitterParameters


func _on_emitter_parameters_changed() -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	assert(parameters != null, "Impossible condition. How can parametters not exists and have changed at the same time?")
	
	_initial_delay_time_picker.time_span_femtoseconds = TimeSpanPicker.unit_to_femtoseconds(
			parameters.get_initial_delay_in_nanoseconds(), TimeSpanPicker.Unit.NANOSECOND)
	_molecules_per_instance_spin_box.set_value_no_signal(parameters.get_molecules_per_instance())
	_instance_rate_time_picker.time_span_femtoseconds = TimeSpanPicker.unit_to_femtoseconds(
			parameters.get_instance_rate_time_in_nanoseconds(), TimeSpanPicker.Unit.NANOSECOND)
	_initial_speed_spin_box.set_value_no_signal(parameters.get_instance_speed_nanometers_per_picosecond())
	_spread_angle_spin_box.set_value_no_signal(parameters.get_spread_angle())
	_stop_never_button.set_pressed_no_signal(parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.NEVER)
	_stop_count_button.set_pressed_no_signal(parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.INSTANCE_COUNT)
	_stop_time_button.set_pressed_no_signal(parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.TIME)
	_limit_label.visible = parameters.get_limit_type() != NanoParticleEmitterParameters.LimitType.NEVER
	_limit_instances_spin_box.visible = parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.INSTANCE_COUNT
	_limit_nanoseconds_time_picker.visible = parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.TIME
	_limit_instances_spin_box.set_value_no_signal(parameters.get_stop_emitting_after_count())
	_limit_nanoseconds_time_picker.time_span_femtoseconds = TimeSpanPicker.unit_to_femtoseconds(
			parameters.get_stop_emitting_after_nanoseconds(), TimeSpanPicker.Unit.NANOSECOND)
	_update_template_preview(parameters.get_molecule_template())


func _update_template_preview(in_structure: AtomicStructure) -> void:
	if _current_molecule_template == in_structure:
		return
	var rendering: Rendering = _molecule_preview.get_rendering() as Rendering
	_current_molecule_template = in_structure
	if _dummy_structure_context != null:
		_dummy_structure_context.queue_free()
		_dummy_structure_context = null
	if in_structure != null:
		_dummy_structure_context = WorkspaceContext.StructureContextScn.instantiate()
		_dummy_structure_context.initialize_as_template(null, in_structure)
		add_child(_dummy_structure_context)
	_molecule_preview.get_structure_preview().set_structure(_dummy_structure_context)
	if in_structure == null:
		rendering.structure_preview_hide()
	else:
		rendering.structure_preview_show()
		rendering.structure_preview_set_transform(Transform3D())
		var structure_center: Vector3 = in_structure.get_aabb().get_center()
		var structure_size: float = in_structure.get_aabb().get_longest_axis_size()
		_molecule_preview.set_preview_camera_pivot_position(structure_center)
		_molecule_preview.set_preview_camera_distance_to_pivot(structure_size * 3.0)


func _on_initial_delay_time_picker_time_span_changed(
		in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
			time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	parameters.set_initial_delay_in_nanoseconds(time_in_nanoseconds)
	_take_snapshot_if_configured(tr(&"Initial Delay"))


func _on_molecules_per_instance_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_molecules_per_instance(int(in_value))
	_take_snapshot_if_configured(tr(&"Molecules per Instantation"))


func _on_instance_rate_time_picker_time_span_changed(
		in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
			time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	parameters.set_instance_rate_time_in_nanoseconds(time_in_nanoseconds)
	_take_snapshot_if_configured(tr(&"Instance Rate"))


func _on_initial_speed_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_instance_speed_nanometers_per_picosecond(in_value)
	_take_snapshot_if_configured(tr(&"Initial Speed"))


func _on_spread_angle_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_spread_angle(in_value)
	_take_snapshot_if_configured(tr(&"Spread Angle"))


func _on_stop_condition_button_group_pressed(in_button: Button) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var type: NanoParticleEmitterParameters.LimitType
	if in_button == _stop_never_button:
		type = NanoParticleEmitterParameters.LimitType.NEVER
	elif in_button == _stop_count_button:
		type = NanoParticleEmitterParameters.LimitType.INSTANCE_COUNT
	elif in_button == _stop_time_button:
		type = NanoParticleEmitterParameters.LimitType.TIME
	else:
		assert(false, "Unexpected button in ButtonGroup: " + str(get_path_to(in_button)))
		pass
	parameters.set_limit_type(type)
	_take_snapshot_if_configured(tr(&"Stop Condition"))


func _on_limit_instances_spin_box_value_confirmed(in_value: float) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	parameters.set_stop_emitting_after_count(int(in_value))
	_take_snapshot_if_configured(tr(&"Instance Limit"))


func _on_limit_nanoseconds_time_picker_time_span_changed(
		in_magnitude: float, in_unit: TimeSpanPicker.Unit) -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var time_in_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(in_magnitude, in_unit)
	var time_in_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
			time_in_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	parameters.set_stop_emitting_after_nanoseconds(time_in_nanoseconds)
	_take_snapshot_if_configured(tr(&"Time Limit"))


func _on_load_molecule_from_selection_button_pressed() -> void:
	var parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	var selected_contexts: Array[StructureContext] = workspace_context.get_atomic_structure_contexts_with_selection()
	if selected_contexts.is_empty():
		parameters.set_molecule_template(null)
	else:
		var template := AtomicStructure.create()
		template.start_edit()
		for context: StructureContext in selected_contexts:
			var structure: AtomicStructure = context.nano_structure as AtomicStructure
			var atoms: PackedInt32Array = context.get_selected_atoms()
			var bonds: PackedInt32Array = context.get_selected_bonds()
			var atom_map: Dictionary[int,int] # { original_id = new_id }
			for atom_id: int in atoms:
				var element: int = structure.atom_get_atomic_number(atom_id)
				var pos: Vector3 = structure.atom_get_position(atom_id)
				# Asiming template is NanoMolecualStructure
				atom_map[atom_id] = template.add_atom(NanoMolecularStructure.AddAtomParameters.new(element, pos))
			for bond_id: int in bonds:
				var bond_data: Vector3i = structure.get_bond(bond_id)
				var atom1: int = bond_data.x
				var atom2: int = bond_data.y
				if atom1 in atoms and atom2 in atoms:
					var order: int = bond_data.z
					template.add_bond(atom_map[atom1], atom_map[atom2], order)
		_center_template_on_origin(template)
		template.end_edit()
		template.set_structure_name("Template")
		template.set_representation_settings(workspace_context.workspace.representation_settings)
		parameters.set_molecule_template(template)
	_take_snapshot_if_configured(tr(&"Molecule Template"))


func _on_load_molecule_from_library_button_pressed() -> void:
	_small_molecules_picker.size.y = _small_molecules_picker.get_meta(&"base_height", 450)
	_small_molecules_picker.position.x = int(_load_molecule_from_library_button.global_position.x)
	_small_molecules_picker.position.y = int(_load_molecule_from_library_button.get_global_rect().end.y)
	
	# Adjust x position
	var picker_rect_end: Vector2 = _small_molecules_picker.position + _small_molecules_picker.size
	var out_of_screen_x: bool = picker_rect_end.x > get_tree().root.size.x
	if out_of_screen_x:
		_small_molecules_picker.position.x = \
			int(_load_molecule_from_library_button.get_global_rect().end.x- _small_molecules_picker.size.x)
	
	# Adjust y position (and size?)
	var up_space := int(_load_molecule_from_library_button.global_position.y)
	var down_space := int(get_tree().root.size.y - _load_molecule_from_library_button.get_global_rect().end.y)
	if down_space >= _small_molecules_picker.size.y:
		_put_small_molecules_picker_bellow()
	elif up_space >= _small_molecules_picker.size.y:
		_put_small_molecules_picker_avobe()
	elif up_space > down_space:
		_small_molecules_picker.size.y = up_space
		_put_small_molecules_picker_avobe()
	else:
		_small_molecules_picker.size.y = down_space
		_put_small_molecules_picker_bellow()
	
	_small_molecules_picker.popup()


func _on_small_molecules_picker_molecule_selected(in_path: String) -> void:
	var _parameters: NanoParticleEmitterParameters = _get_emitter_parameters()
	var unpacked_mol_path: String = WorkspaceUtils.unpack_mol_file_and_get_path(in_path)
	var absolute_path: String = ProjectSettings.globalize_path(unpacked_mol_path)
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	assert(is_instance_valid(workspace_context))
	var structure: NanoStructure = await WorkspaceUtils.get_nano_structure_from_file(workspace_context, absolute_path, false, false, false)
	structure.set_structure_name(in_path.get_file().get_basename())
	structure.set_representation_settings(workspace_context.workspace.representation_settings)
	structure.start_edit()
	_center_template_on_origin(structure)
	structure.end_edit()
	_parameters.set_molecule_template(structure)
	_take_snapshot_if_configured(tr(&"Molecule Template"))


func _center_template_on_origin(out_template: AtomicStructure) -> void:
	var center: Vector3 = out_template.get_aabb().get_center()
	if center.is_equal_approx(Vector3.ZERO):
		return
	var atoms: PackedInt32Array = out_template.get_valid_atoms()
	var positions: PackedVector3Array = []
	for atom_id: int in atoms:
		var new_pos: Vector3 = out_template.atom_get_position(atom_id) - center
		positions.push_back(new_pos)
	out_template.atoms_set_positions(atoms, positions)


func _put_small_molecules_picker_avobe() -> void:
	_small_molecules_picker.position.y = \
		int(_load_molecule_from_library_button.global_position.y - _small_molecules_picker.size.y)


func _put_small_molecules_picker_bellow() -> void:
	_small_molecules_picker.position.y = \
		int(_load_molecule_from_library_button.get_global_rect().end.y)

