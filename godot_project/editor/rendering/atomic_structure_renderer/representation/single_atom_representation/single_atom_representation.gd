class_name SingleAtomRepresentation extends Representation

const BASE_SCALE = 0.022;

const SingleAtomMaterial: ShaderMaterial = preload("res://editor/rendering/atomic_structure_renderer/representation/single_atom_representation/assets/single_atom_representation_material.tres")


var _structure_id: int
var _workspace_context: WorkspaceContext
var _material: SphereMaterial
var _hovered_atom_id: int = -1
var _highlighted_atoms: Dictionary = {
	# atom_id<int> : is_highlighted<bool>
}

@onready var _segmented_multimesh: SegmentedMultimesh = $SegmentedMultiMesh as SegmentedMultimesh


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		
		# need unique material as a workaround. Without it preview is also using the same materials but 
		# have different camera and it would use wrong uniforms (from default view-port rendering)
		_material = SingleAtomMaterial.duplicate()
		_segmented_multimesh = $SegmentedMultiMesh
		_segmented_multimesh.set_material_override(_material)


func build(in_structure_context: StructureContext) -> void:
	assert(is_instance_valid(in_structure_context.nano_structure))
	_workspace_context = in_structure_context.workspace_context
	_structure_id = in_structure_context.get_int_guid()
	var related_nanostructure: NanoStructure = in_structure_context.nano_structure
	clear()
	var atoms_ids: PackedInt32Array = related_nanostructure.get_valid_atoms()
	if atoms_ids.size() < 1:
		_segmented_multimesh.bake()
		return
	
	for atom_id: int in in_structure_context.get_selected_atoms():
		_highlighted_atoms[atom_id] = true
	
	var atom_state := Representation.InstanceState.new()
	for atom_id in atoms_ids:
		var bonds: PackedInt32Array = related_nanostructure.atom_get_bonds(atom_id)
		if not bonds.is_empty():
			continue
		var atom_position: Vector3 = related_nanostructure.atom_get_position(atom_id)
		atom_state.is_selected = _highlighted_atoms.get(atom_id, false)
		atom_state.is_visible = not related_nanostructure.is_atom_hidden_by_user(atom_id)
		atom_state.is_hydrogen = related_nanostructure.atom_is_hydrogen(atom_id)
		var color: Color = StickRepresentation.get_bond_color(atom_id, related_nanostructure)
		color.a = atom_state.to_float()
		var atom_scale: Vector3 = Vector3.ONE * BASE_SCALE
		var atom_transform: Transform3D = Transform3D()
		atom_transform = atom_transform.scaled_local(atom_scale)
		atom_transform.origin = atom_position
		_segmented_multimesh.add_particle(atom_id, atom_transform, color, color)
	_segmented_multimesh.bake()
	
	var representation_settings: RepresentationSettings = related_nanostructure.get_representation_settings()
	apply_theme(representation_settings.get_theme())


func _set_hovered_atom_id(in_hovered_atom_id: int) -> void:
	var prev_hovered_atom_id: int = _hovered_atom_id
	_hovered_atom_id = in_hovered_atom_id
	
	if _segmented_multimesh.is_external_id_known(prev_hovered_atom_id):
		_refresh_atom(prev_hovered_atom_id)
	if _segmented_multimesh.is_external_id_known(_hovered_atom_id):
		_refresh_atom(_hovered_atom_id)


func _update_is_selectable_uniform() -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	var is_editable: bool = structure_context.is_editable()
	_material.set_selectable(is_editable)


func add_atoms(in_atoms_ids: PackedInt32Array) -> void:
	for atom_id in in_atoms_ids:
		if _is_bonded_atom(atom_id):
			continue
		_add_atom(atom_id)
	_segmented_multimesh.rebuild_if_needed()


func remove_atoms(in_atoms_ids: PackedInt32Array) -> void:
	for atom_id in in_atoms_ids:
		_highlighted_atoms.erase(atom_id)
		if not _segmented_multimesh.is_external_id_known(atom_id):
			# cannot perform '_is_bonded_atom()' check because bonds has been already removed
			continue
		_segmented_multimesh.queue_particle_removal(atom_id)
	_segmented_multimesh.apply_queued_removals()


func _add_atom(in_atom_id: int) -> void:
	if _is_bonded_atom(in_atom_id):
		return
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	var atom_position: Vector3 = related_nanostructure.atom_get_position(in_atom_id)
	var atom_scale: Vector3 = Vector3.ONE * BASE_SCALE
	var atom_transform: Transform3D = Transform3D()
	atom_transform = atom_transform.scaled_local(atom_scale)
	atom_transform.origin = atom_position
	var bond_color: Color = StickRepresentation.get_bond_color(in_atom_id, related_nanostructure)
	_segmented_multimesh.add_particle(in_atom_id, atom_transform, bond_color, bond_color)


func refresh_atoms_positions(in_atoms_ids: PackedInt32Array) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id in in_atoms_ids:
		if _is_bonded_atom(atom_id):
			continue
		var atom_position: Vector3 = related_nanostructure.atom_get_position(atom_id)
		_segmented_multimesh.update_particle_position(atom_id, atom_position)
	_segmented_multimesh.apply_queued_removals()
	_segmented_multimesh.rebuild_if_needed()


func refresh_atoms_locking(_in_atoms_ids: PackedInt32Array) -> void:
	return


func refresh_atoms_atomic_number(in_atoms_and_atomic_numbers: Array[Vector2i]) -> void:
	for atom_element_pair in in_atoms_and_atomic_numbers:
		var atom_id: int = atom_element_pair[0]
		if _is_bonded_atom(atom_id):
			continue
		_refresh_atom(atom_id)


func refresh_atoms_sizes() -> void:
	return


func refresh_atoms_color(in_atoms: PackedInt32Array) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id: int in in_atoms:
		if not _segmented_multimesh.is_external_id_known(atom_id):
			continue
		var current_color: Color = _segmented_multimesh.get_particle_color(atom_id)
		var additional_color: Color = _segmented_multimesh.get_particle_additional_data(atom_id)
		var new_color: Color
		if related_nanostructure.has_color_override(atom_id):
			new_color = related_nanostructure.get_color_override(atom_id)
		else:
			var atom_atomic_number: int = related_nanostructure.atom_get_atomic_number(atom_id)
			var data: ElementData = PeriodicTable.get_by_atomic_number(atom_atomic_number)
			new_color = data.color
		new_color.a = current_color.a # Preserve the highlight data
		_segmented_multimesh.update_particle_color(atom_id, new_color, additional_color)


func refresh_atoms_visibility(in_atoms_ids: PackedInt32Array) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id: int in in_atoms_ids:
		if not _segmented_multimesh.is_external_id_known(atom_id):
			continue
		var color: Color = _segmented_multimesh.get_particle_color(atom_id)
		var additional_color: Color = _segmented_multimesh.get_particle_additional_data(atom_id)
		var atom_state := Representation.InstanceState.new(color.a)
		atom_state.is_visible = not related_nanostructure.is_atom_hidden_by_user(atom_id)
		color.a = atom_state.to_float()
		_segmented_multimesh.update_particle_color(atom_id, color, additional_color)


func refresh_all() -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id: int in related_nanostructure.get_valid_atoms():
		_refresh_atom(atom_id)


func clear() -> void:
	_segmented_multimesh.prepare()
	_highlighted_atoms.clear()


func show() -> void:
	_material.reset()
	_segmented_multimesh.show()


func hide() -> void:
	_segmented_multimesh.hide()


func add_bonds(_new_bonds: PackedInt32Array) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for bond_id in _new_bonds:
		var bond: Vector3i = related_nanostructure.get_bond(bond_id)
		var first_atom_id: int = bond.x
		var second_atom_id: int = bond.y
		_hide_atom(first_atom_id)
		_hide_atom(second_atom_id)
	_segmented_multimesh.rebuild_if_needed()


func _hide_atom(in_atom_id: int) -> void:
	if not _segmented_multimesh.is_external_id_known(in_atom_id):
		return
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	var atom_position: Vector3 = related_nanostructure.atom_get_position(in_atom_id)
	var atom_transform: Transform3D = Transform3D(Basis().scaled(Vector3.ZERO), atom_position)
	_segmented_multimesh.update_particle(in_atom_id, atom_transform, Color.BLACK)


func remove_bonds(_removed_bonds: PackedInt32Array) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for bond_id in _removed_bonds:
		var bond: Vector3i = related_nanostructure.get_bond(bond_id)
		var first_atom_id: int = bond.x
		var second_atom_id: int = bond.y
		_ensure_atom_rendered(first_atom_id)
		_ensure_atom_rendered(second_atom_id)
	_segmented_multimesh.rebuild_if_needed()


func _ensure_atom_rendered(in_atom_id: int) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	if _segmented_multimesh.is_external_id_known(in_atom_id):
		_refresh_atom(in_atom_id)
	elif related_nanostructure.is_atom_valid(in_atom_id):
		_add_atom(in_atom_id)


func bonds_changed(_changed_bonds: PackedInt32Array) -> void:
	return


func highlight_bonds(_in_bonds_ids: PackedInt32Array) -> void:
	return


func lowlight_bonds(_in_bonds_ids: PackedInt32Array) -> void:
	return
	
	
func set_material_overlay(in_material: Material) -> void:
	_segmented_multimesh.set_material_overlay(in_material)


func highlight_atoms(in_atoms_ids: PackedInt32Array, _new_partially_influenced_bonds: PackedInt32Array,
			_in_bonds_released_from_partial_influence: PackedInt32Array) -> void:
	for atom_id in in_atoms_ids:
		_highlighted_atoms[atom_id] = true
		if _is_bonded_atom(atom_id):
			continue
		_refresh_atom(atom_id)


func lowlight_atoms(in_atoms_ids: PackedInt32Array,
			_in_bonds_released_from_partial_influence: PackedInt32Array,
			_new_partially_influenced_bonds: PackedInt32Array = PackedInt32Array()) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id in in_atoms_ids:
		_highlighted_atoms[atom_id] = false
		if _is_bonded_atom(atom_id):
			continue
		assert(related_nanostructure.is_atom_valid(atom_id), "atempt to lowlight a non existing atom")
		_refresh_atom(atom_id)


func _refresh_atom(in_atom_id: int) -> void:
	if _is_bonded_atom(in_atom_id):
		return
	
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	var can_refresh_atom: bool = true
	if not related_nanostructure.is_atom_valid(in_atom_id):
		can_refresh_atom = _segmented_multimesh.is_external_id_known(in_atom_id)
	
	if not can_refresh_atom:
		# atom was never represented by SingleAtomRepresentation, it's bond has been probably removed in the same
		# NanoStructure edit sequence.
		return
	var atom_position: Vector3 = related_nanostructure.atom_get_position(in_atom_id)
	var atom_scale: Vector3 = Vector3.ONE * BASE_SCALE if related_nanostructure.is_atom_valid(in_atom_id) \
			else Vector3.ZERO
	var atom_color: Color = StickRepresentation.get_bond_color(in_atom_id, related_nanostructure)
	var atom_state := Representation.InstanceState.new()
	atom_state.is_hovered = _hovered_atom_id == in_atom_id
	atom_state.is_selected = _highlighted_atoms.get(in_atom_id, false)
	atom_state.is_visible = not related_nanostructure.is_atom_hidden_by_user(in_atom_id)
	atom_state.is_hydrogen = related_nanostructure.atom_is_hydrogen(in_atom_id)
	atom_color.a = atom_state.to_float()
	var atom_transform: Transform3D = Transform3D()
	atom_transform = atom_transform.scaled_local(atom_scale)
	atom_transform.origin = atom_position
	_segmented_multimesh.update_particle(in_atom_id, atom_transform, atom_color)


func _is_bonded_atom(in_atom_id: int) -> bool:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	var bonds: PackedInt32Array = related_nanostructure.atom_get_bonds(in_atom_id)
	return not bonds.is_empty()


func _update_multimesh_if_needed() -> void:
	if _segmented_multimesh.update_segments_on_movement:
		_segmented_multimesh.rebuild_if_needed()
		_segmented_multimesh.apply_queued_removals()


func set_atom_selection_position_delta(in_movement_delta: Vector3) -> void:
	_material.update_selection_delta(in_movement_delta)


func rotate_atom_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	_material.update_gizmo(in_point, in_rotation_to_apply)
	_update_multimesh_if_needed()


func update(_delta: float) -> void:
	pass


func refresh_bond_influence(_in_partially_selected_bonds: PackedInt32Array) -> void:
	return


func set_transparency(in_transparency: float) -> void:
	_segmented_multimesh.set_transparency(in_transparency)


func hydrogens_rendering_off() -> void:
	_material.disable_hydrogen_rendering()


func hydrogens_rendering_on() -> void:
	_material.enable_hydrogen_rendering()


func handle_editable_structures_changed(_in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	if not _workspace_context.has_nano_structure_context_id(_structure_id):
		assert(ScriptUtils.is_queued_for_deletion_recursive(self), "structure deleted, this rendering instance is about to be deleted")
		return
	_update_is_selectable_uniform()
	# Active structure have changed, remove highlight if needed
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	if structure_context.nano_structure.int_guid == _workspace_context.workspace.active_structure_int_guid:
		_material.set_hovered(false)


func handle_hover_structure_changed(in_toplevel_hovered_structure_context: StructureContext,
			in_hovered_structure_context: StructureContext, in_atom_id: int, _in_bond_id: int,
			_in_spring_id: int) -> void:
	var workspace: Workspace = _workspace_context.workspace
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	var is_hovered: bool = false
	if in_toplevel_hovered_structure_context != null:
		is_hovered = (in_toplevel_hovered_structure_context == structure_context) \
				or workspace.is_a_ancestor_of_b(in_toplevel_hovered_structure_context.nano_structure, structure_context.nano_structure)
	if is_hovered and in_hovered_structure_context.nano_structure.int_guid == workspace.active_structure_int_guid:
		is_hovered = false
	var hovered_atom_id: int = -1 if in_hovered_structure_context != structure_context else in_atom_id
	if hovered_atom_id != _hovered_atom_id:
		_set_hovered_atom_id(hovered_atom_id)
	_material.set_hovered(is_hovered)


func refresh_bonds_visibility(_in_bonds_ids: PackedInt32Array) -> void:
	return


func hide_bond_rendering() -> void:
	return


func show_bond_rendering() -> void:
	return


func apply_theme(in_theme: Theme3D) -> void:
	var old_material: ShaderMaterial = _material
	var new_mesh: Mesh = in_theme.create_single_atom_ball_mesh()
	_material = in_theme.create_single_atom_ball_material()
	_segmented_multimesh.set_mesh_override(new_mesh)
	_segmented_multimesh.set_material_override(_material)
	_material.copy_state_from(old_material)


func saturate() -> void:
	_material.saturate()


func desaturate() -> void:
	_material.desaturate()


func create_state_snapshot() -> Dictionary:
	assert(is_instance_valid(_workspace_context))
	var snapshot: Dictionary = {}
	snapshot["_structure_id"] = _structure_id
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_segmented_multimesh.snapshot"] = _segmented_multimesh.create_state_snapshot()
	snapshot["_structure_id"] = _structure_id
	snapshot["_hovered_atom_id"] = _hovered_atom_id
	snapshot["_highlighted_atoms"] = _highlighted_atoms.duplicate(true)
	snapshot["_material.snapshot"] = _material.create_state_snapshot()
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_structure_id = in_snapshot["_structure_id"]
	_workspace_context = in_snapshot["_workspace_context"]
	_segmented_multimesh.apply_state_snapshot(in_snapshot["_segmented_multimesh.snapshot"])
	_segmented_multimesh.set_material_override(_material)
	_structure_id = in_snapshot["_structure_id"]
	_hovered_atom_id = in_snapshot["_hovered_atom_id"]
	_highlighted_atoms = in_snapshot["_highlighted_atoms"].duplicate(true)
	_material.apply_state_snapshot(in_snapshot["_material.snapshot"])
	refresh_atoms_sizes()
