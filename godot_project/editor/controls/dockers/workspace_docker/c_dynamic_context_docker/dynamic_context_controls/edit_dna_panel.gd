extends DnaPanel


const StrandPolicy = DnaStructure.StrandPolicy


var _select_one_info_label: InfoLabel
var _main_container: Container
var _start_stop_editing_button: Button

var _workspace_context: WorkspaceContext
var _tracked_structure: DnaStructure = null
var _initialized: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED and !_initialized:
		_initialized = true
		_select_one_info_label = %SelectOneInfoLabel as InfoLabel
		_main_container = $VBoxContainer as Container
		_start_stop_editing_button = %StartStopEditingButton as Button
		_dna_sequence_text_edit.text_changed.connect(_on_dna_sequence_text_edit_text_changed)
		_dna_radius_spin_box_slider.value_confirmed.connect(_on_dna_radius_spin_box_slider_value_confirmed)
		_bases_per_turn_spin_box_slider.value_confirmed.connect(_on_bases_per_turn_spin_box_slider_value_confirmed)
		_rise_nanometers_spin_box_slider.value_confirmed.connect(_on_rise_nanometers_spin_box_slider_value_confirmed)
		_strand_a_button.button_group.pressed.connect(_on_strand_policy_button_group_button_pressed)
		_include_hydrogens_check_button.toggled.connect(_on_include_hydrogens_check_button_toggled)
		_start_stop_editing_button.pressed.connect(_on_start_stop_editing_button_pressed)
		# TODO: Connect controls signals


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_workspace_initialized(in_workspace_context)
	
	var selected_count: int = 0
	var structure: DnaStructure
	var edited_spline_context: StructureContext = in_workspace_context.get_edited_dna_spline_context()
	if edited_spline_context != null:
		selected_count = 1
		structure = edited_spline_context.nano_structure as DnaStructure
		_start_stop_editing_button.text = tr(&"Stop Editing Path")
	else:
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
	if not _workspace_context.dna_spline_edit_started.is_connected(_on_dna_spline_edition_started):
		_workspace_context.dna_spline_edit_started.connect(_on_dna_spline_edition_started)
		_workspace_context.dna_spline_edit_ended.connect(_on_dna_spline_edition_ended)
		# Assume not active edition during initialization
		assert(_workspace_context.get_edited_dna_spline_id() == Workspace.INVALID_STRUCTURE_ID)
		_on_dna_spline_edition_ended()


func _set_tracked_structure(in_structure_or_null: DnaStructure) -> void:
	if in_structure_or_null == _tracked_structure:
		return
	if _tracked_structure != null:
		_tracked_structure.sequence_changed.disconnect(_on_tracked_structure_sequence_changed)
	_tracked_structure = in_structure_or_null
	if in_structure_or_null != null:
		_tracked_structure.sequence_changed.connect(_on_tracked_structure_sequence_changed)
		_dna_sequence_text_edit.set_block_signals(true)
		_dna_sequence_text_edit.text = _tracked_structure.get_sequence()
		_dna_sequence_text_edit.set_block_signals(false)
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
		_dna_sequence_text_edit.text = in_sequence
		_dna_sequence_text_edit.set_block_signals(false)


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


func _on_start_stop_editing_button_pressed() -> void:
	assert(_tracked_structure != null, "Invalid ui state")
	if _workspace_context.get_edited_dna_spline_context() == null:
		_workspace_context.start_editing_dna_spline(_tracked_structure.get_int_guid())
		_workspace_context.snapshot_moment("Start Editing DNA Spline")
	else:
		assert(_workspace_context.get_edited_dna_spline_id() == _tracked_structure.int_guid)
		_workspace_context.stop_editing_dna_spline()
		_workspace_context.snapshot_moment("Stop Editing DNA Spline")


func _on_dna_spline_edition_started(dna_context: StructureContext) -> void:
	assert(_tracked_structure == dna_context.nano_structure)
	_start_stop_editing_button.text = tr(&"Stop Editing Path")


func _on_dna_spline_edition_ended() -> void:
	_start_stop_editing_button.text = tr(&"Start Editing Path")

