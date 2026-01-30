extends DnaPanel


const StrandPolicy = DnaStructure.StrandPolicy
const EditMode = DnaStructure.EditMode


var _select_one_info_label: InfoLabel
var _main_container: Container
var _edit_mode_container: VBoxContainer
var _edit_path_button: Button
var _edit_atoms_button: Button
var _override_colors_check_button: CheckButton
var _create_atoms_button: Button
var _setup_animation_player: AnimationPlayer


var _workspace_context: WorkspaceContext
var _tracked_structure: DnaStructure = null
var _initialized: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED and !_initialized:
		_initialized = true
		_select_one_info_label = %SelectOneInfoLabel as InfoLabel
		_main_container = $VBoxContainer as Container
		_edit_mode_container = %EditModeContainer as VBoxContainer
		_edit_path_button = %EditPathButton as Button
		_edit_atoms_button = %EditAtomsButton as Button
		_override_colors_check_button = %OverrideColorsCheckButton as CheckButton
		_create_atoms_button = %CreateAtomsButton as Button
		_setup_animation_player = %SetupAnimationPlayer as AnimationPlayer
		_edit_path_button.button_group.pressed.connect(_on_edit_mode_button_group_pressed)
		_dna_sequence_text_edit.text_changed.connect(_on_dna_sequence_text_edit_text_changed)
		_dna_radius_spin_box_slider.value_confirmed.connect(_on_dna_radius_spin_box_slider_value_confirmed)
		_bases_per_turn_spin_box_slider.value_confirmed.connect(_on_bases_per_turn_spin_box_slider_value_confirmed)
		_rise_nanometers_spin_box_slider.value_confirmed.connect(_on_rise_nanometers_spin_box_slider_value_confirmed)
		_initial_twist_spin_box_slider.value_confirmed.connect(_on_initial_twist_spin_box_slider_value_confirmed)
		_strand_a_button.button_group.pressed.connect(_on_strand_policy_button_group_button_pressed)
		_include_hydrogens_check_button.toggled.connect(_on_include_hydrogens_check_button_toggled)
		_create_atoms_button.pressed.connect(_on_create_atoms_button_pressed)


func _ready() -> void:
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	_on_feature_flag_toggled(
		FeatureFlagManager.FEATURE_FLAGS_DNA_CHAIN_AS_GROUP_OF_ATOMS,
		FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_DNA_CHAIN_AS_GROUP_OF_ATOMS)
	)


func _on_feature_flag_toggled(in_path: String, in_value: bool) -> void:
	if in_path == FeatureFlagManager.FEATURE_FLAGS_DNA_CHAIN_AS_GROUP_OF_ATOMS:
		_edit_mode_container.visible = in_value


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


func _update_ui() -> void:
	if _tracked_structure != null:
		match _tracked_structure.get_edit_mode():
			EditMode.SequenceAndPath:
				_setup_animation_player.play(&"setup_edit_path")
				_edit_path_button.set_pressed_no_signal(true)
				_edit_atoms_button.set_pressed_no_signal(false)
			EditMode.AtomsAndBonds:
				_setup_animation_player.play(&"setup_edit_atoms")
				_edit_path_button.set_pressed_no_signal(false)
				_edit_atoms_button.set_pressed_no_signal(true)
		if _dna_sequence_text_edit.text != _tracked_structure.get_sequence():
			_on_tracked_structure_sequence_changed(_tracked_structure.get_sequence())
		_dna_radius_spin_box_slider.set_value_no_signal(_tracked_structure.get_dna_radius_nanometers())
		_bases_per_turn_spin_box_slider.set_value_no_signal(_tracked_structure.get_bases_per_turn())
		_rise_nanometers_spin_box_slider.set_value_no_signal(_tracked_structure.get_rise_nanometers())
		_strand_a_button.set_pressed_no_signal(_tracked_structure.get_strand_policy() == StrandPolicy.A)
		_strand_b_button.set_pressed_no_signal(_tracked_structure.get_strand_policy() == StrandPolicy.B)
		_strand_double_button.set_pressed_no_signal(_tracked_structure.get_strand_policy() == StrandPolicy.DOUBLE)
		_include_hydrogens_check_button.set_pressed_no_signal(_tracked_structure.get_include_hydrogens())


func _on_tracked_structure_sequence_changed(in_sequence: String) -> void:
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


func _on_edit_mode_button_group_pressed(in_button: Button) -> void:
	var mode_map: Dictionary[Button, EditMode] = {
		_edit_path_button: EditMode.SequenceAndPath,
		_edit_atoms_button: EditMode.AtomsAndBonds,
	}
	var mode: EditMode = mode_map[in_button]
	if mode == _tracked_structure.get_edit_mode():
		# Re-selected the already selected mode, nothing to do here
		return
	var ctx: StructureContext = _workspace_context.get_structure_context(_tracked_structure.int_guid)
	match mode:
		EditMode.SequenceAndPath:
			var locked_atoms_count: int = _tracked_structure.get_locked_atoms().size()
			var color_overrides_count: int = _tracked_structure.get_color_overrides().size()
			var springs_count: int = _tracked_structure.springs_count()
			var msg: String = (
				tr("This is a destructive operation and any modification to the atoms will be discarded.\n") +
				tr("  · Positions of atoms will reset\n") +
				(tr("  · %d Springs will will be deleted.\n") % springs_count if springs_count > 0 else "") +
				(tr("  · %d atoms will lose it's 'Locking' state.\n") % locked_atoms_count if locked_atoms_count > 0 else "") +
				(tr("  · %d Atoms will lose it's color override.\n") % color_overrides_count if color_overrides_count > 0 else "") + 
				tr("\nDo you want to proceed?")
			)
			var promise: Promise = _workspace_context.show_warning_dialog(
				msg, tr("Continue"), tr("Cancel"))
			await promise.wait_for_fulfill()
			if promise.get_result() == false:
				_edit_path_button.set_pressed_no_signal(false)
				_edit_atoms_button.set_pressed_no_signal(true)
				return
			_workspace_context.get_structure_context(_tracked_structure.get_int_guid()).clear_selection()
			_tracked_structure.set_edit_mode(EditMode.SequenceAndPath)
			_setup_animation_player.play(&"setup_edit_path")
			ctx.select_all()
			_workspace_context.snapshot_moment("DNA Structure: edit Path and Sequence")
		EditMode.AtomsAndBonds:
			_tracked_structure.set_edit_mode(EditMode.AtomsAndBonds)
			_setup_animation_player.play(&"setup_edit_atoms")
			ctx.select_all()
			_workspace_context.snapshot_moment("DNA Structure: show Atoms and Bonds")


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
	_workspace_context.snapshot_moment("Set Dna Chain Radius")


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
	_workspace_context.snapshot_moment("Set Dna Chain includes hydrogens")


func _on_create_atoms_button_pressed() -> void:
	assert(_tracked_structure != null, "Invalid ui state")
	var sequence: String = _tracked_structure.get_sequence()
	var has_invalid_bases: bool = sequence.find("X") != -1
	if has_invalid_bases and _workspace_context.ignored_warnings.convert_dna_with_invalid_bases == false:
		var warning_promise: Promise = _workspace_context.show_warning_dialog(
				tr("DNA Sequence is incomplete. To continue will lead to missing bases in the chain."),
				tr("Continue"), tr("Cancel") , &"convert_dna_with_invalid_bases", true)
		await warning_promise.wait_for_fulfill()
		if warning_promise.get_result() == false:
			# "Cancel" button selected
			return
	var started_in_path_mode: bool = _tracked_structure.get_edit_mode() == EditMode.SequenceAndPath
	if started_in_path_mode:
		# We need to make atoms available, but no bother otehr parts of the editor
		_tracked_structure.set_block_signals(true)
		_tracked_structure.set_edit_mode(EditMode.AtomsAndBonds)
	var parent_group: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_tracked_structure.int_parent_guid)
	var new_group: AtomicStructure = AtomicStructure.create()
	new_group.set_structure_name(_tracked_structure.get_structure_name() + "'s atoms")
	_workspace_context.workspace.add_structure(new_group, parent_group)
	const STRAND_COLOR: Dictionary[DnaStructure.Strand, Color] = {
		DnaStructure.Strand.A : Color.RED,
		DnaStructure.Strand.B : Color.BLUE,
	}
	if _tracked_structure.get_strand_policy() == StrandPolicy.DOUBLE:
		# Split strands in subgroups
		for strand: DnaStructure.Strand in _tracked_structure.get_strands():
			var strand_group: AtomicStructure = AtomicStructure.create()
			strand_group.set_structure_name("Strand " + DnaStructure.Strand.find_key(strand))
			strand_group.start_edit()
			var atom_map: Dictionary[int, int]
			for atom_id: int in _tracked_structure.get_atom_ids_for_strand(strand):
				var atomic_number: int = _tracked_structure.atom_get_atomic_number(atom_id)
				var pos: Vector3 = _tracked_structure.atom_get_position(atom_id)
				atom_map[atom_id] = strand_group.add_atom(AtomicStructure.AddAtomParameters.new(atomic_number, pos))
			for bond_id: int in _tracked_structure.get_bond_ids_for_strand(strand):
				var bond_data: Vector3i = _tracked_structure.get_bond(bond_id)
				# remap atom ids
				strand_group.add_bond(atom_map[bond_data.x], atom_map[bond_data.y], bond_data.z)
			if _override_colors_check_button.button_pressed:
				strand_group.set_color_override(atom_map.values(), STRAND_COLOR[strand])
			strand_group.end_edit()
			_workspace_context.workspace.add_structure(strand_group, new_group)
		pass
	else:
		new_group.start_edit()
		var atom_map: Dictionary[int, int]
		for atom_id: int in _tracked_structure.get_valid_atoms():
			var atomic_number: int = _tracked_structure.atom_get_atomic_number(atom_id)
			var pos: Vector3 = _tracked_structure.atom_get_position(atom_id)
			atom_map[atom_id] = new_group.add_atom(AtomicStructure.AddAtomParameters.new(atomic_number, pos))
		for bond_id: int in _tracked_structure.get_valid_bonds():
			var bond_data: Vector3i = _tracked_structure.get_bond(bond_id)
			# remap atom ids
			new_group.add_bond(atom_map[bond_data.x], atom_map[bond_data.y], bond_data.z)
		if _override_colors_check_button.button_pressed:
			var strand: DnaStructure.Strand = _tracked_structure.get_strands()[0]
			new_group.set_color_override(atom_map.values(), STRAND_COLOR[strand])
		new_group.end_edit()
	if started_in_path_mode:
		# Done polling atoms, back to normal
		_tracked_structure.set_edit_mode(EditMode.SequenceAndPath)
		_tracked_structure.set_block_signals(false)
	_workspace_context.snapshot_moment("Create group from DNA Chain")

