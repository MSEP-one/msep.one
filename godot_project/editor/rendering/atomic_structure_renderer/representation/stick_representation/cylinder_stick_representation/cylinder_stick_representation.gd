class_name CylinderStickRepresentation extends StickRepresentation

const INSTANCE_UNIFORM_BASE_SCALE: StringName = StringName("base_scale")
const UNIFORM_ATOM_SCALE: StringName = StringName("atom_scale")

# Base atom radius on which we are not modifying stick width
const _STICK_VISUAL_RADIUS = 0.045
const _BASE_RADIUS_FOR_STICK_WIDTH_FACTOR = (1.0 / _STICK_VISUAL_RADIUS) * 2.2

# After multiplying atom radius by this value we will get bond with width aproximatelly equal to atom radius,
# this value has been found out experimentally and we might need to adjust it if we will ever modify the
# mesh for bonds in a significant way
const _BOND_TO_ATOM_WIDTH = 80.0

# we want single bonds to have 1/3 visual width of the smaller atom to which it's connected to
const _SINGLE_BOND_RADIUS_FACTOR = _BOND_TO_ATOM_WIDTH * 0.33 

# Note: Currently all three cylinder models, have exactly the same radius
const CYLINDER_MODEL_RADIUS = 0.023054

const CylinderMaterial: CylinderStickMaterial = preload("res://editor/rendering/atomic_structure_renderer/representation/stick_representation/cylinder_stick_representation/assets/bond_cylinder_material.tres")


func _initialize() -> void:
	pass


func build(in_structure_context: StructureContext) -> void:
	super.build(in_structure_context)
	_ensure_material_configured()


func show() -> void:
	super.show()
	_ensure_material_configured()


func hydrogens_rendering_off() -> void:
	_material_bond_1.disable_hydrogen_rendering()
	_material_bond_2.disable_hydrogen_rendering()
	_material_bond_3.disable_hydrogen_rendering()
	_ensure_material_configured()


func hydrogens_rendering_on() -> void:
	_material_bond_1.enable_hydrogen_rendering()
	_material_bond_2.enable_hydrogen_rendering()
	_material_bond_3.enable_hydrogen_rendering()
	_ensure_material_configured()


func _ensure_material_configured() -> void:
	_single_stick_multimesh.set_material_override(_material_bond_1)
	_double_stick_multimesh.set_material_override(_material_bond_2)
	_tripple_stick_multimesh.set_material_override(_material_bond_3)
	_single_stick_multimesh.set_material_instance_uniform(INSTANCE_UNIFORM_BASE_SCALE, 1.0)
	_double_stick_multimesh.set_material_instance_uniform(INSTANCE_UNIFORM_BASE_SCALE, 0.75)
	_tripple_stick_multimesh.set_material_instance_uniform(INSTANCE_UNIFORM_BASE_SCALE, 0.55)
	refresh_atoms_sizes()
	_update_is_selectable_uniform()
	_material_bond_1.set_gizmo_rotation(Basis())
	_material_bond_2.set_gizmo_rotation(Basis())
	_material_bond_3.set_gizmo_rotation(Basis())


func _calculate_bond_transform(in_bond: Vector3i) -> Transform3D:
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id)
	var bond_order: int = in_bond.z
	var first_atom_id: int = in_bond.x
	var second_atom_id: int = in_bond.y
	var first_atom_position: Vector3 = related_nanostructure.atom_get_position(first_atom_id)
	var second_atom_position: Vector3 = related_nanostructure.atom_get_position(second_atom_id)
	var dir_from_first_to_second: Vector3 = first_atom_position.direction_to(second_atom_position)
	var up_vector: Vector3 = StickRepresentation._calc_up_vect_for_single_bond(dir_from_first_to_second) if bond_order == 1 else \
			StickRepresentation._calc_up_vector_for_higher_bond(first_atom_id, second_atom_id, first_atom_position,
					second_atom_position, related_nanostructure)
	var _particle_transform: Transform3D = calculate_transform_for_bond(first_atom_position,
			second_atom_position, up_vector)
	return _particle_transform


static func calc_bond_width_factor(in_bond_order: int, in_smaller_atom_radius: float) -> float:
	if in_bond_order == 1:
		return in_smaller_atom_radius * _SINGLE_BOND_RADIUS_FACTOR
	else:
		var width: float = in_smaller_atom_radius * _BASE_RADIUS_FOR_STICK_WIDTH_FACTOR
		return width


static func calc_bond_visual_radius(in_bond_order: int, in_smaller_atom_radius: float) -> float:
	return CYLINDER_MODEL_RADIUS * calc_bond_width_factor(in_bond_order, in_smaller_atom_radius)


# *
# | Shader related, most probably can be moved to StickRepresentation when
# v CapsuleStickRepresentation supports GPU movement
func _apply_scale_factor(new_scale_factor: float) -> void:
	assert(_material_bond_1 is CylinderStickMaterial)
	assert(_material_bond_2 is CylinderStickMaterial)
	assert(_material_bond_3 is CylinderStickMaterial)
	_material_bond_1.set_atom_scale(new_scale_factor)
	_material_bond_2.set_atom_scale(new_scale_factor)
	_material_bond_3.set_atom_scale(new_scale_factor)


func rotate_atom_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	_material_bond_1.set_gizmo_origin(in_point)
	_material_bond_2.set_gizmo_origin(in_point)
	_material_bond_3.set_gizmo_origin(in_point)
	_material_bond_1.set_gizmo_rotation(in_rotation_to_apply)
	_material_bond_2.set_gizmo_rotation(in_rotation_to_apply)
	_material_bond_3.set_gizmo_rotation(in_rotation_to_apply)
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id)
	for bond_id: int in _current_bond_partial_selection:
		var bond: Vector3i = related_nanostructure.get_bond(bond_id)
		var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
		var related_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[particle_id.bond_order]
		var bond_transform: Transform3D = _calculate_partial_selection_transform(bond, in_point, in_rotation_to_apply)
		related_multimesh.update_particle_transform(particle_id.bond_id, bond_transform)
	update_segments_if_needed()


func set_atom_selection_position_delta(in_movement_delta: Vector3) -> void:
	_material_bond_1.set_selection_delta(in_movement_delta)
	_material_bond_2.set_selection_delta(in_movement_delta)
	_material_bond_3.set_selection_delta(in_movement_delta)
	var related_nanostructure: NanoStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id)
	for bond_id: int in _current_bond_partial_selection:
		var bond: Vector3i = related_nanostructure.get_bond(bond_id)
		var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
		var related_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[particle_id.bond_order]
		var bond_transform: Transform3D = _calculate_partial_selection_translation(bond, in_movement_delta)
		related_multimesh.update_particle_transform(particle_id.bond_id, bond_transform)
	update_segments_if_needed()



func apply_theme(in_theme: Theme3D) -> void:
	var old_order_1_material: ShaderMaterial = _material_bond_1
	var old_order_2_material: ShaderMaterial = _material_bond_2
	var old_order_3_material: ShaderMaterial = _material_bond_3
	
	_material_bond_1 = in_theme.create_bond_order_1_material()
	_material_bond_2 = in_theme.create_bond_order_2_material()
	_material_bond_3 = in_theme.create_bond_order_3_material()
	
	assert(_material_bond_1 is CylinderStickMaterial)
	assert(_material_bond_2 is CylinderStickMaterial)
	assert(_material_bond_3 is CylinderStickMaterial)
	
	_single_stick_multimesh.set_mesh_override(in_theme.create_bond_order_1_mesh())
	_single_stick_multimesh.set_material_override(_material_bond_1)
	_double_stick_multimesh.set_mesh_override(in_theme.create_bond_order_2_mesh())
	_double_stick_multimesh.set_material_override(_material_bond_2)
	_tripple_stick_multimesh.set_mesh_override(in_theme.create_bond_order_3_mesh())
	_tripple_stick_multimesh.set_material_override(_material_bond_3)
	
	_material_bond_1.copy_state_from(old_order_1_material)
	_material_bond_2.copy_state_from(old_order_2_material)
	_material_bond_3.copy_state_from(old_order_3_material)
