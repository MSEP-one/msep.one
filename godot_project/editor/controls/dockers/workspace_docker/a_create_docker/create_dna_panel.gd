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
		_dna_sequence_text_edit.text_changed.connect(_on_dna_sequence_text_edit_text_changed)
		_create_button.pressed.connect(_on_create_button_pressed)
		_update_create_button()
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
	params.initial_twist_rad = deg_to_rad(_initial_twist_spin_box_slider.value)
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
	if OS.is_debug_build() and DnaBuilder.is_dev_tool_enabled():
		DnaBuilder.DNA_BASES_OFFSET = %OffsetSpinBoxSlider.value
	
	var backbone_color_policy_group: ButtonGroup = _dont_colorize_backbone_button.button_group
	params.backbone_color_policy = backbone_color_policy_group.get_pressed_button() \
		.get_meta(&"backbone_color_policy")
	params.backbone_strand_colors[&"A"] = _backbone_a_color_picker.color
	params.backbone_strand_colors[&"B"] = _backbone_b_color_picker.color
	var sugar_color_policy_group: ButtonGroup = _sugar_same_as_backbone_button.button_group
	params.sugar_color_policy = sugar_color_policy_group.get_pressed_button() \
		.get_meta(&"sugar_color_policy")
	var bases_color_policy_group: ButtonGroup = _dont_colorize_bases_button.button_group
	params.bases_color_policy = bases_color_policy_group.get_pressed_button() \
		.get_meta(&"bases_color_policy")
	params.bases_strand_colors[&"A"] = _bases_a_strand_color_picker.color
	params.bases_strand_colors[&"B"] = _bases_b_strand_color_picker.color
	params.major_groove_color = _major_groove_color_picker.color
	params.minor_groove_color = _minor_groove_color_picker.color
	params.bases_color_schema = _bases_schema_option_button.get_selected_id() as DnaStructureParameters.BasesColorSchema
	for base: StringName in _bases_color_pickers.keys():
		params.bases_custom_colors[base] = _bases_color_pickers[base].color
	
	var dna: DnaStructure = DnaStructure.create_dna(params)
	dna.set_structure_name("DNA Object%d" % _workspace_context.workspace.get_nmb_of_structures())
	var dna_pos: Vector3 = InputHandlerCreateObjectBase.calculate_preview_position(_workspace_context)
	var right_dir: Vector3 = _workspace_context.get_editor_viewport().get_camera_3d().global_transform.basis.x
	var bases_count: int = _dna_sequence_text_edit.text.length() if _user_defined_sequence_button.button_pressed else int(_sequence_length_spin_box_slider.value)
	var chain_length: float = params.rise_nanometers * (bases_count - 1)
	chain_length = max(chain_length, 0.01)
	dna.start_edit()
	if _rand_sequence_button.button_pressed:
		dna.set_sequence_policy(DnaStructure.SequencePolicy.RandomlyGenerated)
		dna.set_sequence_length(bases_count)
	else:
		dna.set_sequence_policy(DnaStructure.SequencePolicy.UserDefined)
		dna.set_sequence(_dna_sequence_text_edit.text)
	dna.insert_control_point(dna_pos - right_dir * chain_length / 2.0)
	dna.insert_control_point(dna_pos + right_dir * chain_length / 2.0)
	dna.end_edit()
	_workspace_context.workspace.add_structure(dna, parent_context.nano_structure)
	_workspace_context.clear_all_selection()
	_workspace_context.get_structure_context(dna.int_guid).select_all()
	WorkspaceUtils.focus_camera_on_aabb(_workspace_context, dna.get_aabb())
	_workspace_context.snapshot_moment("Create DNA Object")


func _on_dna_sequence_text_edit_text_changed() -> void:
	_sequence_length_spin_box_slider.set_value_no_signal(max(_dna_sequence_text_edit.text.length(), 1))
	_update_create_button()


func _sequence_button_button_group_pressed() -> void:
	super._sequence_button_button_group_pressed()
	_update_create_button.call_deferred()


func _update_create_button() -> void:
	if _rand_sequence_button.button_pressed:
		# Assume slider value is always > 0
		_create_button.disabled = false
	else:
		_create_button.disabled = _dna_sequence_text_edit.text.is_empty()
