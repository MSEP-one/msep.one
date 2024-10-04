class_name BallsAndSticksRepresentation extends Representation


@onready var _sphere_representation: SphereRepresentation = $"SphereRepresentation"
@onready var _stick_representation: StickRepresentation = $"CylinderStickRepresentation"


var _stick_rendering_visible: bool = RepresentationSettings.BONDS_VISIBLE_BY_DEFAULT


func build(in_structure_context: StructureContext) -> void:
	var representation_settings: RepresentationSettings = in_structure_context.nano_structure.get_representation_settings()
	if not representation_settings.balls_and_sticks_size_source_changed.is_connected(_on_balls_and_sticks_size_source_changed):
		representation_settings.balls_and_sticks_size_source_changed.connect(_on_balls_and_sticks_size_source_changed)
	_sphere_representation.build(in_structure_context)
	_stick_representation.build(in_structure_context)
	if not _stick_rendering_visible:
		_stick_representation.hide()


func highlight_atoms(in_atoms_ids: PackedInt32Array, new_partially_influenced_bonds: PackedInt32Array,
			in_bonds_released_from_partial_influence: PackedInt32Array) -> void:
	_sphere_representation.highlight_atoms(in_atoms_ids, new_partially_influenced_bonds,
			in_bonds_released_from_partial_influence)
	_stick_representation.highlight_atoms(in_atoms_ids, new_partially_influenced_bonds,
			in_bonds_released_from_partial_influence)


func lowlight_atoms(in_atoms_ids: PackedInt32Array,
			in_bonds_released_from_partial_influence: PackedInt32Array,
			new_partially_influenced_bonds: PackedInt32Array) -> void:
	_sphere_representation.lowlight_atoms(in_atoms_ids, in_bonds_released_from_partial_influence, 
			new_partially_influenced_bonds)
	_stick_representation.lowlight_atoms(in_atoms_ids, in_bonds_released_from_partial_influence, 
			new_partially_influenced_bonds)


func add_atoms(in_atoms_ids: PackedInt32Array) -> void:
	_sphere_representation.add_atoms(in_atoms_ids)
	_stick_representation.add_atoms(in_atoms_ids)


func remove_atoms(in_atoms_ids: PackedInt32Array) -> void:
	_sphere_representation.remove_atoms(in_atoms_ids)
	_stick_representation.remove_atoms(in_atoms_ids)


func refresh_atoms_positions(in_atoms_ids: PackedInt32Array) -> void:
	_sphere_representation.refresh_atoms_positions(in_atoms_ids)
	_stick_representation.refresh_atoms_positions(in_atoms_ids)


func refresh_atoms_locking(in_atoms_ids: PackedInt32Array) -> void:
	_sphere_representation.refresh_atoms_locking(in_atoms_ids)
	_stick_representation.refresh_atoms_locking(in_atoms_ids)


func refresh_atoms_atomic_number(in_atoms_and_atomic_numbers: Array[Vector2i]) -> void:
	_sphere_representation.refresh_atoms_atomic_number(in_atoms_and_atomic_numbers)
	_stick_representation.refresh_atoms_atomic_number(in_atoms_and_atomic_numbers)


func refresh_atoms_sizes() -> void:
	_sphere_representation.refresh_atoms_sizes()
	_stick_representation.refresh_atoms_sizes()


func refresh_atoms_color(in_atoms: PackedInt32Array) -> void:
	_sphere_representation.refresh_atoms_color(in_atoms)
	_stick_representation.refresh_atoms_color(in_atoms)


func refresh_atoms_visibility(in_atoms_ids: PackedInt32Array) -> void:
	_sphere_representation.refresh_atoms_visibility(in_atoms_ids)
	_stick_representation.refresh_atoms_visibility(in_atoms_ids)


func refresh_bonds_visibility(in_bonds_ids: PackedInt32Array) -> void:
	_stick_representation.refresh_bonds_visibility(in_bonds_ids)


func refresh_all() -> void:
	_sphere_representation.refresh_all()
	_stick_representation.refresh_all()


func clear() -> void:
	_sphere_representation.clear()
	_stick_representation.clear()


func show() -> void:
	_sphere_representation.show()
	if _stick_rendering_visible:
		_stick_representation.show()


func hide() -> void:
	_sphere_representation.hide()
	_stick_representation.hide()


func hydrogens_rendering_off() -> void:
	_sphere_representation.hydrogens_rendering_off()
	_stick_representation.hydrogens_rendering_off()


func hydrogens_rendering_on() -> void:
	_sphere_representation.hydrogens_rendering_on()
	_stick_representation.hydrogens_rendering_on()


func add_bonds(new_bonds: PackedInt32Array) -> void:
	_sphere_representation.add_bonds(new_bonds)
	_stick_representation.add_bonds(new_bonds)


func remove_bonds(in_removed_bonds: PackedInt32Array) -> void:
	_sphere_representation.remove_bonds(in_removed_bonds)
	_stick_representation.remove_bonds(in_removed_bonds)


func bonds_changed(in_changed_bonds: PackedInt32Array) -> void:
	_sphere_representation.bonds_changed(in_changed_bonds)
	_stick_representation.bonds_changed(in_changed_bonds)


func highlight_bonds(in_bonds_ids: PackedInt32Array) -> void:
	_stick_representation.highlight_bonds(in_bonds_ids)


func lowlight_bonds(in_bonds_ids: PackedInt32Array) -> void:
	_stick_representation.lowlight_bonds(in_bonds_ids)


func set_material_overlay(in_material: Material) -> void:
	_sphere_representation.set_material_overlay(in_material)
	_stick_representation.set_material_overlay(in_material)


func hide_bond_rendering() -> void:
	_stick_representation.hide()
	_stick_rendering_visible = false


func show_bond_rendering() -> void:
	_stick_representation.show()
	_stick_rendering_visible = true


func update(_in_delta: float) -> void:
	_sphere_representation.update(_in_delta)
	_stick_representation.update(_in_delta)


func set_partially_selected_bonds(in_partially_selected_bonds: PackedInt32Array) -> void:
	_stick_representation.set_partially_selected_bonds(in_partially_selected_bonds)


func set_atom_selection_position_delta(in_movement_delta: Vector3) -> void:
	_sphere_representation.set_atom_selection_position_delta(in_movement_delta)
	_stick_representation.set_atom_selection_position_delta(in_movement_delta)


func rotate_atom_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	_sphere_representation.rotate_atom_selection_around_point(in_point, in_rotation_to_apply)
	_stick_representation.rotate_atom_selection_around_point(in_point, in_rotation_to_apply)


func set_transparency(in_transparency: float) -> void:
	_sphere_representation.set_transparency(in_transparency)
	_stick_representation.set_transparency(in_transparency)


func handle_editable_structures_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	_sphere_representation.handle_editable_structures_changed(in_new_editable_structure_contexts)
	_stick_representation.handle_editable_structures_changed(in_new_editable_structure_contexts)


func handle_hover_structure_changed(in_toplevel_hovered_structure_context: StructureContext,
			in_hovered_structure_context: StructureContext, in_atom_id: int, in_bond_id: int,
			in_spring_id: int) -> void:
	_sphere_representation.handle_hover_structure_changed(in_toplevel_hovered_structure_context,
			in_hovered_structure_context, in_atom_id, in_bond_id, in_spring_id)
	_stick_representation.handle_hover_structure_changed(in_toplevel_hovered_structure_context,
			in_hovered_structure_context, in_atom_id, in_bond_id, in_spring_id)


func get_materials() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	materials.append_array(_sphere_representation.get_materials())
	materials.append_array(_stick_representation.get_materials())
	return materials


func apply_theme(in_theme: Theme3D) -> void:
	_sphere_representation.apply_theme(in_theme)
	_stick_representation.apply_theme(in_theme)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_stick_rendering_visible"] = _stick_rendering_visible
	snapshot["_sphere_representation.snapshot"] = _sphere_representation.create_state_snapshot()
	snapshot["_stick_representation.snapshot"] = _stick_representation.create_state_snapshot()
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_stick_rendering_visible = in_snapshot["_stick_rendering_visible"]
	_sphere_representation.apply_state_snapshot(in_snapshot["_sphere_representation.snapshot"])
	_stick_representation.apply_state_snapshot(in_snapshot["_stick_representation.snapshot"])


func _on_balls_and_sticks_size_source_changed(_in_new_source: RepresentationSettings.UserAtomSizeSource) -> void:
	_sphere_representation.refresh_atoms_sizes(true)
	_stick_representation.refresh_atoms_sizes()
