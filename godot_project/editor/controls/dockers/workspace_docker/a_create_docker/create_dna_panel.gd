extends DnaPanel

var _create_button: Button

var _initialized: bool = false
var _workspace_context: WorkspaceContext


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_workspace_context = in_workspace_context
	var structure_context: StructureContext = in_workspace_context.get_current_structure_context()
	if !is_instance_valid(structure_context) || !is_instance_valid(structure_context.nano_structure):
		return false
	
	if not in_workspace_context.get_current_structure_context().nano_structure.can_contain_child_structure():
		return false
	
	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_DNA_CHAIN:
		return false
	
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED and !_initialized == true:
		_initialized = true
		_create_button = %CreateButton as Button
		var default_params := DnaStructureParameters.new()
		_dna_radius_spin_box_slider.value = default_params.dna_radius_nanometers
		_bases_per_turn_spin_box_slider.value = default_params.bases_per_turn
		_rise_nanometers_spin_box_slider.value = default_params.rise_nanometers
		match default_params.strand_policy:
			DnaStructure.StrandPolicy.A:
				_strand_a_button.button_pressed = true
			DnaStructure.StrandPolicy.B:
				_strand_b_button.button_pressed = true
			DnaStructure.StrandPolicy.DOUBLE:
				_strand_double_button.button_pressed = true
		_include_hydrogens_check_button.button_pressed = default_params.include_hydrogens
		_dna_sequence_text_edit.text_changed.connect(_on_dna_sequence_text_edit_text_changed)
		_create_button.pressed.connect(_on_create_button_pressed)
		_create_button.disabled = true
		%OffsetSpinBoxSlider.value = DnaBuilder.DNA_BASES_OFFSET
		FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled.unbind(2))
		_on_feature_flag_toggled()


func _on_feature_flag_toggled() -> void:
	%DevToolLabel.visible = OS.is_debug_build() and DnaBuilder.is_dev_tool_enabled()
	%OffsetSpinBoxSlider.visible = OS.is_debug_build() and DnaBuilder.is_dev_tool_enabled()


func _on_create_button_pressed() -> void:
	var parent_context: StructureContext = _workspace_context.get_current_structure_context()
	assert(parent_context.nano_structure.can_contain_child_structure())
	var params := DnaStructureParameters.new()
	params.dna_radius_nanometers = _dna_radius_spin_box_slider.value
	params.bases_per_turn = _bases_per_turn_spin_box_slider.value
	params.rise_nanometers = _rise_nanometers_spin_box_slider.value
	var strand_button: Button = _strand_a_button.button_group.get_pressed_button()
	match strand_button:
		_strand_a_button:
			params.strand_policy = DnaStructure.StrandPolicy.A
		_strand_b_button:
			params.strand_policy = DnaStructure.StrandPolicy.B
		_strand_double_button:
			params.strand_policy = DnaStructure.StrandPolicy.DOUBLE
		_:
			push_error("Invalid strand polocy_button: ",
				"<null>" if strand_button == null else str(get_path_to(strand_button)))
	params.include_hydrogens = _include_hydrogens_check_button.button_pressed
	if OS.is_debug_build() and DnaBuilder.is_dev_tool_enabled():
		DnaBuilder.DNA_BASES_OFFSET = %OffsetSpinBoxSlider.value

	var dna: DnaStructure = DnaStructure.create_dna(params, _dna_sequence_text_edit.text)
	dna.set_structure_name("DNA Chain%d" % _workspace_context.workspace.get_nmb_of_structures())
	var dna_pos: Vector3 = InputHandlerCreateObjectBase.calculate_preview_position(_workspace_context)
	var right_dir: Vector3 = _workspace_context.get_editor_viewport().get_camera_3d().global_transform.basis.x
	var chain_length: float = params.rise_nanometers * (_dna_sequence_text_edit.text.length() - 1)
	chain_length = max(chain_length, 0.01)
	dna.start_edit()
	dna.insert_control_point(dna_pos - right_dir * chain_length / 2.0)
	dna.insert_control_point(dna_pos + right_dir * chain_length / 2.0)
	dna.end_edit()
	_workspace_context.workspace.add_structure(dna, parent_context.nano_structure)
	_workspace_context.clear_all_selection()
	_workspace_context.get_structure_context(dna.int_guid).set_dna_spline_selected(true)
	WorkspaceUtils.focus_camera_on_aabb(_workspace_context, dna.get_aabb())
	_workspace_context.snapshot_moment("Create DNA Chain")


func _on_dna_sequence_text_edit_text_changed() -> void:
	_create_button.disabled = _dna_sequence_text_edit.text.is_empty()
