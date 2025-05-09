extends DynamicContextControl


var _workspace_context: WorkspaceContext = null

@onready var _max_bond_distance_slider: SpinBoxSlider = %MaxBondDistanceSlider
@onready var _option_selected_atoms: CheckBox = %OptionSelectedAtoms
@onready var _auto_create_bonds_button: Button = %AutoCreateBondsButton
@onready var _no_selection_label: Label = %NoSelectionLabel


func _ready() -> void:
	var max_distance: float = ProjectSettings.get_setting(&"msep/heuristic_bond_assignment/max_length_factor", 3.0)
	_max_bond_distance_slider.set_value_no_signal(max_distance)
	
	_option_selected_atoms.toggled.connect(_on_option_toggled)
	_auto_create_bonds_button.pressed.connect(_on_auto_create_bonds_button_pressed)
	_max_bond_distance_slider.value_changed.connect(_on_max_bond_distance_slider_value_changed)


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_ensure_initialized(in_workspace_context)
	return in_workspace_context.create_object_parameters.get_create_mode_type() \
			== CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS


# region: internal

func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		in_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		in_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
		_update_panel_state()


func _update_panel_state() -> void:
	_no_selection_label.self_modulate.a = 0.0
	_auto_create_bonds_button.disabled = false
	var has_selected_atoms: bool = false
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	for structure: StructureContext in workspace_context.get_visible_structure_contexts():
		if structure.get_selected_atoms().size() > 0:
			has_selected_atoms = true
			break
	
	if _option_selected_atoms.button_pressed and not has_selected_atoms:
		_no_selection_label.self_modulate.a = 1.0
		_auto_create_bonds_button.disabled = true


func _on_auto_create_bonds_button_pressed() -> void:
	var visible_structure_contexts: Array[StructureContext] = \
		_workspace_context.get_visible_structure_contexts()
	
	_workspace_context.start_async_work(tr("Creating Bonds"))
	var new_bonds_count: int = 0
	for context: StructureContext in visible_structure_contexts:
		if context.nano_structure is AtomicStructure:
			var new_bonds: PackedInt32Array = PackedInt32Array()
			new_bonds = await AutoBonder.generate_bonds_for_structure(context, _option_selected_atoms.button_pressed)
			new_bonds_count += new_bonds.size()
	_workspace_context.end_async_work()
	_workspace_context.notify_bonds_auto_created(new_bonds_count)
	if new_bonds_count > 0:
		_workspace_context.snapshot_moment("Automatically Create Bonds")


func _on_max_bond_distance_slider_value_changed(value: float) -> void:
	ProjectSettings.set_setting(&"msep/heuristic_bond_assignment/max_length_factor", value)


func _on_option_toggled(_enabled: bool) -> void:
	ScriptUtils.call_deferred_once(_update_panel_state)


func _on_workspace_context_selection_in_structures_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_update_panel_state)


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_update_panel_state)
