class_name SphereRepresentation extends Representation

signal rendering_ready

const BASE_SCALE = 1.0;
const HIGHLIGHT_FACTOR = 3.0;

const MultimeshAtomMaterial: SphereMaterial = preload("res://editor/rendering/atomic_structure_renderer/representation/sphere_representation/assets/multimesh_atom_material.tres")

@onready var _segmented_multimesh: SegmentedMultimesh = $SegmentedMultiMesh

var _structure_id: int
var _material: SphereMaterial
var _shader_scale: float = 0.0
var _hovered_atom_id: int = -1
var _workspace_context: WorkspaceContext
var _highlighted_atoms: Dictionary = {
	# atom_id<int> : is_highlighted<bool>
}


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		# need unique material as a workaround. Without it preview is also using the same materials but
		# have different camera and it would use wrong uniforms (from default view-port rendering)
		_material = MultimeshAtomMaterial.duplicate()
		_segmented_multimesh = $SegmentedMultiMesh
		_segmented_multimesh.set_material_override(_material)


func build(in_structure_context: StructureContext) -> void:
	assert(is_instance_valid(in_structure_context.nano_structure))
	_workspace_context = in_structure_context.workspace_context
	_structure_id = in_structure_context.get_int_guid()
	var related_nanostructure: AtomicStructure = in_structure_context.nano_structure as AtomicStructure
	
	clear()
	
	var representation_settings: RepresentationSettings = related_nanostructure.get_representation_settings()
	var scale_factor: float = Representation.get_atom_scale_factor(representation_settings)
	_apply_scale_factor(scale_factor)

	var aabb: AABB = AABB()
	var atoms_ids: PackedInt32Array = related_nanostructure.get_valid_atoms()
	if atoms_ids.size() < 1:
		_segmented_multimesh.bake()
		return
	
	var selected_atoms: PackedInt32Array = in_structure_context.get_selected_atoms()
	var locked_atoms: PackedInt32Array = related_nanostructure.get_locked_atoms()
	var atom_state := Representation.InstanceState.new()
	aabb.position = related_nanostructure.atom_get_position(atoms_ids[0])
	for atom_id in atoms_ids:
		var atom_position: Vector3 = related_nanostructure.atom_get_position(atom_id)
		var atom_atomic_number: int = related_nanostructure.atom_get_atomic_number(atom_id)
		var data: ElementData = PeriodicTable.get_by_atomic_number(atom_atomic_number)
		var additional_color: Color = data.noise_color
		additional_color.a = data.noise_atlas_id
		var atom_radius: float = Representation.get_atom_radius(data, related_nanostructure.get_representation_settings())
		var atom_scale: Vector3 = Vector3.ONE * atom_radius * BASE_SCALE
		var atom_transform: Transform3D = Transform3D()
		var atom_color: Color = data.color
		if related_nanostructure.has_color_override(atom_id):
			atom_color = related_nanostructure.get_color_override(atom_id)
		atom_state.is_visible = not related_nanostructure.is_atom_hidden_by_user(atom_id)
		atom_state.is_selected = atom_id in selected_atoms
		atom_state.is_locked = atom_id in locked_atoms
		atom_color.a = atom_state.to_float()
		atom_transform = atom_transform.scaled_local(atom_scale)
		atom_transform.origin = atom_position
		_segmented_multimesh.add_particle(atom_id, atom_transform, atom_color, additional_color)
		aabb = aabb.expand(atom_position)
	_segmented_multimesh.bake()
	
	rendering_ready.emit()
	
	highlight_atoms(in_structure_context.get_selected_atoms())
	apply_theme(representation_settings.get_theme())


func handle_editable_structures_changed(_in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	_update_is_selectable_uniform()


func handle_hover_structure_changed(in_toplevel_hovered_structure_context: StructureContext,
			in_hovered_structure_context: StructureContext, in_atom_id: int, _in_bond_id: int,
			_in_spring_id: int) -> void:
	var workspace: Workspace = _workspace_context.workspace
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	var current_context: StructureContext = _workspace_context.get_current_structure_context()
	var is_hovered: bool = false
	var did_hover_a_group: bool = in_toplevel_hovered_structure_context != null
	var is_context_edited_by_user: bool = current_context == structure_context
	if did_hover_a_group and not is_context_edited_by_user:
		var is_entire_group_hovered: bool = (
				in_toplevel_hovered_structure_context == structure_context
				or workspace.is_a_ancestor_of_b(
					in_toplevel_hovered_structure_context.nano_structure,
					structure_context.nano_structure)
				)
		if is_entire_group_hovered:
			is_hovered = true
	var hovered_atom_id: int = -1 if in_hovered_structure_context != structure_context else in_atom_id
	if hovered_atom_id != _hovered_atom_id:
		_set_hovered_atom_id(hovered_atom_id)
	_material.set_hovered(is_hovered)


func _set_hovered_atom_id(in_hovered_atom_id: int) -> void:
	if in_hovered_atom_id == _hovered_atom_id:
		return
	var prev_hovered_atom_id: int = _hovered_atom_id
	_hovered_atom_id = in_hovered_atom_id
	if _segmented_multimesh.is_external_id_known(prev_hovered_atom_id):
		_refresh_atom(prev_hovered_atom_id)
	if _segmented_multimesh.is_external_id_known(_hovered_atom_id):
		_refresh_atom(_hovered_atom_id)


func _update_is_selectable_uniform() -> void:
	if not _workspace_context.has_nano_structure_context_id(_structure_id):
		assert(ScriptUtils.is_queued_for_deletion_reqursive(self), "structure deleted, this rendering instance is about to be deleted")
		return
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	var is_editable: bool = structure_context.is_editable()
	_material.set_selectable(is_editable)


func add_atoms(in_atoms_ids: PackedInt32Array) -> void:
	for atom_id in in_atoms_ids:
		_add_atom(atom_id)
	_segmented_multimesh.rebuild_if_needed()


func remove_atoms(in_atoms_ids: PackedInt32Array) -> void:
	for atom_id in in_atoms_ids:
		_highlighted_atoms.erase(atom_id)
		_segmented_multimesh.queue_particle_removal(atom_id)
	_segmented_multimesh.apply_queued_removals()


func _add_atom(in_atom_id: int) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	var atom_position: Vector3 = related_nanostructure.atom_get_position(in_atom_id)
	var atom_atomic_number: int = related_nanostructure.atom_get_atomic_number(in_atom_id)
	var data: ElementData = PeriodicTable.get_by_atomic_number(atom_atomic_number)
	var additional_color: Color = data.noise_color
	additional_color.a = data.noise_atlas_id
	var atom_radius: float = Representation.get_atom_radius(data, related_nanostructure.get_representation_settings())
	var atom_scale: Vector3 = Vector3.ONE * atom_radius * BASE_SCALE
	var atom_transform: Transform3D = Transform3D()
	var atom_color: Color = data.color
	atom_color.a = Representation.InstanceState.new().to_float()
	atom_transform = atom_transform.scaled_local(atom_scale)
	atom_transform.origin = atom_position
	_segmented_multimesh.add_particle(in_atom_id, atom_transform, atom_color, additional_color)


func refresh_atoms_positions(in_atoms_ids: PackedInt32Array) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id in in_atoms_ids:
		var atom_position: Vector3 = related_nanostructure.atom_get_position(atom_id)
		_segmented_multimesh.update_particle_position(atom_id, atom_position)
	_segmented_multimesh.apply_queued_removals()
	_segmented_multimesh.rebuild_if_needed()


func refresh_atoms_locking(_in_atoms_ids: PackedInt32Array) -> void:
	return


func refresh_atoms_atomic_number(in_atoms_and_atomic_numbers: Array[Vector2i]) -> void:
	for atom_element_pair in in_atoms_and_atomic_numbers:
		var atom_id: int = atom_element_pair[0]
		_refresh_atom(atom_id)


func refresh_atoms_sizes(in_update_atoms_radii: bool = false) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	var scale_factor: float = Representation.get_atom_scale_factor(related_nanostructure.get_representation_settings())
	_apply_scale_factor(scale_factor)
	
	if in_update_atoms_radii:
		# The actual atom radius is stored in each particle transform, we need to modify all of them
		# when the source radius visualization (physical or VDW) changes.
		# TODO: This update could be avoided if we can store both radii in the atom data and toggle
		# between one or the other with a shader instance uniform, like we do for the scale factor
		refresh_all()


# Refresh the atom color.
# This method does not change the hovered / highlight status, use _refresh_atom()
# to update the complete state.
func refresh_atoms_color(in_atoms: PackedInt32Array) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id: int in in_atoms:
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


func refresh_bonds_visibility(_in_bonds_ids: PackedInt32Array) -> void:
	return


func refresh_all() -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id: int in related_nanostructure.get_valid_atoms():
		_refresh_atom(atom_id)


func clear() -> void:
	_segmented_multimesh.prepare()
	_highlighted_atoms.clear()


func show() -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	_segmented_multimesh.set_material_override(_material)
	
	_segmented_multimesh.show()
	var scale_factor: float = Representation.get_atom_scale_factor(related_nanostructure.get_representation_settings())
	_apply_scale_factor(scale_factor)
	_update_is_selectable_uniform()


func _apply_scale_factor(new_scale_factor: float) -> void:
	_shader_scale = new_scale_factor
	_material.set_scale_factor(new_scale_factor)


func hide() -> void:
	_segmented_multimesh.hide()


func hydrogens_rendering_off() -> void:
	_material.disable_hydrogen_rendering()


func hydrogens_rendering_on() -> void:
	_material.enable_hydrogen_rendering()


func add_bonds(_new_bonds: PackedInt32Array) -> void:
	return


func remove_bonds(_new_bonds: PackedInt32Array) -> void:
	return


func bonds_changed(_changed_bonds: PackedInt32Array) -> void:
	return


func highlight_bonds(_in_bonds_ids: PackedInt32Array) -> void:
	return


func lowlight_bonds(_in_bonds_ids: PackedInt32Array) -> void:
	return
	
	
func set_material_overlay(in_material: Material) -> void:
	_segmented_multimesh.set_material_overlay(in_material)


func highlight_atoms(in_atoms_ids: PackedInt32Array,
			_new_partially_influenced_bonds: PackedInt32Array = PackedInt32Array(),
			_in_bonds_released_from_partial_influence: PackedInt32Array = PackedInt32Array()) -> void:
	for atom_id in in_atoms_ids:
		if _highlighted_atoms.get(atom_id, false):
			continue
		_highlighted_atoms[atom_id] = true
		_refresh_atom(atom_id)


func lowlight_atoms(in_atoms_ids: PackedInt32Array, 
			_in_bonds_released_from_partial_influence: PackedInt32Array = PackedInt32Array(),
			_new_partially_influenced_bonds: PackedInt32Array = PackedInt32Array()) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id in in_atoms_ids:
		assert(related_nanostructure.is_atom_valid(atom_id), "atempt to lowlight a non existing atom")
		if not _highlighted_atoms.get(atom_id, false):
			continue
		_highlighted_atoms[atom_id] = false
		_refresh_atom(atom_id)


func _refresh_atom(in_atom_id: int, scale_factor: float = BASE_SCALE) -> void:
	assert(_segmented_multimesh.is_external_id_known(in_atom_id), "Atempt to refresh non existing atom. Ensure
		this operation is performed at right time in the context of NanoStructure.[start/end]_edit() call. ")
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	var atom_position: Vector3 = related_nanostructure.atom_get_position(in_atom_id)
	var atom_atomic_number: int = related_nanostructure.atom_get_atomic_number(in_atom_id)
	var data: ElementData = PeriodicTable.get_by_atomic_number(atom_atomic_number)
	var atom_radius: float = Representation.get_atom_radius(data, related_nanostructure.get_representation_settings())
	var atom_scale: Vector3 = Vector3.ONE * atom_radius * scale_factor
	atom_scale *= 1.0 if related_nanostructure.is_atom_valid(in_atom_id) else 0.0
	var atom_color: Color
	if related_nanostructure.has_color_override(in_atom_id):
		atom_color = related_nanostructure.get_color_override(in_atom_id)
	else:
		atom_color = data.color
	var atom_state := Representation.InstanceState.new()
	atom_state.is_visible = not related_nanostructure.is_atom_hidden_by_user(in_atom_id)
	atom_state.is_hovered = in_atom_id == _hovered_atom_id
	atom_state.is_selected = _highlighted_atoms.get(in_atom_id, false)
	atom_color.a = atom_state.to_float()
	var highlight_factor: float = 1.0 + float(atom_state.is_selected) + float(atom_state.is_hovered)
	var additional_color: Color = data.noise_color * max(1.0, highlight_factor * 0.5)
	additional_color.a = data.noise_atlas_id
	var atom_transform: Transform3D = Transform3D()
	atom_transform = atom_transform.scaled_local(atom_scale)
	atom_transform.origin = atom_position
	_segmented_multimesh.update_particle_transform_and_color(in_atom_id, atom_transform, atom_color, additional_color)


func _update_multimesh_if_needed() -> void:
	if _segmented_multimesh.update_segments_on_movement:
		_segmented_multimesh.rebuild_if_needed()
		_segmented_multimesh.apply_queued_removals()


func set_atom_selection_position_delta(in_movement_delta: Vector3) -> void:
	_material.update_selection_delta(in_movement_delta)
	_update_multimesh_if_needed()


func rotate_atom_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	_material.update_gizmo(in_point, in_rotation_to_apply)
	_update_multimesh_if_needed()


func update(_delta: float) -> void:
	var camera3d: Camera3D = get_viewport().get_camera_3d()
	var to_local: Quaternion = Quaternion(self.global_basis.inverse())
	var camera_up: Vector3 = to_local * camera3d.global_transform.basis.y
	var camera_right: Vector3 = to_local * camera3d.global_transform.basis.x
	_material.update_camera(camera_up, camera_right)


func set_transparency(in_transparency: float) -> void:
	_segmented_multimesh.set_transparency(in_transparency)


func hide_bond_rendering() -> void:
	return


func show_bond_rendering() -> void:
	return


func set_partially_selected_bonds(_in_partially_selected_bonds: PackedInt32Array) -> void:
	return


func apply_theme(in_theme: Theme3D) -> void:
	var old_material: ShaderMaterial = _material
	var new_mesh: Mesh = in_theme.create_ball_mesh()
	_material = in_theme.create_ball_material()
	_segmented_multimesh.set_mesh_override(new_mesh)
	_segmented_multimesh.set_material_override(_material)
	_material.set_scale_factor(_shader_scale)
	_material.copy_state_from(old_material)


func create_state_snapshot() -> Dictionary:
	assert(is_instance_valid(_workspace_context))
	var snapshot: Dictionary = {}
	snapshot["_structure_id"] = _structure_id
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_segmented_multimesh.snapshot"] = _segmented_multimesh.create_state_snapshot()
	snapshot["_structure_id"] = _structure_id
	snapshot["_shader_scale"] = _shader_scale
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
	_shader_scale = in_snapshot["_shader_scale"]
	_hovered_atom_id = in_snapshot["_hovered_atom_id"]
	_highlighted_atoms = in_snapshot["_highlighted_atoms"].duplicate(true)
	_material.apply_state_snapshot(in_snapshot["_material.snapshot"])
	refresh_atoms_sizes()
