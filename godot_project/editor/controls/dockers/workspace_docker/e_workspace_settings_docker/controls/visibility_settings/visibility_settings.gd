class_name BondsSettings extends DynamicContextControl


var _bonds_toggle: CheckButton
var _labels_toggle: CheckButton
var _hydrogens_toggle: CheckButton

var _workspace_context: WorkspaceContext = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_bonds_toggle = $Settings/PanelContainer/VBoxContainer/ShowBondsToggle
		_labels_toggle = $Settings/PanelContainer/VBoxContainer/ShowLabelsToggle
		_hydrogens_toggle = $Settings/PanelContainer/VBoxContainer/ShowHydrogensToggle


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_workspace_context = in_workspace_context
	var settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	
	if not in_workspace_context.workspace.representation_settings_changed.is_connected(_on_workspace_representation_settings_changed):
		in_workspace_context.workspace.representation_settings_changed.connect(_on_workspace_representation_settings_changed)
	if not settings.bond_visibility_changed.is_connected(_on_bond_visibility_changed):
		settings.bond_visibility_changed.connect(_on_bond_visibility_changed)
	if not settings.hydrogen_visibility_changed.is_connected(_on_hydrogen_visibility_changed):
		settings.hydrogen_visibility_changed.connect(_on_hydrogen_visibility_changed)
	if not settings.atom_labels_visibility_changed.is_connected(_on_atom_labels_visibility_changed):
		settings.atom_labels_visibility_changed.connect(_on_atom_labels_visibility_changed)
		
	_bonds_toggle.set_pressed_no_signal(_workspace_context.are_bonds_visualised())
	_labels_toggle.set_pressed_no_signal(_workspace_context.are_atom_labels_visualised())
	_hydrogens_toggle.set_pressed_no_signal(_workspace_context.are_hydrogens_visualized())
	
	return true


func _on_workspace_representation_settings_changed() -> void:
	var settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	var current_representation: Rendering.Representation = settings.get_rendering_representation()
	var is_bond_toggle_enabled: bool = current_representation in [Rendering.Representation.VAN_DER_WAALS_SPHERES,
			Rendering.Representation.MECHANICAL_SIMULATION, Rendering.Representation.BALLS_AND_STICKS,
			Rendering.Representation.ENHANCED_STICKS_AND_BALLS]
	_bonds_toggle.disabled = not is_bond_toggle_enabled
	_bonds_toggle.set_pressed_no_signal(settings.get_display_bonds())
	_hydrogens_toggle.set_pressed_no_signal(settings.get_hydrogens_visible())
	_labels_toggle.set_pressed_no_signal(settings.get_display_atom_labels())


func _on_bond_visibility_changed(in_visible: bool) -> void:
	_bonds_toggle.set_pressed_no_signal(in_visible)


func _on_hydrogen_visibility_changed(in_visible: bool) -> void:
	_hydrogens_toggle.set_pressed_no_signal(in_visible)


func _on_atom_labels_visibility_changed(in_visible: bool) -> void:
	_labels_toggle.set_pressed_no_signal(in_visible)


func _on_show_bonds_toggle_toggled(button_pressed: bool) -> void:
	var bonds_visible: bool = button_pressed
	_workspace_context.change_bond_visibility(bonds_visible)


func _on_show_labels_toggle_toggled(button_pressed: bool) -> void:
	var bonds_visible: bool = button_pressed
	if bonds_visible:
		_workspace_context.enable_atom_labels()
	else:
		_workspace_context.disable_atom_labels()


func _on_show_hydrogens_toggle_toggled(button_pressed: bool) -> void:
	var new_h_visibility: bool = button_pressed
	var are_hydrogens_visible: bool = _workspace_context.are_hydrogens_visualized()
	if new_h_visibility == are_hydrogens_visible:
		return
	
	if new_h_visibility:
		_workspace_context.enable_hydrogens_visualization()
	else:
		_workspace_context.disable_hydrogens_visualization()
	_workspace_context.snapshot_moment("Change Hydrogen Visibility")
	
