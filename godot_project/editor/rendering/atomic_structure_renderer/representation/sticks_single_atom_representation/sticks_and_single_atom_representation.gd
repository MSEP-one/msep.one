class_name SticksAndSingleAtomRepresentation extends Representation


var _single_atom_representation: SingleAtomRepresentation
var _stick_representation: CapsuleStickRepresentation


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_single_atom_representation = get_node("SingleAtomRepresentation")
		_stick_representation = get_node("CapsuleStickRepresentation")


func build(in_structure_context: StructureContext) -> void:
	_single_atom_representation.build(in_structure_context)
	_stick_representation.build(in_structure_context)
	

func highlight_atoms(in_atoms_ids: PackedInt32Array, new_partially_influenced_bonds: PackedInt32Array,
			in_bonds_released_from_partial_influence: PackedInt32Array) -> void:
	_single_atom_representation.highlight_atoms(in_atoms_ids, new_partially_influenced_bonds,
			in_bonds_released_from_partial_influence)
	_stick_representation.highlight_atoms(in_atoms_ids, new_partially_influenced_bonds,
			in_bonds_released_from_partial_influence)


func lowlight_atoms(in_atoms_ids: PackedInt32Array,
			in_bonds_released_from_partial_influence: PackedInt32Array,
			_new_partially_influenced_bonds: PackedInt32Array = PackedInt32Array()) -> void:
	_single_atom_representation.lowlight_atoms(in_atoms_ids, in_bonds_released_from_partial_influence)
	_stick_representation.lowlight_atoms(in_atoms_ids, in_bonds_released_from_partial_influence)


func add_atoms(in_atoms_ids: PackedInt32Array) -> void:
	_single_atom_representation.add_atoms(in_atoms_ids)
	_stick_representation.add_atoms(in_atoms_ids)


func remove_atoms(in_atoms_ids: PackedInt32Array) -> void:
	_single_atom_representation.remove_atoms(in_atoms_ids)
	_stick_representation.remove_atoms(in_atoms_ids)


func refresh_atoms_positions(in_atoms_ids: PackedInt32Array) -> void:
	_single_atom_representation.refresh_atoms_positions(in_atoms_ids)
	_stick_representation.refresh_atoms_positions(in_atoms_ids)


func refresh_atoms_locking(in_atoms_ids: PackedInt32Array) -> void:
	_single_atom_representation.refresh_atoms_locking(in_atoms_ids)
	_stick_representation.refresh_atoms_locking(in_atoms_ids)


func refresh_atoms_atomic_number(in_atoms_and_atomic_numbers: Array[Vector2i]) -> void:
	_single_atom_representation.refresh_atoms_atomic_number(in_atoms_and_atomic_numbers)
	_stick_representation.refresh_atoms_atomic_number(in_atoms_and_atomic_numbers)


func refresh_atoms_sizes() -> void:
	_single_atom_representation.refresh_atoms_sizes()
	_stick_representation.refresh_atoms_sizes()


func refresh_atoms_color(in_atoms: PackedInt32Array) -> void:
	_single_atom_representation.refresh_atoms_color(in_atoms)
	_stick_representation.refresh_atoms_color(in_atoms)


func refresh_atoms_visibility(in_atoms_ids: PackedInt32Array) -> void:
	_single_atom_representation.refresh_atoms_visibility(in_atoms_ids)
	_stick_representation.refresh_atoms_visibility(in_atoms_ids)


func refresh_bonds_visibility(in_bonds_ids: PackedInt32Array) -> void:
	_stick_representation.refresh_bonds_visibility(in_bonds_ids)


func refresh_all() -> void:
	_single_atom_representation.refresh_all()
	_stick_representation.refresh_all()


func clear() -> void:
	_single_atom_representation.clear()
	_stick_representation.clear()


func show() -> void:
	_single_atom_representation.show()
	_stick_representation.show()


func hide() -> void:
	_single_atom_representation.hide()
	_stick_representation.hide()


func hydrogens_rendering_off() -> void:
	_single_atom_representation.hydrogens_rendering_off()
	_stick_representation.hydrogens_rendering_off()


func hydrogens_rendering_on() -> void:
	_single_atom_representation.hydrogens_rendering_on()
	_stick_representation.hydrogens_rendering_on()


func add_bonds(new_bonds: PackedInt32Array) -> void:
	_single_atom_representation.add_bonds(new_bonds)
	_stick_representation.add_bonds(new_bonds)


func remove_bonds(new_bonds: PackedInt32Array) -> void:
	_single_atom_representation.remove_bonds(new_bonds)
	_stick_representation.remove_bonds(new_bonds)


func bonds_changed(_changed_bonds: PackedInt32Array) -> void:
	_single_atom_representation.bonds_changed(_changed_bonds)
	_stick_representation.bonds_changed(_changed_bonds)


func highlight_bonds(in_bonds_ids: PackedInt32Array) -> void:
	_single_atom_representation.highlight_bonds(in_bonds_ids)
	_stick_representation.highlight_bonds(in_bonds_ids)


func lowlight_bonds(_in_bonds_ids: PackedInt32Array) -> void:
	_single_atom_representation.lowlight_bonds(_in_bonds_ids)
	_stick_representation.lowlight_bonds(_in_bonds_ids)


func hide_bond_rendering() -> void:
	return


func show_bond_rendering() -> void:
	return


func set_material_overlay(_in_material: Material) -> void:
	_single_atom_representation.set_material_overlay(_in_material)
	_stick_representation.set_material_overlay(_in_material)


func refresh_bond_influence(in_partially_selected_bonds: PackedInt32Array) -> void:
	_single_atom_representation.set_partially_selected_bonds(in_partially_selected_bonds)
	_stick_representation.set_partially_selected_bonds(in_partially_selected_bonds)


func set_atom_selection_position_delta(in_movement_delta: Vector3) -> void:
	_single_atom_representation.set_atom_selection_position_delta(in_movement_delta)
	_stick_representation.set_atom_selection_position_delta(in_movement_delta)


func rotate_atom_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	_single_atom_representation.rotate_atom_selection_around_point(in_point, in_rotation_to_apply)
	_stick_representation.rotate_atom_selection_around_point(in_point, in_rotation_to_apply)


func set_transparency(in_transparency: float) -> void:
	_single_atom_representation.set_transparency(in_transparency)
	_stick_representation.set_transparency(in_transparency)


func update(in_delta: float) -> void:
	_single_atom_representation.update(in_delta)
	_stick_representation.update(in_delta)


func handle_editable_structures_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	_single_atom_representation.handle_editable_structures_changed(in_new_editable_structure_contexts)
	_stick_representation.handle_editable_structures_changed(in_new_editable_structure_contexts)


func handle_hover_structure_changed(in_toplevel_hovered_structure_context: StructureContext,
			in_hovered_structure_context: StructureContext, in_atom_id: int, in_bond_id: int,
			in_spring_id: int) -> void:
	_single_atom_representation.handle_hover_structure_changed(in_toplevel_hovered_structure_context,
			in_hovered_structure_context, in_atom_id, in_bond_id, in_spring_id)
	_stick_representation.handle_hover_structure_changed(in_toplevel_hovered_structure_context,
			in_hovered_structure_context, in_atom_id, in_bond_id, in_spring_id)


func get_materials() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	materials.append_array(_single_atom_representation.get_materials())
	materials.append_array(_stick_representation.get_materials())
	return materials


func apply_theme(in_theme: Theme3D) -> void:
	_stick_representation.apply_theme(in_theme)
	_single_atom_representation.apply_theme(in_theme)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_single_atom_representation.snapshot"] = _single_atom_representation.create_state_snapshot()
	snapshot["_stick_representation.snapshot"] = _stick_representation.create_state_snapshot()
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_single_atom_representation.apply_state_snapshot(in_snapshot["_single_atom_representation.snapshot"])
	_stick_representation.apply_state_snapshot(in_snapshot["_stick_representation.snapshot"])
	refresh_atoms_sizes()
