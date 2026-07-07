class_name BondsSettings extends DynamicContextControl


var _bonds_toggle: CheckButton
var _labels_toggle: CheckButton
var _hydrogens_toggle: CheckButton
var _dna_representation_option_button: OptionButton
var _nanotube_representation_option_button: OptionButton
var _hide_simulation_boundaries_toggle: CheckButton
var _hide_reference_shapes_toggle: CheckButton
var _hide_dna_objects_toggle: CheckButton
var _hide_virtual_motors_toggle: CheckButton
var _hide_particle_emitters_toggle: CheckButton
var _hide_anchors_and_springs_toggle: CheckButton

var _workspace_context: WorkspaceContext = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_bonds_toggle = $Settings/PanelContainer/VBoxContainer/ShowBondsToggle
		_labels_toggle = $Settings/PanelContainer/VBoxContainer/ShowLabelsToggle
		_hydrogens_toggle = $Settings/PanelContainer/VBoxContainer/ShowHydrogensToggle
		_dna_representation_option_button = %DnaRepresentationOptionButton
		_nanotube_representation_option_button = %NanotubeRepresentationOptionButton
		_hide_simulation_boundaries_toggle = $Settings/PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/HideSimulationBoundariesToggle
		_hide_reference_shapes_toggle = $Settings/PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/HideReferenceShapesToggle
		_hide_dna_objects_toggle = $Settings/PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/HideDnaObjectsToggle
		_hide_virtual_motors_toggle = $Settings/PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/HideVirtualMotorsToggle
		_hide_particle_emitters_toggle = $Settings/PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/HideParticleEmittersToggle
		_hide_anchors_and_springs_toggle = $Settings/PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/HideAnchorsAndSpringsToggle


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_workspace_context = in_workspace_context
	var settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	
	if not in_workspace_context.workspace.representation_settings_changed.is_connected(_on_workspace_representation_settings_changed):
		in_workspace_context.workspace.representation_settings_changed.connect(_on_workspace_representation_settings_changed)
	if not settings.bond_visibility_changed.is_connected(_on_bond_visibility_changed):
		settings.bond_visibility_changed.connect(_on_bond_visibility_changed)
	if not settings.hydrogen_visibility_changed.is_connected(_on_hydrogen_visibility_changed):
		settings.hydrogen_visibility_changed.connect(_on_hydrogen_visibility_changed)
	if not settings.dna_representation_changed.is_connected(_on_dna_representation_changed):
		settings.dna_representation_changed.connect(_on_dna_representation_changed)
	if not settings.nanotube_representation_changed.is_connected(_on_nanotube_representation_changed):
		settings.nanotube_representation_changed.connect(_on_nanotube_representation_changed)
	if not settings.atom_labels_visibility_changed.is_connected(_on_atom_labels_visibility_changed):
		settings.atom_labels_visibility_changed.connect(_on_atom_labels_visibility_changed)
	if not in_workspace_context.history_changed.is_connected(_on_workspace_context_history_changed):
		in_workspace_context.history_changed.connect(_on_workspace_context_history_changed)
	_bonds_toggle.set_pressed_no_signal(_workspace_context.are_bonds_visualised())
	_labels_toggle.set_pressed_no_signal(_workspace_context.are_atom_labels_visualised())
	_hydrogens_toggle.set_pressed_no_signal(_workspace_context.are_hydrogens_visualized())
	_on_dna_representation_changed(settings.get_dna_representation())
	_on_nanotube_representation_changed(settings.get_nanotube_representation())
	_hide_simulation_boundaries_toggle.set_pressed_no_signal(not settings.get_display_simulation_boundaries())
	_update_visibility_during_representation_toggles()
	return true


func _on_workspace_context_history_changed() -> void:
	_update_visibility_during_representation_toggles()


func _update_visibility_during_representation_toggles() -> void:
	var settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	_hide_reference_shapes_toggle.set_pressed_no_signal(settings.get_should_hide_virtual_object_during_simulation(NanoShape))
	_hide_dna_objects_toggle.set_pressed_no_signal(settings.get_should_hide_virtual_object_during_simulation(DnaStructure))
	_hide_virtual_motors_toggle.set_pressed_no_signal(settings.get_should_hide_virtual_object_during_simulation(NanoVirtualMotor))
	_hide_particle_emitters_toggle.set_pressed_no_signal(settings.get_should_hide_virtual_object_during_simulation(NanoParticleEmitter))
	_hide_anchors_and_springs_toggle.set_pressed_no_signal(settings.get_should_hide_virtual_object_during_simulation(NanoVirtualAnchor))


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


func _on_dna_representation_changed(in_representation: RepresentationSettings.DnaRepresentation) -> void:
	_dna_representation_option_button.set_block_signals(true)
	_dna_representation_option_button.select(in_representation)
	_dna_representation_option_button.set_block_signals(false)


func _on_nanotube_representation_changed(in_representation: RepresentationSettings.NanotubeRepresentation) -> void:
	_nanotube_representation_option_button.set_block_signals(true)
	_nanotube_representation_option_button.select(in_representation)
	_nanotube_representation_option_button.set_block_signals(false)


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
		_workspace_context.enable_hydrogens_visualization(false)
	else:
		_workspace_context.disable_hydrogens_visualization(true)
	_workspace_context.snapshot_moment("Change Hydrogen Visibility")


func _on_show_potential_atoms_toggle_toggled(button_pressed: bool) -> void:
	_workspace_context.workspace.representation_settings.set_display_auto_posing(button_pressed)


func _on_dna_representation_option_button_item_selected(index: int) -> void:
	var dna_representation := index as RepresentationSettings.DnaRepresentation
	if dna_representation == _workspace_context.workspace.representation_settings.get_dna_representation():
		return
	_workspace_context.workspace.representation_settings \
		.set_dna_representation(dna_representation)
	_workspace_context.snapshot_moment("Change DNA Representation")


func _on_nanotube_representation_option_button_item_selected(index: int) -> void:
	var nanotube_representation := index as RepresentationSettings.NanotubeRepresentation
	if nanotube_representation == _workspace_context.workspace.representation_settings.get_nanotube_representation():
		return
	_workspace_context.workspace.representation_settings \
		.set_nanotube_representation(nanotube_representation)
	_workspace_context.snapshot_moment("Change Carbon Nanotube Representation")


func _on_hide_simulation_boundaries_toggle_toggled(button_pressed: bool) -> void:
	_workspace_context.workspace.representation_settings.set_display_simulation_boundaries(not button_pressed)


func _on_hide_virtual_objects_toggle(button_pressed: bool, in_type: StringName) -> void:
	_workspace_context.workspace.representation_settings.set_should_hide_virtual_object_during_simulation(in_type, button_pressed)
	_workspace_context.snapshot_moment("Set visibility during simulation of " + in_type.capitalize() + " to "+ ("OFF" if button_pressed else "ON"))
