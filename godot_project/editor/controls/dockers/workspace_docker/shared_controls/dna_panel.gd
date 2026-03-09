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

var _bases_schema_option_button: OptionButton
var _bases_color_pickers: Dictionary[StringName, ColorPickerButton]

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
		assert(_rand_sequence_button.button_group == _user_defined_sequence_button.button_group)
		_bases_schema_option_button = %BasesSchemaOptionButton
		_bases_color_pickers = {
			&"A" : %BaseAPickerButton,
			&"T" : %BaseTPickerButton,
			&"C" : %BaseCPickerButton,
			&"G" : %BaseGPickerButton,
		}
		if not _rand_sequence_button.button_group.pressed.is_connected(_sequence_button_button_group_pressed):
			_rand_sequence_button.button_group.pressed.connect(_sequence_button_button_group_pressed.unbind(1))
			_sequence_button_button_group_pressed()
		if not _bases_schema_option_button.item_selected.is_connected(_on_bases_schema_option_button_item_selected):
			_bases_schema_option_button.item_selected.connect(_on_bases_schema_option_button_item_selected)
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
	var colors: Dictionary = {} if schema == Schema.CUSTOM else DnaBaseColorPalette.get_schema_colors(schema)
	for base: StringName in _bases_color_pickers.keys():
		var picker: ColorPickerButton = _bases_color_pickers[base]
		picker.set_block_signals(true)
		picker.color = colors.get(base, picker.color)
		picker.disabled = schema != Schema.CUSTOM
		picker.set_block_signals(false)
