extends DynamicContextControl


const MAX_TREE_HEIGHT: int = 200
const COLOR_DELETED: Color = Color.WEB_GRAY
const DELETED_ICON: Texture2D = preload("res://editor/controls/menu_bar/menu_edit/icons/icon_delete.svg")
const MAX_COVALENT_RADIUS: float = 0.232
const MAX_RELAX_ITERATIONS: int = 5


@onready var _only_selected_checkbox: CheckBox = %OnlySelectedCheckBox
@onready var _all_visible_check_box: CheckBox = %AllVisibleCheckBox
@onready var _invisible_selection_label: InfoLabel = %InvisibleSelectionLabel
@onready var _no_selection_label: InfoLabel = %NoSelectionLabel
@onready var _outdated_results_label: InfoLabel = %OutdatedResultsLabel
@onready var _fix_overlapping_atoms_button: Button = %FixOverlappingAtomsButton
@onready var _validate_button: Button = %ValidateButton
@onready var _button_view_alerts: Button = %ButtonViewAlerts
@onready var _atomic_structure_model_validator: AtomicStructureModelValidator = $AtomicStructureModelValidator


var _workspace_context: WorkspaceContext = null


func _ready() -> void:
	_only_selected_checkbox.toggled.connect(_on_only_selected_checkbox_toggled)
	_validate_button.pressed.connect(_on_validate_button_pressed)
	_button_view_alerts.pressed.connect(_on_button_view_alerts_pressed)
	_fix_overlapping_atoms_button.pressed.connect(_on_fix_overlapping_atoms_button_pressed)
	_fix_overlapping_atoms_button.hide()
	_invisible_selection_label.meta_clicked.connect(_on_invisible_selection_label_meta_clicked)
	_atomic_structure_model_validator.validation_finished.connect(_on_atomic_structure_model_validator_validation_finished)
	_atomic_structure_model_validator.alert_selected.connect(_on_atomic_structure_model_validator_alert_selected)
	_atomic_structure_model_validator.results_outdated.connect(_on_atomic_structure_model_validator_results_outdated)


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_ensure_initialized(in_workspace_context)
	var current_type: CreateObjectParameters.SimulationType = \
		in_workspace_context.create_object_parameters.get_simulation_type()
	if current_type == CreateObjectParameters.SimulationType.VALIDATION:
		ScriptUtils.call_deferred_once(_update_panel_state)
		return true
	return false


# region: internal

func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context != in_workspace_context:
		_workspace_context = in_workspace_context
		in_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		in_workspace_context.create_object_parameters.validate_bonds_requested.connect(_on_create_object_parameters_validate_bonds_requested)
		in_workspace_context.alerts_panel_visibility_changed.connect(_on_workspace_context_alerts_panel_visibility_changed)
		_atomic_structure_model_validator.set_workspace_context(in_workspace_context)
		ScriptUtils.call_deferred_once(_update_panel_state)


func _update_panel_state() -> void:
	_no_selection_label.visible = false
	_validate_button.disabled = false
	var has_selected_atoms: bool = false
	for structure: StructureContext in _workspace_context.get_visible_structure_contexts():
		if structure.get_selected_atoms().size() > 0:
			has_selected_atoms = true
			break
	
	if _only_selected_checkbox.button_pressed and not has_selected_atoms:
		_no_selection_label.visible = true
		_validate_button.disabled = true
	
	if not _workspace_context.get_alert_selected():
		_invisible_selection_label.visible = false
	_update_view_alerts_button()
	
	var has_overlaps: bool = _atomic_structure_model_validator.has_overlapping_atoms()
	_fix_overlapping_atoms_button.visible = has_overlaps


func _on_validate_button_pressed() -> void:
	_workspace_context.clear_alerts()
	var selection_only: bool = _only_selected_checkbox.button_pressed
	_atomic_structure_model_validator.validate_atomic_model(selection_only)


func _on_button_view_alerts_pressed() -> void:
	if _workspace_context.has_alerts():
		_workspace_context.show_alerts_panel()


func _on_fix_overlapping_atoms_button_pressed() -> void:
	_atomic_structure_model_validator.fix_overlapping_atoms()
	_fix_overlapping_atoms_button.hide()


func _on_create_object_parameters_validate_bonds_requested(in_selection_only: bool) -> void:
	# Validating bonds was requested from another UI, we ensure this UI is visible and proceed with validation
	_workspace_context.create_object_parameters.set_simulation_type(
			CreateObjectParameters.SimulationType.VALIDATION)
	_only_selected_checkbox.set_pressed_no_signal(in_selection_only)
	_all_visible_check_box.set_pressed_no_signal(not in_selection_only)
	if ScriptUtils.is_callable_queued(_update_panel_state):
		ScriptUtils.flush_now(_update_panel_state)
	else:
		_update_panel_state()
	_on_validate_button_pressed()


func _on_workspace_context_alerts_panel_visibility_changed(in_is_visible: bool) -> void:
	_button_view_alerts.visible = (not in_is_visible) and _workspace_context.has_alerts()


func _on_workspace_context_selection_in_structures_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_update_panel_state)


func _on_only_selected_checkbox_toggled(_enabled: bool) -> void:
	ScriptUtils.call_deferred_once(_update_panel_state)


func _on_invisible_selection_label_meta_clicked(_meta: Variant) -> void:
	var selected_alert: int = _workspace_context.get_alert_selected()
	if selected_alert:
		_atomic_structure_model_validator.show_hidden_atoms(selected_alert)


func _on_atomic_structure_model_validator_validation_finished(in_found_overlaps: bool) -> void:
	_outdated_results_label.visible = false
	_fix_overlapping_atoms_button.visible = in_found_overlaps
	if _workspace_context.has_alerts():
		_workspace_context.show_alerts_panel()
	ScriptUtils.call_deferred_once(_update_view_alerts_button)


func _on_atomic_structure_model_validator_alert_selected(in_has_invisible_atoms: bool) -> void:
	_invisible_selection_label.visible = in_has_invisible_atoms


func _on_atomic_structure_model_validator_results_outdated() -> void:
	_outdated_results_label.visible = true


func _update_view_alerts_button() -> void:
	var alerts_count: int = _workspace_context.get_alerts_count()
	_button_view_alerts.visible = (not _workspace_context.is_alerts_panel_visible()) and alerts_count > 0
	_button_view_alerts.text = tr_n(&"View %d alert", &"View %d alerts", alerts_count) % alerts_count
