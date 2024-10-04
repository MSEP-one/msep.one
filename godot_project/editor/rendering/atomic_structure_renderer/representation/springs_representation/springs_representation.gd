class_name SpringsRepresentation extends Representation

const COLOR_LOWLIGHT := Color(1.0, 1.0, 1.0)
const COLOR_HIGHLIGHT := Color(5.0, 5.0, 5.0)
const COLOR_HOVER := Color(0.75, 5.0, 0.75)
const COLOR_EDITABLE := COLOR_LOWLIGHT
const COLOR_NON_EDITABLE := COLOR_LOWLIGHT * 0.5

@onready var _spring_renderer: SpringRenderer = $SpringRenderer


var _workspace_context: WorkspaceContext
var _structure_id: int = Workspace.INVALID_STRUCTURE_ID

var _hovered_spring: int = AtomicStructure.INVALID_SPRING_ID
var _anchors_to_related_springs: Dictionary = {
	# anchor_id : PackedInt32Array<spring_id>
}

var _highlighted_atoms: Dictionary = {
	#atom_id<int> : true/false<bool>
}


func build(in_structure_context: StructureContext) -> void:
	clear()
	
	_structure_id = in_structure_context.get_int_guid()
	_workspace_context = in_structure_context.workspace_context
	_spring_renderer.initialize(in_structure_context)


func add_springs(in_springs: PackedInt32Array) -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	var nano_struct: NanoStructure = structure_context.nano_structure
	for spring_id: int in in_springs:
		var atom_id: int = nano_struct.spring_get_atom_id(spring_id)
		var is_atom_hydrogen: bool = nano_struct.atom_get_atomic_number(atom_id) == PeriodicTable.ATOMIC_NUMBER_HYDROGEN
		var atom_position: Vector3 = nano_struct.atom_get_position(atom_id)
		var position_anchor: Vector3 = nano_struct.spring_get_anchor_position(spring_id, structure_context)
		var direction_to_atom: Vector3 = position_anchor.direction_to(atom_position)
		var anchor_radius: float = NanoVirtualAnchor.MODEL_SIZE * 0.5
		position_anchor += direction_to_atom * anchor_radius
		_spring_renderer.add_spring(spring_id, atom_position, position_anchor, is_atom_hydrogen)
		var anchor_id: int = nano_struct.spring_get_anchor_id(spring_id)
		if not _anchors_to_related_springs.has(anchor_id):
			_anchors_to_related_springs[anchor_id] = PackedInt32Array()
		_anchors_to_related_springs[anchor_id].append(spring_id)
	_spring_renderer.rebuild_check()


func remove_springs(in_removed_springs: PackedInt32Array) -> void:
	for spring_id: int in in_removed_springs:
		_spring_renderer.prepare_spring_for_removal(spring_id)
	_spring_renderer.apply_prepared_removals()


func update_springs_positions(in_springs_to_update: PackedInt32Array) -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	var related_nanostructure: NanoStructure = structure_context.nano_structure
	for spring_id: int in in_springs_to_update:
		var atom_position: Vector3 = related_nanostructure.spring_get_atom_position(spring_id)
		var anchor_position: Vector3 = related_nanostructure.spring_get_anchor_position(spring_id, structure_context)
		var direction_to_atom: Vector3 = anchor_position.direction_to(atom_position)
		var anchor_radius: float = NanoVirtualAnchor.MODEL_SIZE * 0.5
		anchor_position += direction_to_atom * anchor_radius
		_spring_renderer.refresh_spring_position(spring_id, atom_position, anchor_position)


func refresh_atoms_positions(_in_atoms_ids: PackedInt32Array) -> void:
	pass


func highlight_atoms(in_atoms_ids: PackedInt32Array, _new_partially_influenced_bonds: PackedInt32Array,
			_in_bonds_released_from_partial_influence: PackedInt32Array) -> void:
	for atom_id in in_atoms_ids:
		_highlighted_atoms[atom_id] = true


func lowlight_atoms(in_atoms_ids: PackedInt32Array, 
			_in_bonds_released_from_partial_influence: PackedInt32Array,
			_new_partially_influenced_bonds: PackedInt32Array) -> void:
	for atom_id in in_atoms_ids:
		_highlighted_atoms.erase(atom_id)


func set_atom_selection_position_delta(in_movement_delta: Vector3) -> void:
	_spring_renderer.handle_atom_delta_progress(in_movement_delta, _highlighted_atoms.keys())


func handle_anchor_transform_progress(in_anchor: NanoVirtualAnchor,  in_selection_initial_pos: Vector3,
			in_initial_nano_struct_transform: Transform3D, in_gizmo_transform: Transform3D) -> void:
	_spring_renderer.handle_anchor_transform_progress(in_anchor, in_selection_initial_pos,
			in_initial_nano_struct_transform, in_gizmo_transform)


func rotate_atom_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	_spring_renderer.handle_atom_rotation_progress(in_point, in_rotation_to_apply, _highlighted_atoms.keys())


func get_materials() -> Array[ShaderMaterial]:
	assert(false, "Implement me" + "Return materials used by SegmentedMultimesh(es)")
	return []


func add_atoms(_in_atoms_ids: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func remove_atoms(_in_atoms_ids: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func refresh_atoms_atomic_number(_in_atoms_and_atomic_numbers: Array[Vector2i]) -> void:
	assert(false, "Implement me")
	return


func refresh_atoms_sizes() -> void:
	assert(false, "Implement me")
	return


func refresh_atoms_color(_in_atoms: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func refresh_atoms_visibility(_in_atoms_ids: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func refresh_bonds_visibility(_in_bonds_ids: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func refresh_springs_visibility(in_springs_ids: PackedInt32Array) -> void:
	var nano_struct: AtomicStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for spring_id: int in in_springs_ids:
		var is_visible: bool = nano_struct.spring_is_visible(spring_id)
		if is_visible:
			_spring_renderer.show_spring(spring_id)
		else:
			_spring_renderer.hide_spring(spring_id)


func refresh_all() -> void:
	assert(false, "Implement me")
	return


func clear() -> void:
	_hovered_spring = AtomicStructure.INVALID_SPRING_ID
	_anchors_to_related_springs.clear()
	_highlighted_atoms.clear()


func show() -> void:
	assert(false, "Implement me")
	return


func hide() -> void:
	assert(false, "Implement me")
	return


func hydrogens_rendering_off() -> void:
	_spring_renderer.hide_hydrogen_springs()


func hydrogens_rendering_on() -> void:
	_spring_renderer.show_hydrogen_springs()


func add_bonds(_new_bonds: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func remove_bonds(_new_bonds: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func bonds_changed(_changed_bonds: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func highlight_bonds(_in_bonds_ids: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func lowlight_bonds(_in_bonds_ids: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func highlight_springs(in_springs_to_highlight: PackedInt32Array) -> void:
	for spring_id: int in in_springs_to_highlight:
		_spring_renderer.change_spring_color(spring_id, COLOR_HIGHLIGHT)


func lowlight_springs(in_springs_to_lowlight: PackedInt32Array) -> void:
	for spring_id: int in in_springs_to_lowlight:
		_spring_renderer.change_spring_color(spring_id, COLOR_LOWLIGHT)


func hide_bond_rendering() -> void:
	assert(false, "Implement me")
	return


func show_bond_rendering() -> void:
	assert(false, "Implement me")
	return


func set_material_overlay(_in_material: Material) -> void:
	assert(false, "Implement me")
	return


func update(_in_delta_time: float) -> void:
	return


func set_partially_selected_bonds(_in_partially_selected_bonds: PackedInt32Array) -> void:
	assert(false, "Implement me")
	return


func set_atom_convexity(_in_atoms_convexity: float) -> void:
	assert(false, "Implement me")
	# pass is needed to avoid GdScript compile errors on Release when asserts are striped out
	pass


func set_transparency(_in_transparency: float) -> void:
	assert(false, "Implement me")
	# pass is needed to avoid GdScript compile errors on Release when asserts are striped out
	pass


func handle_editable_structures_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	if not _workspace_context.has_nano_structure_context_id(_structure_id):
		assert(ScriptUtils.is_queued_for_deletion_reqursive(self), "structure deleted, this rendering instance is about to be deleted")
		return
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	var is_editable: bool = in_new_editable_structure_contexts.find(structure_context)
	var global_color: Color = Color(COLOR_EDITABLE, 1.0) if is_editable else Color(COLOR_NON_EDITABLE, 1.0)
	_spring_renderer.set_global_color(global_color)


func handle_hover_structure_changed(_in_toplevel_hovered_structure_context: StructureContext,
			in_hovered_structure_context: StructureContext, _in_atom_id: int, _in_bond_id: int,
			in_spring_id: int) -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	if in_hovered_structure_context != structure_context:
		# Hovered bond is not part of this structure, remove roll over if needed
		in_spring_id = AtomicStructure.INVALID_SPRING_ID
	
	if not structure_context.nano_structure.spring_has(_hovered_spring):
		# Previous hovered spring was deleted
		_hovered_spring = AtomicStructure.INVALID_SPRING_ID
	
	if _hovered_spring == in_spring_id:
		return
	
	if _hovered_spring != AtomicStructure.INVALID_SPRING_ID:
		var color := COLOR_HIGHLIGHT if structure_context.is_spring_selected(_hovered_spring) else COLOR_LOWLIGHT
		_spring_renderer.change_spring_color(_hovered_spring, color)
	if in_spring_id != AtomicStructure.INVALID_SPRING_ID:
		_spring_renderer.change_spring_color(in_spring_id, COLOR_HOVER)
	_hovered_spring = in_spring_id


func refresh_atoms_locking(_in_atoms_ids: PackedInt32Array) -> void:
	return


func apply_theme(in_theme: Theme3D) -> void:
	_spring_renderer.change_look(in_theme.create_spring_mesh(), in_theme.create_spring_material())


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_structure_id"] = _structure_id
	snapshot["_hovered_spring"] = _hovered_spring
	snapshot["_anchors_to_related_springs"] = _anchors_to_related_springs.duplicate(true)
	snapshot["_highlighted_atoms"] = _highlighted_atoms.duplicate(true)
	snapshot["_spring_renderer.snapshot"] = _spring_renderer.create_state_snapshot()
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_workspace_context = in_snapshot["_workspace_context"]
	_structure_id = in_snapshot["_structure_id"]
	_hovered_spring = in_snapshot["_hovered_spring"]
	_anchors_to_related_springs = in_snapshot["_anchors_to_related_springs"].duplicate(true)
	_highlighted_atoms = in_snapshot["_highlighted_atoms"].duplicate(true)
	_spring_renderer.apply_state_snapshot(in_snapshot["_spring_renderer.snapshot"])
