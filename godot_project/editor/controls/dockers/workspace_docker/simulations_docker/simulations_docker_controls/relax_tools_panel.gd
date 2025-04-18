extends DynamicContextControl


const _DIMMED_ALPHA: float = 0.2


var _option_selection_only: CheckBox = null
var _option_all_visible: CheckBox = null
var _option_group: ButtonGroup = null
var _temperature_picker: TemperaturePicker = null
var _check_box_maintain_locks: CheckBox = null
var _check_box_include_springs: CheckBox = null
var _check_box_passivate_molecules: CheckBox = null
var _label_select_only_notice: Label = null
var _button_run_relaxation: Button = null
var _button_view_alerts: Button = null
var _open_mm_failure_tracker: OpenMMFailureTracker
var _atomic_structure_model_validator: AtomicStructureModelValidator = null
var _workspace_context: WorkspaceContext = null
var _selection_only_notice_dimmed: bool = true



func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_option_selection_only = %OptionSelectionOnly as CheckBox
		_option_all_visible = %OptionAllVisible as CheckBox
		_option_group = _option_all_visible.button_group
		_temperature_picker = %TemperaturePicker as TemperaturePicker
		_check_box_maintain_locks = %CheckBoxMaintainLocks as CheckBox
		_check_box_include_springs = %CheckBoxIncludeSprings as CheckBox
		_check_box_passivate_molecules = %CheckBoxPassivateMolecules as CheckBox
		FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
		var show_temperature_picker: bool = FeatureFlagManager.get_flag_value(FeatureFlagManager.RELAX_EDITABLE_TEMPERATURE)
		_temperature_picker.visible = show_temperature_picker
		_label_select_only_notice = %LabelSelectOnlyNotice as Label
		_button_run_relaxation = %ButtonRunRelaxation as Button
		_button_view_alerts = %ButtonViewAlerts as Button
		_open_mm_failure_tracker = %OpenMMFailureTracker as OpenMMFailureTracker
		_atomic_structure_model_validator = %AtomicStructureModelValidator as AtomicStructureModelValidator
		assert(_option_group.get_pressed_button() != null, "There's no a default state!")
		_label_select_only_notice.self_modulate.a = _DIMMED_ALPHA
		_option_group.pressed.connect(_on_option_group_pressed)
		_button_run_relaxation.pressed.connect(_on_button_run_relaxation_pressed)
		_button_view_alerts.pressed.connect(_on_button_view_alerts_pressed)
		_open_mm_failure_tracker.results_collected.connect(_on_open_mm_failure_tracker_results_collected)
		_atomic_structure_model_validator.validation_finished.connect(_on_atomic_structure_model_validator_validation_finished)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_initialized(in_workspace_context)
	ScriptUtils.call_deferred_once(_update_view_alerts_button)
	var current_type: CreateObjectParameters.SimulationType = \
		in_workspace_context.create_object_parameters.get_simulation_type()
	return current_type == CreateObjectParameters.SimulationType.RELAXATION


func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		_open_mm_failure_tracker.set_workspace_context(in_workspace_context)
		in_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		in_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
		in_workspace_context.alerts_panel_visibility_changed.connect(_on_workspace_context_alerts_panel_visibility_changed)
		_atomic_structure_model_validator.set_workspace_context(in_workspace_context)
		_update_button_run_relaxation_state()


func _update_view_alerts_button() -> void:
	var alerts_count: int = _workspace_context.get_alerts_count()
	_button_view_alerts.visible = (not _workspace_context.is_alerts_panel_visible()) and alerts_count > 0
	_button_view_alerts.text = tr_n(&"View %d alert", &"View %d alerts", alerts_count) % alerts_count


func _on_feature_flag_toggled(path: String, new_value: bool) -> void:
	if path == FeatureFlagManager.RELAX_EDITABLE_TEMPERATURE and is_instance_valid(_temperature_picker):
		_temperature_picker.visible = new_value


func _on_workspace_context_selection_in_structures_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_update_button_run_relaxation_state)


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_update_button_run_relaxation_state)


func _on_workspace_context_alerts_panel_visibility_changed(in_is_visible: bool) -> void:
	_button_view_alerts.visible = (not in_is_visible) and _workspace_context.has_alerts()


func _update_button_run_relaxation_state() -> void:
	var can_relax: bool = WorkspaceUtils.can_relax(_workspace_context, _is_relax_selection_only_selected())
	_button_run_relaxation.disabled = not can_relax
	var should_dim_notice: bool = not _button_run_relaxation.disabled
	if _selection_only_notice_dimmed != should_dim_notice:
		_selection_only_notice_dimmed = should_dim_notice
		var tween: Tween = create_tween()
		var target_alpha: float = _DIMMED_ALPHA if should_dim_notice else 1.0
		tween.tween_property(_label_select_only_notice, "self_modulate:a", target_alpha, 0.1)


func _on_option_group_pressed(_in_button: BaseButton) -> void:
	ScriptUtils.call_deferred_once(_update_button_run_relaxation_state)


func _on_button_run_relaxation_pressed() -> void:
	var temperature_in_kelvins: float = _temperature_picker.temperature_kelvins
	var selection_only: bool = _is_relax_selection_only_selected()
	var request: RelaxRequest = null
	if WorkspaceUtils.can_relax(_workspace_context, selection_only):
		if not _workspace_context.ignored_warnings.invalid_tetrahedral_structure:
			var found_bad_angle: bool = WorkspaceUtils.has_invalid_tetrahedral_structure(_workspace_context, selection_only)
			if found_bad_angle:
				var warning_promise: Promise = _workspace_context.show_warning_dialog(
						tr("This model has incorrect tetrahedral bonds. Run \"Validation\" to identify the issues."), tr("Run Validation"), tr("Continue Relaxation"), &"invalid_tetrahedral_structure")
				await warning_promise.wait_for_fulfill()
				if warning_promise.get_result() == true:
					# "Run Validation" button selected
					_workspace_context.create_object_parameters.request_validate_bonds(selection_only)
					return
		var include_springs: bool = _check_box_include_springs.button_pressed
		var lock_atoms: bool = _check_box_maintain_locks.button_pressed
		var passivate_molecules: bool = _check_box_passivate_molecules.button_pressed
		request = WorkspaceUtils.relax(_workspace_context, temperature_in_kelvins, selection_only, include_springs, lock_atoms, passivate_molecules)
	if is_instance_valid(request) and is_instance_valid(request.promise):
		_workspace_context.clear_alerts()
		_open_mm_failure_tracker.track_openmm_relax_request(request)


func _is_relax_selection_only_selected() -> bool:
	assert(_option_group != null, "Option ButtonGroup is null, was this function called too early?")
	return _option_group.get_pressed_button() == _option_selection_only


func _on_button_view_alerts_pressed() -> void:
	if _workspace_context.has_alerts():
		_workspace_context.show_alerts_panel()


func _on_open_mm_failure_tracker_results_collected() -> void:
	var selection_only: bool = _option_selection_only.button_pressed
	_atomic_structure_model_validator.validate_atomic_model(selection_only)
	ScriptUtils.call_deferred_once(_update_view_alerts_button)


func _on_atomic_structure_model_validator_validation_finished(_in_found_overlaps: bool) -> void:
	ScriptUtils.call_deferred_once(_update_view_alerts_button)
