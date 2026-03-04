extends DnaPanel

signal tracked_object_changed(out_object: DnaStructure)

const StrandPolicy = DnaStructure.StrandPolicy


var _select_one_info_label: InfoLabel
var _main_container: Container

var _advanced_options_button: Button
var _simulate_hydrogen_bonds_check_button: CheckButton
var _convert_to_atoms_button: Button


var _workspace_context: WorkspaceContext
var _tracked_structure: DnaStructure = null
var _initialized: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED and !_initialized:
		_initialized = true
		_select_one_info_label = %SelectOneInfoLabel as InfoLabel
		_main_container = $VBoxContainer as Container
		_advanced_options_button = %AdvancedOptionsButton as Button
		_simulate_hydrogen_bonds_check_button = %SimulateHydrogenBondsCheckButton as CheckButton
		_convert_to_atoms_button = %ConvertToAtomsButton as Button
		_sequence_length_spin_box_slider.value_confirmed.connect(_sequence_length_spin_box_slider_value_confirmed)
		_dna_sequence_text_edit.text_changed.connect(_on_dna_sequence_text_edit_text_changed)
		_dna_radius_spin_box_slider.value_confirmed.connect(_on_dna_radius_spin_box_slider_value_confirmed)
		_bases_per_turn_spin_box_slider.value_confirmed.connect(_on_bases_per_turn_spin_box_slider_value_confirmed)
		_rise_nanometers_spin_box_slider.value_confirmed.connect(_on_rise_nanometers_spin_box_slider_value_confirmed)
		_initial_twist_spin_box_slider.value_confirmed.connect(_on_initial_twist_spin_box_slider_value_confirmed)
		_strand_a_button.button_group.pressed.connect(_on_strand_policy_button_group_button_pressed)
		_convert_to_atoms_button.pressed.connect(_on_convert_to_atoms_button_pressed)


func _sequence_button_button_group_pressed() -> void:
	var pressed_button: Button = _rand_sequence_button.button_group.get_pressed_button()
	_sequence_length_spin_box_slider.editable = pressed_button == _rand_sequence_button
	_sequence_length_spin_box_slider.visible = true
	_dna_sequence_text_edit.editable = pressed_button == _user_defined_sequence_button
	_dna_sequence_text_edit.visible = true
	if _tracked_structure == null:
		return
	_tracked_structure.start_edit()
	if _rand_sequence_button.button_pressed:
		_tracked_structure.set_sequence_policy(DnaStructure.SequencePolicy.RandomlyGenerated)
	else:
		_tracked_structure.set_sequence_policy(DnaStructure.SequencePolicy.UserDefined)
	_tracked_structure.end_edit()


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(in_workspace_context)
	
	var selected_count: int = 0
	var structure: DnaStructure
	for structure_context: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		if not structure_context.nano_structure is DnaStructure:
			_set_tracked_structure(null)
			return false
		selected_count += 1
		structure = structure_context.nano_structure as DnaStructure
	
	if selected_count == 0:
		_set_tracked_structure(null)
		return false
	elif selected_count > 1:
		_select_one_info_label.show()
		_main_container.hide()
		_set_tracked_structure(null)
	else:
		_select_one_info_label.hide()
		_main_container.show()
		_set_tracked_structure(structure)
	return true


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context
	if not _workspace_context.history_changed.is_connected(_on_history_changed):
		_workspace_context.history_changed.connect(_on_history_changed)


func _on_history_changed() -> void:
	_update_ui()


func _set_tracked_structure(in_structure_or_null: DnaStructure) -> void:
	if in_structure_or_null == _tracked_structure:
		return
	if _tracked_structure != null and _tracked_structure.sequence_changed.is_connected(_on_tracked_structure_sequence_changed):
		_tracked_structure.sequence_changed.disconnect(_on_tracked_structure_sequence_changed)
	_tracked_structure = in_structure_or_null
	if _tracked_structure != null and not _tracked_structure.sequence_changed.is_connected(_on_tracked_structure_sequence_changed):
		_tracked_structure.sequence_changed.connect(_on_tracked_structure_sequence_changed)
	_update_ui()
	_advanced_options_button.ensure_panel_hidden()
	tracked_object_changed.emit(_tracked_structure)


func _update_ui() -> void:
	if _tracked_structure != null:
		if _dna_sequence_text_edit.text != _tracked_structure.get_sequence():
			_on_tracked_structure_sequence_changed(_tracked_structure.get_sequence())
		_dna_radius_spin_box_slider.set_value_no_signal(_tracked_structure.get_dna_radius_nanometers())
		_bases_per_turn_spin_box_slider.set_value_no_signal(_tracked_structure.get_bases_per_turn())
		_rise_nanometers_spin_box_slider.set_value_no_signal(_tracked_structure.get_rise_nanometers())
		_strand_a_button.set_pressed_no_signal(_tracked_structure.get_strand_policy() == StrandPolicy.A)
		_strand_b_button.set_pressed_no_signal(_tracked_structure.get_strand_policy() == StrandPolicy.B)
		_strand_double_button.set_pressed_no_signal(_tracked_structure.get_strand_policy() == StrandPolicy.DOUBLE)


func _on_tracked_structure_sequence_changed(in_sequence: String) -> void:
	_sequence_length_spin_box_slider.set_value_no_signal(in_sequence.length())
	if in_sequence != _dna_sequence_text_edit.text:
		_dna_sequence_text_edit.set_block_signals(true)
		var carets: Array[Vector2i]
		if _dna_sequence_text_edit.has_focus():
			# Remember positions of carets
			for i: int in _dna_sequence_text_edit.get_caret_count():
				carets.append(Vector2i(_dna_sequence_text_edit.get_caret_line(i), _dna_sequence_text_edit.get_caret_column(i)))
		_dna_sequence_text_edit.text = _tracked_structure.get_sequence()
		if _dna_sequence_text_edit.has_focus():
			# Restore positions of carets
			for i in carets.size():
				if i < _dna_sequence_text_edit.get_caret_count():
					_dna_sequence_text_edit.set_caret_line(carets[i][0], false, true, 0, i)
					_dna_sequence_text_edit.set_caret_column(carets[i][1], true, i)
				else:
					_dna_sequence_text_edit.add_caret.call_deferred(carets[i][0], carets[i][1])
		_dna_sequence_text_edit.set_block_signals(false)


func _sequence_length_spin_box_slider_value_confirmed(in_value: int) -> void:
	assert(_tracked_structure != null)
	_tracked_structure.start_edit()
	_tracked_structure.set_sequence_length(in_value)
	_tracked_structure.end_edit()
	_workspace_context.snapshot_moment("Set Dna Sequence Length")


func _on_dna_sequence_text_edit_text_changed() -> void:
	assert(_tracked_structure != null)
	var sequence: String = _dna_sequence_text_edit.text
	_tracked_structure.start_edit()
	_tracked_structure.set_sequence(sequence)
	_tracked_structure.end_edit()
	if sequence != _tracked_structure.get_sequence():
		# Sequence was capped to match chain length
		var caret_line: int = _dna_sequence_text_edit.get_caret_line(0)
		var caret_pos: int = _dna_sequence_text_edit.get_caret_column(0)
		_dna_sequence_text_edit.set_block_signals(true)
		_dna_sequence_text_edit.text = _tracked_structure.get_sequence()
		_dna_sequence_text_edit.set_caret_line(caret_line)
		_dna_sequence_text_edit.set_caret_column(caret_pos)
		_dna_sequence_text_edit.set_block_signals(false)
	_workspace_context.snapshot_moment("Set Dna Sequence")


func _on_dna_radius_spin_box_slider_value_confirmed(in_value: float) -> void:
	assert(_tracked_structure != null)
	_tracked_structure.start_edit()
	_tracked_structure.set_dna_radius_nanometers(in_value)
	_tracked_structure.end_edit()
	_workspace_context.snapshot_moment("Set Dna Object Radius")


func _on_bases_per_turn_spin_box_slider_value_confirmed(in_value: float) -> void:
	assert(_tracked_structure != null)
	_tracked_structure.start_edit()
	_tracked_structure.set_bases_per_turn(in_value)
	_tracked_structure.end_edit()
	_workspace_context.snapshot_moment("Set Dna Bases per turn")


func _on_rise_nanometers_spin_box_slider_value_confirmed(in_value: float) -> void:
	assert(_tracked_structure != null)
	_tracked_structure.start_edit()
	_tracked_structure.set_rise_nanometers(in_value)
	_tracked_structure.end_edit()
	_workspace_context.snapshot_moment("Set Dna Rise per Base")


func _on_initial_twist_spin_box_slider_value_confirmed(in_value: float) -> void:
	assert(_tracked_structure != null)
	_tracked_structure.start_edit()
	_tracked_structure.set_initial_twist_rad(deg_to_rad(in_value))
	_tracked_structure.end_edit()
	_workspace_context.snapshot_moment("Set Initial Helix Twist")


func _on_strand_policy_button_group_button_pressed(in_button: Button) -> void:
	assert(_tracked_structure != null)
	var button_map: Dictionary[Button, StrandPolicy] = {
		_strand_a_button : StrandPolicy.A,
		_strand_b_button : StrandPolicy.B,
		_strand_double_button : StrandPolicy.DOUBLE,
	}
	var policy: StrandPolicy = button_map[in_button]
	if policy == _tracked_structure.get_strand_policy():
		return
	_tracked_structure.start_edit()
	_tracked_structure.set_strand_policy(policy)
	_tracked_structure.end_edit()
	_workspace_context.snapshot_moment("Set Strand Mode")


func _on_include_hydrogens_check_button_toggled(in_button_pressed: bool) -> void:
	assert(_tracked_structure != null)
	_tracked_structure.start_edit()
	_tracked_structure.set_include_hydrogens(in_button_pressed)
	_tracked_structure.end_edit()
	_workspace_context.snapshot_moment("Set Dna Object includes hydrogens")


func _on_convert_to_atoms_button_pressed() -> void:
	assert(_tracked_structure != null, "Invalid ui state")
	if _workspace_context.ignored_warnings.convert_dna_to_atoms == false:
		var warning_promise: Promise = _workspace_context.show_warning_dialog(
				tr("MSEP.one does not support Hydrogen Bonds, so simulations run on DNA may not deliver scientifically accurate results."),
				tr("Continue"), tr("Cancel") , &"convert_dna_to_atoms", true)
		await warning_promise.wait_for_fulfill()
		if warning_promise.get_result() == false:
			# "Cancel" button selected
			return
	# We need to make atoms available, but no bother other parts of the editor
	_tracked_structure.set_block_signals(true)
	_tracked_structure.set_force_track_atoms(true)
	var parent_group: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_tracked_structure.int_parent_guid)
	var new_group: AtomicStructure = AtomicStructure.create()
	new_group.set_structure_name(_tracked_structure.get_structure_name() + "'s atoms")
	_workspace_context.workspace.add_structure(new_group, parent_group)
	new_group.start_edit()
	var atom_map: Dictionary[int, int]
	for strand: DnaStructure.Strand in _tracked_structure.get_strands():
		for atom_id: int in _tracked_structure.get_atom_ids_for_strand(strand):
			var atomic_number: int = _tracked_structure.atom_get_atomic_number(atom_id)
			var pos: Vector3 = _tracked_structure.atom_get_position(atom_id)
			atom_map[atom_id] = new_group.add_atom(AtomicStructure.AddAtomParameters.new(atomic_number, pos))
		for bond_id: int in _tracked_structure.get_bond_ids_for_strand(strand):
			var bond_data: Vector3i = _tracked_structure.get_bond(bond_id)
			# remap atom ids
			new_group.add_bond(atom_map[bond_data.x], atom_map[bond_data.y], bond_data.z)
	if _simulate_hydrogen_bonds_check_button.button_pressed:
		var all_springs: PackedInt32Array = _tracked_structure.springs_get_all()
		# Assume all springs has the same force
		var k: float = 0.0 if all_springs.is_empty() else _tracked_structure.spring_get_constant_force(all_springs[0])
		for spring_id: int in all_springs:
			if _tracked_structure.spring_is_atom_to_atom(spring_id):
				var atom1: int = atom_map[_tracked_structure.spring_get_atom_id(spring_id)]
				var atom2: int = atom_map[_tracked_structure.spring_get_second_atom_id(spring_id)]
				# Also assume all springs use automatic length
				const LENGTH_IS_AUTOMATIC: bool = true
				const DUMMY_LENGTH: float = 0.1
				new_group.spring_create_between_atoms(atom1, atom2, k, LENGTH_IS_AUTOMATIC, DUMMY_LENGTH)
	new_group.end_edit()
	# Done polling atoms, back to normal
	_tracked_structure.set_force_track_atoms(false)
	_tracked_structure.set_block_signals(false)
	_workspace_context.workspace.remove_structure(_tracked_structure)
	var new_context: StructureContext = _workspace_context.get_structure_context(new_group.int_guid)
	new_context.select_all()
	_workspace_context.snapshot_moment("Convert DNA to Atoms and Bonds")
