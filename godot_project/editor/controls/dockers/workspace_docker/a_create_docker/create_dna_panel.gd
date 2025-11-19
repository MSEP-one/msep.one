extends DynamicContextControl

var _sequence_text_edit: TextEdit
var _dna_radius_spin_box_slider: SpinBoxSlider
var _double_strand_check_button: CheckButton
var _include_hydrogens_check_button: CheckButton
var _create_button: Button

var _workspace_context: WorkspaceContext

func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_workspace_context = in_workspace_context
	var structure_context: StructureContext = in_workspace_context.get_current_structure_context()
	if !is_instance_valid(structure_context) || !is_instance_valid(structure_context.nano_structure):
		return false

	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_DNA_CHAIN:
		return false
	
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_sequence_text_edit = %SequenceTextEdit as TextEdit
		_dna_radius_spin_box_slider = %DnaRadiusSpinBoxSlider as SpinBoxSlider
		_double_strand_check_button = %DoubleStrandCheckButton as CheckButton
		_include_hydrogens_check_button = %IncludeHydrogensCheckButton as CheckButton
		_create_button = %CreateButton as Button
		var default_params := DnaBuilder.Parameters.new()
		_dna_radius_spin_box_slider.value = default_params.dna_radius_nanometers
		_include_hydrogens_check_button.button_pressed = default_params.include_hydrogens
		_sequence_text_edit.text_changed.connect(_on_sequence_text_edit_text_changed)
		_create_button.pressed.connect(_on_create_button_pressed)
		_create_button.disabled = true
		%OffsetSpinBoxSlider.value = DnaBuilder.DNA_BASES_OFFSET
		FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled.unbind(2))
		_on_feature_flag_toggled()

func _on_feature_flag_toggled() -> void:
	%DevToolLabel.visible = OS.is_debug_build() and DnaBuilder.is_dev_tool_enabled()
	%OffsetSpinBoxSlider.visible = OS.is_debug_build() and DnaBuilder.is_dev_tool_enabled()

func _on_create_button_pressed() -> void:
	var params := DnaBuilder.Parameters.new()
	params.dna_radius_nanometers = _dna_radius_spin_box_slider.value
	params.double_strands = _double_strand_check_button.button_pressed
	params.include_hydrogens = _include_hydrogens_check_button.button_pressed
	if OS.is_debug_build() and DnaBuilder.is_dev_tool_enabled():
		DnaBuilder.DNA_BASES_OFFSET = %OffsetSpinBoxSlider.value

	var dna: AtomicStructure = DnaBuilder.build_dna_structure(_sequence_text_edit.text, params)
	dna.set_structure_name("DNA Chain%d" % _workspace_context.workspace.get_nmb_of_structures())
	var parent_context: StructureContext = _workspace_context.get_current_structure_context()
	_workspace_context.workspace.add_structure(dna, parent_context.nano_structure)
	_workspace_context.snapshot_moment("Create DNA Chain")

func _on_sequence_text_edit_text_changed() -> void:
	_create_button.disabled = _sequence_text_edit.text.is_empty()
