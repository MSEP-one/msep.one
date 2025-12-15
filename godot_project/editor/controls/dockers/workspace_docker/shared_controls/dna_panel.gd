class_name  DnaPanel
extends DynamicContextControl


var _dna_sequence_text_edit: TextEdit
var _dna_radius_spin_box_slider: SpinBoxSlider
var _bases_per_turn_spin_box_slider: SpinBoxSlider
var _rise_nanometers_spin_box_slider: SpinBoxSlider
var _strand_a_button: Button
var _strand_b_button: Button
var _strand_double_button: Button
var _include_hydrogens_check_button: CheckButton


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_dna_sequence_text_edit = %DnaSequenceTextEdit as TextEdit
		_dna_radius_spin_box_slider = %DnaRadiusSpinBoxSlider as SpinBoxSlider
		_bases_per_turn_spin_box_slider = %BasesPerTurnSpinBoxSlider as SpinBoxSlider
		_rise_nanometers_spin_box_slider = %RiseNanometersSpinBoxSlider as SpinBoxSlider
		_strand_a_button = %StrandAButton as Button
		_strand_b_button = %StrandBButton as Button
		_strand_double_button = %StrandDoubleButton as Button
		_include_hydrogens_check_button = %IncludeHydrogensCheckButton as CheckButton

