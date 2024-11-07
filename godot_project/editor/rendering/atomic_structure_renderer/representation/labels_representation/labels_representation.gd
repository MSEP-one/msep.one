class_name LabelsRepresentation extends Representation


const BASE_SCALE = 1.0;
const NMB_OF_KNOWN_ATOMS = 118
const SCALE_FACTOR = 4.0 # tweak to modify relation relation between atom size and label size

const HydrogensMaterial: ShaderMaterial = preload("res://editor/rendering/atomic_structure_renderer/representation/labels_representation/assets/labels_representation_material.tres")

const UNIFORM_SCALE = &"scale"

var _atom_number_to_atlas_id_map : Dictionary = {
	# (how to map atom number to concrete section of labels_representation_atlas.png)
	# 1 : 0,
	# 2 : 1,
	# (...)
}
var _highlighted_atoms: Dictionary = {
	# atom_id<int> : is_highlighted<bool>
}
var _structure_id: int
var _workspace_context: WorkspaceContext
var _segmented_multimesh: SegmentedMultimesh

var _scale_factor: float = 1.0

# need unique material as a workaround. Without it preview is also using the same materials but 
# have different camera and it would use wrong uniforms (from default view-port rendering)
var _material: LabelMaterial = HydrogensMaterial.duplicate()


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_segmented_multimesh = $ProximitySegmentedMultimesh as SegmentedMultimesh
		_segmented_multimesh.set_material_override(_material)
		for atlas_idx in range(NMB_OF_KNOWN_ATOMS + 1):
			var atomic_nmb: int = atlas_idx + 1
			_atom_number_to_atlas_id_map[atomic_nmb] = atlas_idx


func is_built() -> bool:
	return _structure_id != Workspace.INVALID_STRUCTURE_ID


func build(in_structure_context: StructureContext) -> void:
	assert(is_instance_valid(in_structure_context.nano_structure))
	_structure_id = in_structure_context.get_int_guid()
	_workspace_context = in_structure_context.workspace_context
	var related_nanostructure: NanoStructure = in_structure_context.nano_structure
	clear()
	
	_segmented_multimesh.set_material_override(_material)
	
	refresh_atoms_sizes()
	
	var aabb: AABB = AABB()
	var atoms_ids: PackedInt32Array = related_nanostructure.get_valid_atoms()
	if atoms_ids.size() < 1:
		_segmented_multimesh.bake()
		return
	
	aabb.position = related_nanostructure.atom_get_position(atoms_ids[0])
	var atom_state := Representation.InstanceState.new()
	for atom_id in atoms_ids:
		var atom_position: Vector3 = related_nanostructure.atom_get_position(atom_id)
		var atom_atomic_number: int = related_nanostructure.atom_get_atomic_number(atom_id)
		var data: ElementData = PeriodicTable.get_by_atomic_number(atom_atomic_number)
		var additional_color: Color = data.noise_color
		additional_color.a = data.noise_atlas_id
		atom_state.is_visible = not related_nanostructure.is_atom_hidden_by_user(atom_id)
		atom_state.is_locked = related_nanostructure.atom_is_locked(atom_id)
		atom_state.is_selected = in_structure_context.is_atom_selected(atom_id)
		if atom_state.is_selected:
			_highlighted_atoms[atom_id] = true
		atom_state.is_hydrogen = related_nanostructure.atom_is_hydrogen(atom_id)
		var atom_transform: Transform3D = Transform3D()
		atom_transform.origin = atom_position
		var color: Color = data.color
		color.g = _atom_number_to_atlas_id_map[data.number]
		color.b = data.render_radius
		color.a = atom_state.to_float()
		
		_segmented_multimesh.add_particle(atom_id, atom_transform, color, additional_color)
		aabb = aabb.expand(atom_position)
	_segmented_multimesh.bake()


func add_atoms(in_atoms_ids: PackedInt32Array) -> void:
	for atom_id in in_atoms_ids:
		_add_atom(atom_id)
	_segmented_multimesh.rebuild_if_needed()


func remove_atoms(in_atoms_ids: PackedInt32Array) -> void:
	for atom_id in in_atoms_ids:
		_segmented_multimesh.queue_particle_removal(atom_id)
		_highlighted_atoms.erase(atom_id)
	_segmented_multimesh.apply_queued_removals()


func _add_atom(in_atom_id: int) -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	var related_nanostructure: NanoStructure = structure_context.nano_structure
	var atom_position: Vector3 = related_nanostructure.atom_get_position(in_atom_id)
	var atom_atomic_number: int = related_nanostructure.atom_get_atomic_number(in_atom_id)
	var data: ElementData = PeriodicTable.get_by_atomic_number(atom_atomic_number)
	var atom_transform: Transform3D = Transform3D()
	atom_transform.origin = atom_position
	var color := Color()
	var atom_state := Representation.InstanceState.new(color.a)
	atom_state.is_visible = not related_nanostructure.is_atom_hidden_by_user(in_atom_id)
	atom_state.is_locked = related_nanostructure.atom_is_locked(in_atom_id)
	atom_state.is_selected = structure_context.is_atom_selected(in_atom_id)
	if atom_state.is_selected:
		_highlighted_atoms[in_atom_id] = true
	atom_state.is_hydrogen = related_nanostructure.atom_is_hydrogen(in_atom_id)
	color.g = _atom_number_to_atlas_id_map[data.number]
	color.b = data.render_radius
	color.a = atom_state.to_float()
	_segmented_multimesh.add_particle(in_atom_id, atom_transform, color, data.noise_color)


func refresh_atoms_positions(in_atoms_ids: PackedInt32Array) -> void:
	var nano_struct: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id in in_atoms_ids:
		var atom_position: Vector3 = nano_struct.atom_get_position(atom_id)
		_segmented_multimesh.update_particle_position(atom_id, atom_position)
	
	_segmented_multimesh.apply_queued_removals()
	_segmented_multimesh.rebuild_if_needed()


func refresh_atoms_locking(in_atoms_ids: PackedInt32Array) -> void:
	for atom_id: int in in_atoms_ids:
		_refresh_atom(atom_id)


func refresh_atoms_atomic_number(in_atoms_and_atomic_numbers: Array[Vector2i]) -> void:
	for atom_element_pair in in_atoms_and_atomic_numbers:
		var atom_id: int = atom_element_pair[0]
		_refresh_atom(atom_id)


func refresh_atoms_sizes() -> void:
	if not is_built():
		return
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	var scale_factor: float = Representation.get_atom_scale_factor(related_nanostructure.get_representation_settings())
	_apply_scale_factor(scale_factor)


func refresh_atoms_visibility(in_atoms_ids: PackedInt32Array) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id: int in in_atoms_ids:
		var color: Color = _segmented_multimesh.get_particle_color(atom_id)
		var additional_color: Color = _segmented_multimesh.get_particle_additional_data(atom_id)
		var atom_state := Representation.InstanceState.new(color.a)
		atom_state.is_visible = not related_nanostructure.is_atom_hidden_by_user(atom_id)
		color.a = atom_state.to_float()
		_segmented_multimesh.update_particle_color(atom_id, color, additional_color)


func refresh_bonds_visibility(_in_bonds_ids: PackedInt32Array) -> void:
	return


func clear() -> void:
	_segmented_multimesh.prepare()


func show() -> void:
	_segmented_multimesh.show()
	refresh_atoms_sizes()


func _apply_scale_factor(new_scale_factor: float) -> void:
	_material.set_scale_factor(new_scale_factor)
	_scale_factor = new_scale_factor


func hide() -> void:
	_segmented_multimesh.hide()


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


func refresh_bond_influence(_in_partially_selected_bonds: PackedInt32Array) -> void:
	return


func set_material_overlay(in_material: Material) -> void:
	_segmented_multimesh.set_material_overlay(in_material)


func highlight_atoms(in_atoms_ids: PackedInt32Array, _new_partially_influenced_bonds: PackedInt32Array,
			_in_bonds_released_from_partial_influence: PackedInt32Array) -> void:
	for atom_id in in_atoms_ids:
		if _highlighted_atoms.get(atom_id, false):
			continue
		_highlighted_atoms[atom_id] = true
		_refresh_atom(atom_id)


func lowlight_atoms(in_atoms_ids: PackedInt32Array, 
			_in_bonds_released_from_partial_influence: PackedInt32Array,
			_new_partially_influenced_bonds: PackedInt32Array) -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id in in_atoms_ids:
		assert(related_nanostructure.is_atom_valid(atom_id), "atempt to lowlight a non existing atom")
		if not _highlighted_atoms.get(atom_id, false):
			continue
		_highlighted_atoms[atom_id] = false
		_refresh_atom(atom_id)


func _refresh_atom(in_atom_id: int, _in_scale_factor: float = BASE_SCALE) -> void:
	assert(_segmented_multimesh.is_external_id_known(in_atom_id), "Atempt to refresh non existing atom. Ensure
		this operation is performed at right time in the context of NanoStructure.[start/end]_edit() call.")
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	var atom_position: Vector3 = related_nanostructure.atom_get_position(in_atom_id)
	var atom_atomic_number: int = related_nanostructure.atom_get_atomic_number(in_atom_id)
	var data: ElementData = PeriodicTable.get_by_atomic_number(atom_atomic_number)
	var atom_transform: Transform3D = Transform3D()
	atom_transform.origin = atom_position
	var atom_state := Representation.InstanceState.new()
	atom_state.is_selected = _highlighted_atoms.get(in_atom_id, false)
	atom_state.is_visible = not related_nanostructure.is_atom_hidden_by_user(in_atom_id)
	atom_state.is_locked = related_nanostructure.atom_is_locked(in_atom_id)
	atom_state.is_hydrogen = related_nanostructure.atom_is_hydrogen(in_atom_id)
	var atom_color: Color = data.color
	atom_color.g = _atom_number_to_atlas_id_map[data.number]
	atom_color.b = data.render_radius
	atom_color.a = atom_state.to_float()
	_segmented_multimesh.update_particle(in_atom_id, atom_transform, atom_color)


func set_atom_selection_position_delta(in_movement_delta: Vector3) -> void:
	_material.update_selection_delta(in_movement_delta)


func rotate_atom_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	_material.update_gizmo(in_point, in_rotation_to_apply)


func update(in_delta: float) -> void:
	_segmented_multimesh.update(in_delta)
	
	var camera: Camera3D = get_viewport().get_camera_3d()
	var to_local: Quaternion = Quaternion(self.global_basis.inverse())
	var cam_forward: Vector3 = camera.global_transform.basis.z
	var cam_up: Vector3 = to_local * camera.global_transform.basis.y
	var cam_right: Vector3 = to_local * camera.global_transform.basis.x
	_material.update_camera(cam_forward, cam_up, cam_right, camera.size)


func set_transparency(_in_transparency: float) -> void:
	# Do Nothing
	return


func hydrogens_rendering_off() -> void:
	_material.disable_hydrogen_rendering()
	refresh_atoms_sizes()


func hydrogens_rendering_on() -> void:
	_material.enable_hydrogen_rendering()
	refresh_atoms_sizes()


func refresh_all() -> void:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id)
	for atom_id: int in related_nanostructure.get_valid_atoms():
		_refresh_atom(atom_id)


func handle_hover_structure_changed(_in_toplevel_hovered_structure_context: StructureContext,
			_in_hovered_structure_context: StructureContext, _in_atom_id: int, _in_bond_id: int,
			_in_spring_id: int) -> void:
	return


func refresh_atoms_color(_in_atoms: PackedInt32Array) -> void:
	return


func hide_bond_rendering() -> void:
	return


func show_bond_rendering() -> void:
	return


func handle_editable_structures_changed(_in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	return


func apply_theme(in_theme: Theme3D) -> void:
	var old_material: ShaderMaterial = _segmented_multimesh.get_material_override()
	var new_material: ShaderMaterial = in_theme.create_label_material()
	var scale: float = old_material.get_shader_parameter(UNIFORM_SCALE)
	new_material.set_scale_factor(scale)
	_segmented_multimesh.set_material_override(new_material)
	_material = new_material


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_structure_id"] = _structure_id
	snapshot["_highlighted_atoms"] = _highlighted_atoms.duplicate(true)
	snapshot["_atom_number_to_atlas_id_map"] = _atom_number_to_atlas_id_map.duplicate(true)
	snapshot["_scale_factor"] = _scale_factor
	snapshot["_segmented_multimesh.snapshot"] = _segmented_multimesh.create_state_snapshot()
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_workspace_context = in_snapshot["_workspace_context"]
	_structure_id = in_snapshot["_structure_id"]
	_highlighted_atoms = in_snapshot["_highlighted_atoms"].duplicate(true)
	_atom_number_to_atlas_id_map = in_snapshot["_atom_number_to_atlas_id_map"].duplicate(true)
	_scale_factor = in_snapshot["_scale_factor"]
	_segmented_multimesh.apply_state_snapshot(in_snapshot["_segmented_multimesh.snapshot"])
	refresh_atoms_sizes() 
