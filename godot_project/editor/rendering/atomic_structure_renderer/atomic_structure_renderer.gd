class_name AtomicStructureRenderer extends Node3D
## Responsible for rendering single NanoStructure
## It's accomplishing this by managing all the possible NanoStructure renderers and their states

var material_overlay: Material = null: set = set_material_overlay

@onready var _balls_and_sticks_representation: BallsAndSticksRepresentation = $BallsAndSticksRepresentation
@onready var _sticks_and_single_atom_representation: SticksAndSingleAtomRepresentation = $SticksAndSingleAtomRepresentation
@onready var _enhanced_sticks_and_single_atom_representation: SticksAndSingleAtomRepresentation = $EnhancedSticksAndSingleAtomRepresentation
@onready var _enhanced_sticks_and_balls_representation: EnhancedSticksAndBallsRepresentation = $EnhancedSticksAndBallsRepresentation
@onready var _representation_to_node_map: Dictionary = {
	Rendering.Representation.VAN_DER_WAALS_SPHERES: _balls_and_sticks_representation,
	Rendering.Representation.MECHANICAL_SIMULATION: _balls_and_sticks_representation,
	Rendering.Representation.STICKS: _sticks_and_single_atom_representation,
	Rendering.Representation.ENHANCED_STICKS: _enhanced_sticks_and_single_atom_representation,
	Rendering.Representation.BALLS_AND_STICKS: _balls_and_sticks_representation,
	Rendering.Representation.ENHANCED_STICKS_AND_BALLS: _enhanced_sticks_and_balls_representation
}
@onready var _current_representation: Representation = _representation_to_node_map[_rendering_representation]
@onready var _labels_representation: LabelsRepresentation = $LabelsRepresentation
@onready var _springs_representation: SpringsRepresentation = $SpringsRepresentation


var _is_labels_representation_enabled: bool = RepresentationSettings.LABELS_VISIBLE_BY_DEFAULT
var _is_hydrogens_representation_enabled: bool = RepresentationSettings.HYDROGENS_VISIBLE_BY_DEFAULT
var _are_labels_available_for_current_representation: bool = true
var _is_label_representation_up_to_date: bool = true
var _rendering_representation := Rendering.Representation.BALLS_AND_STICKS
var _nano_structure_id: int = Workspace.INVALID_STRUCTURE_ID
var _is_built: bool = false
var _up_to_date_representations: Dictionary = {
#	Rendering.Representation: true
}
var _workspace_context: WorkspaceContext = null

func rebuild() -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_nano_structure_id)
	_current_representation.build(structure_context)
	_current_representation.refresh_all()
	_current_representation.show()


func snapshot_rebuild(in_structure_context: StructureContext) -> void:
	_nano_structure_id = in_structure_context.get_int_guid()
	_current_representation.build(in_structure_context)
	_current_representation.refresh_all()
	_current_representation.show()
	_labels_representation.build(in_structure_context)
	_springs_representation.build(in_structure_context)


func build(in_structure_context: StructureContext, in_representation: Rendering.Representation) -> void:
	assert(is_instance_valid(in_structure_context.nano_structure), "trying to build renderer based on non existing NanoStructure")
	assert(not _is_built, "this AtomicStructureRenderer is already built")
	_workspace_context = in_structure_context.workspace_context
	_rendering_representation = in_representation
	_current_representation = _representation_to_node_map[in_representation]
	_nano_structure_id = in_structure_context.get_int_guid()
	_internal_build()
	_refresh_label_visibility_state()
	refresh_atom_sizes()
	_ensure_selectable_property_tracked(in_structure_context)
	_current_representation.show()


func _internal_build() -> void:
	assert(_workspace_context.workspace.has_structure_with_int_guid(_nano_structure_id), "trying to build renderer based on non existing NanoStructure")
	var structure_context: StructureContext = _workspace_context.get_structure_context(_nano_structure_id)
	_springs_representation.build(structure_context)
	_current_representation.build(structure_context)
	_up_to_date_representations[_rendering_representation] = true
	var nano_structure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_nano_structure_id) as NanoStructure
	visible = nano_structure.get_visible()
	if not nano_structure.atoms_moved.is_connected(_on_nanostructure_atoms_moved):
		nano_structure.atoms_moved.connect(_on_nanostructure_atoms_moved)
	if not nano_structure.atoms_atomic_number_changed.is_connected(_on_nanostructure_atoms_atomic_number_changed):
		nano_structure.atoms_atomic_number_changed.connect(_on_nanostructure_atoms_atomic_number_changed)
	if not nano_structure.atoms_color_override_changed.is_connected(_on_nanostructure_atoms_color_override_changed):
		nano_structure.atoms_color_override_changed.connect(_on_nanostructure_atoms_color_override_changed)
	if not nano_structure.visibility_changed.is_connected(_on_nanostructure_visibility_changed):
		nano_structure.visibility_changed.connect(_on_nanostructure_visibility_changed)
	if not nano_structure.atoms_visibility_changed.is_connected(_on_nanostructure_atoms_visibility_changed):
		nano_structure.atoms_visibility_changed.connect(_on_nanostructure_atoms_visibility_changed)
	if not nano_structure.bonds_visibility_changed.is_connected(_on_nanostructure_bonds_visibility_changed):
		nano_structure.bonds_visibility_changed.connect(_on_nanostructure_bonds_visibility_changed)
	if not nano_structure.springs_visibility_changed.is_connected(_on_nanostructure_springs_visibility_changed):
		nano_structure.springs_visibility_changed.connect(_on_nanostructure_springs_visibility_changed)
	if not nano_structure.atoms_added.is_connected(_on_nanostructure_atoms_added):
		nano_structure.atoms_added.connect(_on_nanostructure_atoms_added)
	if not nano_structure.atoms_removed.is_connected(_on_nanostructure_atoms_removed):
		nano_structure.atoms_removed.connect(_on_nanostructure_atoms_removed)
	if not nano_structure.atoms_cleared.is_connected(_on_nanostructure_atoms_cleared):
		nano_structure.atoms_cleared.connect(_on_nanostructure_atoms_cleared)
	if not nano_structure.bonds_removed.is_connected(_on_nanostructure_bonds_removed):
		nano_structure.bonds_removed.connect(_on_nanostructure_bonds_removed)
	if not nano_structure.bonds_created.is_connected(_on_nanostructure_bonds_created):
		nano_structure.bonds_created.connect(_on_nanostructure_bonds_created)
	if not nano_structure.bonds_changed.is_connected(_on_nanostructure_bonds_changed):
		nano_structure.bonds_changed.connect(_on_nanostructure_bonds_changed)
	if not nano_structure.atoms_locking_changed.is_connected(_on_nanostructure_atoms_locking_changed):
		nano_structure.atoms_locking_changed.connect(_on_nanostructure_atoms_locking_changed)
	if not nano_structure.springs_added.is_connected(_on_nanostructure_springs_added):
		nano_structure.springs_added.connect(_on_nanostructure_springs_added)
	if not nano_structure.springs_moved.is_connected(_on_nanostructure_springs_moved):
		nano_structure.springs_moved.connect(_on_nanostructure_springs_moved)
	if not nano_structure.springs_removed.is_connected(_on_nanostructure_springs_removed):
		nano_structure.springs_removed.connect(_on_nanostructure_springs_removed)
	
	_is_built = true
	if _are_labels_active():
		_labels_representation.build(structure_context)


func set_workspace_context(in_worksapce_context: WorkspaceContext) -> void:
	_workspace_context = in_worksapce_context


func _ensure_selectable_property_tracked(in_structure_context: StructureContext) -> void:
	if in_structure_context.is_context_of_object_being_created():
		# previews cannot be hovered
		return
	var workspace_context: WorkspaceContext = in_structure_context.workspace_context
	if not workspace_context.editable_structure_context_list_changed.is_connected(_on_workspace_context_editable_structure_context_list_changed):
		workspace_context.editable_structure_context_list_changed.connect(_on_workspace_context_editable_structure_context_list_changed)
		workspace_context.hovered_structure_context_changed.connect(_on_workspace_context_hovered_structure_context_changed)
		_current_representation.handle_editable_structures_changed([])


func _on_workspace_context_editable_structure_context_list_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	_current_representation.handle_editable_structures_changed(in_new_editable_structure_contexts)
	_springs_representation.handle_editable_structures_changed(in_new_editable_structure_contexts)
	_outdate_non_active_representations()


func _on_workspace_context_hovered_structure_context_changed(
			in_toplevel_hovered_structure_context: StructureContext, in_hovered_structure_context: StructureContext,
			in_atom_id: int, in_bond_id: int, in_spring_id: int) -> void:
	_current_representation.handle_hover_structure_changed(in_toplevel_hovered_structure_context,
			in_hovered_structure_context, in_atom_id, in_bond_id, in_spring_id)
	_springs_representation.handle_hover_structure_changed(in_toplevel_hovered_structure_context,
			in_hovered_structure_context, in_atom_id, in_bond_id, in_spring_id)
	_outdate_non_active_representations()


func set_material_overlay(in_material_overlay: Material) -> void:
	material_overlay = in_material_overlay
	for representation: Representation in _representation_to_node_map.values():
		representation.set_material_overlay(material_overlay)


func refresh_atom_sizes() -> void:
	_current_representation.refresh_atoms_sizes()
	if _are_labels_active():
		_labels_representation.refresh_atoms_sizes()
	_outdate_non_active_representations()


func saturate() -> void:
	_current_representation.saturate()
	_outdate_non_active_representations()


func desaturate() -> void:
	_current_representation.desaturate()
	_outdate_non_active_representations()


func change_representation(new_representation: Rendering.Representation) -> void:
	var struct_context: StructureContext = _workspace_context.get_structure_context(_nano_structure_id)
	var old_representation: Representation = _current_representation
	var old_rendering_representation: Rendering.Representation = _rendering_representation
	_current_representation.hide()
	_rendering_representation = new_representation
	_current_representation = _representation_to_node_map[new_representation]
	var is_representation_up_to_date: bool = _up_to_date_representations.get(_rendering_representation, false)
	if not is_representation_up_to_date and is_instance_valid(struct_context):
		_current_representation.build(struct_context)
		_up_to_date_representations[_rendering_representation] = true
	
	_current_representation.refresh_all()
	_current_representation.show()
	_refresh_label_visibility_state()
	_reset_representation_highlight(old_representation, old_rendering_representation, new_representation)


# ensure old representation highlight is removed (to keep it in clean state when inactive)
# and highlight new representationcode
func _reset_representation_highlight(in_old_representation: Representation,
			in_old_rendering_representation: Rendering.Representation,
			in_new_representation: Rendering.Representation) -> void:
	var struct_context: StructureContext = _workspace_context.get_structure_context(_nano_structure_id)
	var selected_atoms: PackedInt32Array = struct_context.get_selected_atoms()
	var selected_bonds: PackedInt32Array = struct_context.get_selected_bonds()
	var partially_influenced_bonds: PackedInt32Array = struct_context.get_bonds_partially_influenced_by_selection()
	in_old_representation.lowlight_atoms(selected_atoms, partially_influenced_bonds, [])
	in_old_representation.lowlight_bonds(selected_bonds)
	_current_representation.highlight_atoms(selected_atoms, partially_influenced_bonds, PackedInt32Array())
	_current_representation.highlight_bonds(selected_bonds)
	
	if not _is_labels_representation_enabled:
		return
	
	var labels_avail_in_old_representation: bool = _are_labels_available_for_representation(in_old_rendering_representation)
	var labels_avail_in_new_representation: bool = _are_labels_available_for_representation(in_new_representation)
	if labels_avail_in_old_representation and not labels_avail_in_new_representation:
		_labels_representation.lowlight_atoms(selected_atoms, partially_influenced_bonds, [])
		_labels_representation.lowlight_bonds(selected_bonds)
	if labels_avail_in_new_representation:
		_labels_representation.highlight_atoms(selected_atoms, PackedInt32Array(), PackedInt32Array())


func _refresh_label_visibility_state() -> void:
	_are_labels_available_for_current_representation = _are_labels_available_for_representation(_rendering_representation)
	var show_labels: bool = _is_labels_representation_enabled and _are_labels_available_for_current_representation
	if show_labels:
		ensure_label_rendering_on()
	else:
		_labels_representation.hide()


func _are_labels_available_for_representation(in_representation: Rendering.Representation) -> bool:
	return in_representation in [
		Rendering.Representation.BALLS_AND_STICKS,
		Rendering.Representation.VAN_DER_WAALS_SPHERES,
		Rendering.Representation.MECHANICAL_SIMULATION,
		Rendering.Representation.ENHANCED_STICKS_AND_BALLS
	]


func _on_nanostructure_atoms_moved(in_moved_atoms: PackedInt32Array) -> void:
	_current_representation.refresh_atoms_positions(in_moved_atoms)
	_outdate_non_active_representations()
	if _are_labels_active():
		_labels_representation.refresh_atoms_positions(in_moved_atoms)
	
	_springs_representation.refresh_atoms_positions(in_moved_atoms)


func _on_nanostructure_atoms_atomic_number_changed(in_changed_atoms: Array[Vector2i]) -> void:
	_current_representation.refresh_atoms_atomic_number(in_changed_atoms)
	if _are_labels_active():
		_labels_representation.refresh_atoms_atomic_number(in_changed_atoms)
	_outdate_non_active_representations()


func _on_nanostructure_atoms_color_override_changed(in_changed_atoms: PackedInt32Array) -> void:
	_current_representation.refresh_atoms_color(in_changed_atoms)


func _on_nanostructure_visibility_changed(new_visibility: bool) -> void:
	visible = new_visibility
	if visible:
		_current_representation.show()
		if _are_labels_active():
			_labels_representation.show()
	else:
		_current_representation.hide()
		_labels_representation.hide()


func _on_nanostructure_atoms_visibility_changed(in_atoms_ids: PackedInt32Array) -> void:
	_current_representation.refresh_atoms_visibility(in_atoms_ids)
	if _are_labels_active():
		_labels_representation.refresh_atoms_visibility(in_atoms_ids)
	_outdate_non_active_representations()


func _on_nanostructure_bonds_visibility_changed(in_bonds_ids: PackedInt32Array) -> void:
	_current_representation.refresh_bonds_visibility(in_bonds_ids)
	_outdate_non_active_representations()


func _on_nanostructure_springs_visibility_changed(in_springs_ids: PackedInt32Array) -> void:
	_springs_representation.refresh_springs_visibility(in_springs_ids)


func _on_nanostructure_atoms_added(in_added_atoms: PackedInt32Array) -> void:
	_current_representation.add_atoms(in_added_atoms)
	if _are_labels_active():
		_labels_representation.add_atoms(in_added_atoms)
	_outdate_non_active_representations()


func _on_nanostructure_atoms_removed(_in_removed_atoms: PackedInt32Array) -> void:
	_current_representation.remove_atoms(_in_removed_atoms)
	if _are_labels_active():
		_labels_representation.remove_atoms(_in_removed_atoms)
	_outdate_non_active_representations()


func _on_nanostructure_atoms_cleared() -> void:
	_current_representation.clear()
	if _are_labels_active():
		_labels_representation.clear()
	_outdate_non_active_representations()


func _on_nanostructure_bonds_removed(_in_removed_bonds: PackedInt32Array) -> void:
	_current_representation.remove_bonds(_in_removed_bonds)
	if _are_labels_active():
		_labels_representation.remove_bonds(_in_removed_bonds)
	_outdate_non_active_representations()


func _on_nanostructure_bonds_created(new_bonds: PackedInt32Array) -> void:
	_current_representation.add_bonds(new_bonds)
	if _are_labels_active():
		_labels_representation.add_bonds(new_bonds)
	_outdate_non_active_representations()


func _on_nanostructure_bonds_changed(in_changed_bonds: PackedInt32Array) -> void:
	_current_representation.bonds_changed(in_changed_bonds)
	if _are_labels_active():
		_labels_representation.bonds_changed(in_changed_bonds)
	_outdate_non_active_representations()


func _on_nanostructure_atoms_locking_changed(in_atoms_changed: PackedInt32Array) -> void:
	_current_representation.refresh_atoms_locking(in_atoms_changed)
	if _are_labels_active():
		_labels_representation.refresh_atoms_locking(in_atoms_changed)
	_outdate_non_active_representations()


func _on_nanostructure_springs_added(in_added_springs: PackedInt32Array) -> void:
	_springs_representation.add_springs(in_added_springs)


func _on_nanostructure_springs_removed(in_removed_springs: PackedInt32Array) -> void:
	_springs_representation.remove_springs(in_removed_springs)


func _on_nanostructure_springs_moved(in_moved_springs: PackedInt32Array) -> void:
	_springs_representation.update_springs_positions(in_moved_springs)


func is_built() -> bool:
	return _is_built


func highlight_atoms(in_atoms_ids: Array, new_partially_influenced_bonds: PackedInt32Array,
			in_bonds_released_from_partial_influence: PackedInt32Array) -> void:
	_current_representation.highlight_atoms(in_atoms_ids, new_partially_influenced_bonds,
			in_bonds_released_from_partial_influence)
	_springs_representation.highlight_atoms(in_atoms_ids, new_partially_influenced_bonds,
			in_bonds_released_from_partial_influence)
	if _are_labels_active():
		_labels_representation.highlight_atoms(in_atoms_ids, new_partially_influenced_bonds,
			in_bonds_released_from_partial_influence)


func lowlight_atoms(in_atoms_ids: Array, in_bonds_released_from_partial_influence: PackedInt32Array,
			new_partially_influenced_bonds: PackedInt32Array) -> void:
	_current_representation.lowlight_atoms(in_atoms_ids, in_bonds_released_from_partial_influence,
			new_partially_influenced_bonds)
	_springs_representation.lowlight_atoms(in_atoms_ids, in_bonds_released_from_partial_influence,
			new_partially_influenced_bonds)
	if _are_labels_active():
		_labels_representation.lowlight_atoms(in_atoms_ids, in_bonds_released_from_partial_influence,
				new_partially_influenced_bonds)


func highlight_bonds(in_bonds_ids: PackedInt32Array) -> void:
	_current_representation.highlight_bonds(in_bonds_ids)
	if _are_labels_active():
		_labels_representation.highlight_bonds(in_bonds_ids)


func lowlight_bonds(in_bonds_ids: PackedInt32Array) -> void:
	_current_representation.lowlight_bonds(in_bonds_ids)
	if _are_labels_active():
		_labels_representation.lowlight_bonds(in_bonds_ids)


func highlight_springs(in_springs_to_highlight: PackedInt32Array) -> void:
	_springs_representation.highlight_springs(in_springs_to_highlight)


func lowlight_springs(in_springs_to_lowlight: PackedInt32Array) -> void:
	_springs_representation.lowlight_springs(in_springs_to_lowlight)


func _outdate_non_active_representations() -> void:
	for representation: Rendering.Representation in _up_to_date_representations:
		if _rendering_representation != representation:
			_up_to_date_representations[representation] = false
	if not _are_labels_active():
		_is_label_representation_up_to_date = false


func ensure_bond_rendering_on() -> void:
	_current_representation.show_bond_rendering()


func ensure_bond_rendering_off() -> void:
	_current_representation.hide_bond_rendering()


func is_label_rendering_enabled() -> bool:
	return _is_labels_representation_enabled


func ensure_label_rendering_on() -> void:
	_labels_representation.refresh_atoms_sizes()
	if _are_labels_active() and _is_label_representation_up_to_date:
		return
	_is_labels_representation_enabled = true
	if not _is_label_representation_up_to_date and _workspace_context.has_nano_structure_context_id(_nano_structure_id): 
		var struct_context: StructureContext = _workspace_context.get_structure_context(_nano_structure_id)
		_labels_representation.build(struct_context)
		_is_label_representation_up_to_date = true
	if _are_labels_available_for_current_representation:
		_labels_representation.show()


func ensure_label_rendering_off() -> void:
	if not _is_labels_representation_enabled:
		return
	_is_labels_representation_enabled = false
	_labels_representation.hide()


func ensure_hydrogens_rendering_off() -> void:
	_current_representation.hydrogens_rendering_off()
	_labels_representation.hydrogens_rendering_off()
	_springs_representation.hydrogens_rendering_off()
	_is_hydrogens_representation_enabled = false


func ensure_hydrogens_rendering_on() -> void:
	_current_representation.hydrogens_rendering_on()
	_labels_representation.hydrogens_rendering_on()
	_springs_representation.hydrogens_rendering_on()
	_is_hydrogens_representation_enabled = true


func is_hydrogen_rendering_enabled() -> bool:
	return _is_hydrogens_representation_enabled


func apply_theme(in_theme: Theme3D) -> void:
	refresh_atom_sizes()
	_labels_representation.apply_theme(in_theme)
	_springs_representation.apply_theme(in_theme)
	for representation: Representation in _representation_to_node_map.values():
		representation.apply_theme(in_theme)
	


func update(delta: float) -> void:
	_current_representation.update(delta)
	if _are_labels_active():
		_labels_representation.update(delta)
	_springs_representation.update(delta)


func refresh_bond_influence(in_partially_selected_bonds: PackedInt32Array) -> void:
	_current_representation.refresh_bond_influence(in_partially_selected_bonds)
	if _are_labels_active():
		_labels_representation.refresh_bond_influence(in_partially_selected_bonds)
	_outdate_non_active_representations()


func set_transparency(in_transparency: float) -> void:
	_current_representation.set_transparency(in_transparency)


func set_atom_selection_position_delta(in_selection_delta: Vector3) -> void:
	_current_representation.set_atom_selection_position_delta(in_selection_delta)
	_springs_representation.set_atom_selection_position_delta(in_selection_delta)
	if _are_labels_active():
		_labels_representation.set_atom_selection_position_delta(in_selection_delta)
	_outdate_non_active_representations()


func rotate_atom_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	_current_representation.rotate_atom_selection_around_point(in_point, in_rotation_to_apply)
	_springs_representation.rotate_atom_selection_around_point(in_point, in_rotation_to_apply)
	if _are_labels_active():
		_labels_representation.rotate_atom_selection_around_point(in_point, in_rotation_to_apply)
	_outdate_non_active_representations()


func _are_labels_active() -> bool:
	return _is_labels_representation_enabled and _are_labels_available_for_current_representation


func update_springs_anchor_positon(in_anchor: NanoVirtualAnchor, in_gizmo_delta: Vector3) -> void:
	_springs_representation.update_spring_anchor_positon(in_anchor, in_gizmo_delta)


func handle_anchor_transform_progress(in_anchor: NanoVirtualAnchor,  in_selection_initial_pos: Vector3,
			in_initial_nano_struct_transform: Transform3D, in_gizmo_transform: Transform3D) -> void:
	_springs_representation.handle_anchor_transform_progress(in_anchor, in_selection_initial_pos,
			in_initial_nano_struct_transform, in_gizmo_transform)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_is_labels_representation_enabled"] = _is_labels_representation_enabled
	snapshot["_is_hydrogens_representation_enabled"] = _is_hydrogens_representation_enabled
	snapshot["_are_labels_available_for_current_representation"] = _are_labels_available_for_current_representation
	snapshot["_is_label_representation_up_to_date"] = _is_label_representation_up_to_date
	snapshot["_rendering_representation"] = _rendering_representation
	snapshot["_is_built"] = _is_built
	snapshot["_nano_structure_id"] = _nano_structure_id
	snapshot["_up_to_date_representations"] = _up_to_date_representations.duplicate(true)
	snapshot["_current_representation.snapshot"] = _current_representation.create_state_snapshot()
	snapshot["_springs_representation.snapshot"] = _springs_representation.create_state_snapshot()
	snapshot["_labels_representation.snapshot"] = _labels_representation.create_state_snapshot()
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_is_labels_representation_enabled = in_snapshot["_is_labels_representation_enabled"]
	_is_hydrogens_representation_enabled = in_snapshot["_is_hydrogens_representation_enabled"]
	_are_labels_available_for_current_representation = in_snapshot["_are_labels_available_for_current_representation"]
	_is_label_representation_up_to_date = in_snapshot["_is_label_representation_up_to_date"]
	_rendering_representation = in_snapshot["_rendering_representation"]
	_is_built = in_snapshot["_is_built"]
	_nano_structure_id = in_snapshot["_nano_structure_id"]
	_up_to_date_representations = in_snapshot["_up_to_date_representations"].duplicate(true)
	_current_representation = _representation_to_node_map[_rendering_representation]
	_current_representation.apply_state_snapshot(in_snapshot["_current_representation.snapshot"])
	_springs_representation.apply_state_snapshot(in_snapshot["_springs_representation.snapshot"])
	_labels_representation.apply_state_snapshot(in_snapshot["_labels_representation.snapshot"])
	_refresh_label_visibility_state()
	
	#
	for representation: Rendering.Representation in _representation_to_node_map:
		if representation != _rendering_representation:
			_representation_to_node_map[representation].hide()
	_current_representation.show()
