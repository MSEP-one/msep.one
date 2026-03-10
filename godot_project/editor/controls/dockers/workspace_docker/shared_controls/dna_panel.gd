class_name  DnaPanel
extends DynamicContextControl


const COLOR_OVERRIDES_ENABLED = false

var _rand_sequence_button: Button
var _user_defined_sequence_button: Button
var _sequence_length_container: HBoxContainer
var _sequence_length_spin_box_slider: SpinBoxSlider
var _dna_sequence_text_edit: TextEdit
var _dna_radius_spin_box_slider: SpinBoxSlider
var _bases_per_turn_spin_box_slider: SpinBoxSlider
var _rise_nanometers_spin_box_slider: SpinBoxSlider
var _initial_twist_spin_box_slider: SpinBoxSlider
var _strand_a_button: Button
var _strand_b_button: Button
var _strand_double_button: Button
# Color Override Controls
var _dont_colorize_backbone_button: Button
var _per_strand_backbone_button: Button
var _backbone_a_color_picker: AdvancedColorPickerButton
var _backbone_b_color_picker: AdvancedColorPickerButton
var _sugar_same_as_backbone_button: Button
var _sugar_same_as_bases_button: Button
var _dont_colorize_bases_button: Button
var _per_strand_bases_button: Button
var _per_groove_button: Button
var _per_base_type_button: Button
var _bases_a_strand_color_picker: AdvancedColorPickerButton
var _bases_b_strand_color_picker: AdvancedColorPickerButton
var _major_groove_color_picker: AdvancedColorPickerButton
var _minor_groove_color_picker: AdvancedColorPickerButton
var _bases_schema_option_button: OptionButton
var _bases_color_pickers: Dictionary[StringName, AdvancedColorPickerButton]

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_rand_sequence_button = %RandSequenceButton as Button
		_user_defined_sequence_button = %UserDefinedSequenceButton as Button
		_sequence_length_container = %SequenceLengthContainer as HBoxContainer
		_sequence_length_spin_box_slider = %SequenceLengthSpinBoxSlider as SpinBoxSlider
		_dna_sequence_text_edit = %DnaSequenceTextEdit as TextEdit
		_dna_radius_spin_box_slider = %DnaRadiusSpinBoxSlider as SpinBoxSlider
		_bases_per_turn_spin_box_slider = %BasesPerTurnSpinBoxSlider as SpinBoxSlider
		_rise_nanometers_spin_box_slider = %RiseNanometersSpinBoxSlider as SpinBoxSlider
		_initial_twist_spin_box_slider = %InitialTwistSpinBoxSlider as SpinBoxSlider
		_strand_a_button = %StrandAButton as Button
		_strand_b_button = %StrandBButton as Button
		_strand_double_button = %StrandDoubleButton as Button
		_dont_colorize_backbone_button = %DontColorizeBackboneButton as Button
		_per_strand_backbone_button = %PerStrandBackboneButton as Button
		_backbone_a_color_picker = %BackboneAColorPicker as AdvancedColorPickerButton
		_backbone_b_color_picker = %BackboneBColorPicker as AdvancedColorPickerButton
		_sugar_same_as_backbone_button = %SugarSameAsBackboneButton as Button
		_sugar_same_as_bases_button = %SugarSameAsBasesButton as Button
		_dont_colorize_bases_button = %DontColorizeBasesButton as Button
		_per_strand_bases_button = %PerStrandBasesButton as Button
		_per_groove_button = %PerGrooveButton as Button
		_per_base_type_button = %PerBaseTypeButton as Button
		_bases_a_strand_color_picker = %BasesAStrandColorPicker as AdvancedColorPickerButton
		_bases_b_strand_color_picker = %BasesBStrandColorPicker as AdvancedColorPickerButton
		_major_groove_color_picker = %MajorGrooveColorPicker as AdvancedColorPickerButton
		_minor_groove_color_picker = %MinorGrooveColorPicker as AdvancedColorPickerButton
		assert(_rand_sequence_button.button_group == _user_defined_sequence_button.button_group)
		_bases_schema_option_button = %BasesSchemaOptionButton
		_bases_color_pickers = {
			&"A" : %BaseAPickerButton,
			&"T" : %BaseTPickerButton,
			&"C" : %BaseCPickerButton,
			&"G" : %BaseGPickerButton,
		}
		_dont_colorize_backbone_button.set_meta(&"backbone_color_policy",
			DnaStructureParameters.BackboneColorPolicy.BACKBONE_NO_COLORS)
		_per_strand_backbone_button.set_meta(&"backbone_color_policy",
			DnaStructureParameters.BackboneColorPolicy.BACKBONE_PER_STRAND)
		_sugar_same_as_backbone_button.set_meta(&"sugar_color_policy",
			DnaStructureParameters.SugarsColorPolicy.SUGAR_SAME_AS_BACKBONE)
		_sugar_same_as_bases_button.set_meta(&"sugar_color_policy",
			DnaStructureParameters.SugarsColorPolicy.SUGAR_SAME_AS_BASES)
		_dont_colorize_bases_button.set_meta(&"bases_color_policy",
			DnaStructureParameters.BasesColorPolicy.BASES_NO_COLORS)
		_per_strand_bases_button.set_meta(&"bases_color_policy",
			DnaStructureParameters.BasesColorPolicy.BASES_PER_STRAND)
		_per_groove_button.set_meta(&"bases_color_policy",
			DnaStructureParameters.BasesColorPolicy.BASES_MAJOR_MINOR_GROOVE)
		_per_base_type_button.set_meta(&"bases_color_policy",
			DnaStructureParameters.BasesColorPolicy.BASES_PER_TYPE)
		if not _rand_sequence_button.button_group.pressed.is_connected(_sequence_button_button_group_pressed):
			_rand_sequence_button.button_group.pressed.connect(_sequence_button_button_group_pressed.unbind(1))
			_sequence_button_button_group_pressed()
		if not _bases_schema_option_button.item_selected.is_connected(_on_bases_schema_option_button_item_selected):
			_bases_schema_option_button.item_selected.connect(_on_bases_schema_option_button_item_selected)
			_backbone_a_color_picker.color = DnaBaseColorPalette.DEFAULT_A_STRAND_COLOR
			_backbone_b_color_picker.color = DnaBaseColorPalette.DEFAULT_B_STRAND_COLOR
			_bases_a_strand_color_picker.color = DnaBaseColorPalette.DEFAULT_A_STRAND_COLOR
			_bases_b_strand_color_picker.color = DnaBaseColorPalette.DEFAULT_B_STRAND_COLOR
			_major_groove_color_picker.color = DnaBaseColorPalette.DEFAULT_MAJOR_GROOVE
			_minor_groove_color_picker.color = DnaBaseColorPalette.DEFAULT_MINOR_GROOVE
			_on_bases_schema_option_button_item_selected(_bases_schema_option_button.selected)
		# TODO: Delete me when feature is complete
		if not COLOR_OVERRIDES_ENABLED:
			%ColorizeOptionsButton.hide()
			%ColorizeMainContainer.hide()


func _sequence_button_button_group_pressed() -> void:
	var pressed_button: Button = _rand_sequence_button.button_group.get_pressed_button()
	_sequence_length_container.visible = pressed_button == _rand_sequence_button
	_dna_sequence_text_edit.visible = pressed_button == _user_defined_sequence_button


func _on_bases_schema_option_button_item_selected(in_index: int) -> void:
	const Schema = DnaBaseColorPalette.Schema
	var schema: Schema = _bases_schema_option_button.get_item_id(in_index) as Schema
	var colors: Dictionary = DnaBaseColorPalette.get_schema_colors_or_empty(schema)
	for base: StringName in _bases_color_pickers.keys():
		var picker: AdvancedColorPickerButton = _bases_color_pickers[base]
		picker.set_block_signals(true)
		picker.color = colors.get(base, picker.color)
		picker.disabled = schema != Schema.CUSTOM
		picker.set_block_signals(false)
