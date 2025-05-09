class_name CapsuleStickRepresentation extends StickRepresentation

static var CapsuleMaterial: ShaderMaterial = load("res://editor/rendering/atomic_structure_renderer/representation/stick_representation/capsule_stick_representation/assets/capsule_stick_material.tres")

const _SHADER_SINGLE_BOND_MESH_CAPS_STARTS_AT_LOCAL_Z = 0.44
const _SHADER_DOUBLE_BOND_MESH_CAPS_STARTS_AT_LOCAL_Z = 0.44
const _SHADER_TRIPLE_BOND_MESH_CAPS_STARTS_AT_LOCAL_Z = 0.44

# Multiply with the atom radius to get the bond width (cf. CylinderStickRepresentation)
# Value obtained using the formula:
# (CYLINDER_MODEL_RADIUS / CAPSULE_MODEL_RADIUS) * CYLINDER_BOND_TO_ATOM_WIDTH
const _BOND_TO_ATOM_WIDTH = 55.2
const CAPSULE_MODEL_RADIUS: float = 0.033

var _capsule_material: CapsuleStickMaterial = CapsuleMaterial.duplicate()

func _initialize() -> void:
	pass


func get_materials() -> Array[ShaderMaterial]:
	return [_capsule_material]


func build(in_structure_context: StructureContext) -> void:
	super.build(in_structure_context)


func _apply_scale_factor(_new_scale_factor: float) -> void:
	return


func show() -> void:
	super.show()
	_single_stick_multimesh.set_material_override(_capsule_material)
	_double_stick_multimesh.set_material_override(_capsule_material)
	_tripple_stick_multimesh.set_material_override(_capsule_material)
	# Override members from parent class
	_material_bond_1 = _capsule_material
	_material_bond_2 = _capsule_material
	_material_bond_3 = _capsule_material
	_init_material_uniforms()


func _init_material_uniforms() -> void:
	_single_stick_multimesh.set_material_instance_uniform(CapsuleStickMaterial.INSTANCE_UNIFORM_BASE_SCALE, 1.00)
	_double_stick_multimesh.set_material_instance_uniform(CapsuleStickMaterial.INSTANCE_UNIFORM_BASE_SCALE, 1.00)
	_tripple_stick_multimesh.set_material_instance_uniform(CapsuleStickMaterial.INSTANCE_UNIFORM_BASE_SCALE, 1.00)
	_capsule_material.set_scale(1.00).set_caps_starts_at_local_z(0.44)
	_update_is_selectable_uniform()


func _update_is_selectable_uniform() -> void:
	var _structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var is_editable: bool = _structure_context.is_editable()
	_capsule_material.set_selectable(is_editable)


func _calculate_bond_transform(in_bond: Vector3i) -> Transform3D:
	var related_structure: AtomicStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id)
	var bond_order: int = in_bond.z
	var first_atom_id: int = in_bond.x
	var second_atom_id: int = in_bond.y
	var first_atom_position: Vector3 = related_structure.atom_get_position(first_atom_id)
	var second_atom_position: Vector3 = related_structure.atom_get_position(second_atom_id)
	var distance_between_atoms: float = first_atom_position.distance_to(second_atom_position)
	var dir_from_first_to_second: Vector3 = first_atom_position.direction_to(second_atom_position)
	var up_vector: Vector3 = StickRepresentation._calc_up_vect_for_single_bond(dir_from_first_to_second) if bond_order == 1 else \
			StickRepresentation._calc_up_vector_for_higher_bond(first_atom_id, second_atom_id, first_atom_position,
					second_atom_position, related_structure)
	var particle_position: Vector3 = (first_atom_position + second_atom_position) / 2.0
	var new_transform: Transform3D = Transform3D(Basis(), particle_position)
	new_transform = new_transform.looking_at(first_atom_position, up_vector)
	new_transform = new_transform.scaled_local(Vector3(1, 1, distance_between_atoms))
	return new_transform


func set_atom_selection_position_delta(in_movement_delta: Vector3) -> void:
	# TODO: implement GPU translation
	var bonds_to_update: PackedInt32Array = PackedInt32Array()
	var structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var related_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
	bonds_to_update.append_array(structure_context.get_selected_bonds())
	bonds_to_update.append_array(_current_bond_partial_selection.keys())
	for bond_id in bonds_to_update:
		var bond: Vector3i = related_structure.get_bond(bond_id)
		var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
		var related_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[particle_id.bond_order]
		var bond_transform: Transform3D = _calculate_partial_selection_translation(bond, in_movement_delta)
		related_multimesh.update_particle_transform(particle_id.bond_id, bond_transform)
	update_segments_if_needed() 


func rotate_atom_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	# TODO: implement GPU rotation
	var structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var related_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
	var bonds_to_update: PackedInt32Array = PackedInt32Array()
	bonds_to_update.append_array(structure_context.get_selected_bonds())
	bonds_to_update.append_array(_current_bond_partial_selection.keys())
	for bond_id in bonds_to_update:
		var bond: Vector3i = related_structure.get_bond(bond_id)
		var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
		var related_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[particle_id.bond_order]
		var bond_transform: Transform3D = _calculate_partial_selection_transform(bond, in_point, in_rotation_to_apply)
		related_multimesh.update_particle_transform(particle_id.bond_id, bond_transform)
	update_segments_if_needed() 


func hydrogens_rendering_off() -> void:
	_capsule_material.disable_hydrogen_rendering()
	_init_material_uniforms()


func hydrogens_rendering_on() -> void:
	_capsule_material.enable_hydrogen_rendering()
	_init_material_uniforms()


func update(_in_delta: float) -> void:
	return


static func calc_bond_visual_radius(in_bond_order: int, in_smaller_atom_radius: float) -> float:
	return CAPSULE_MODEL_RADIUS * calc_bond_width_factor(in_bond_order, in_smaller_atom_radius)


static func calc_bond_width_factor(_in_bond_order: int, in_smaller_atom_radius: float) -> float:
	return in_smaller_atom_radius * _BOND_TO_ATOM_WIDTH


func apply_theme(in_theme: Theme3D) -> void:
	var old_order_1_material: ShaderMaterial = _material_bond_1
	var old_order_2_material: ShaderMaterial = _material_bond_2
	var old_order_3_material: ShaderMaterial = _material_bond_3
	
	_material_bond_1 = in_theme.create_stick_order_1_material()
	_material_bond_2 = in_theme.create_stick_order_2_material()
	_material_bond_3 = in_theme.create_stick_order_3_material()
	
	assert(_material_bond_1 is CapsuleStickMaterial)
	assert(_material_bond_2 is CapsuleStickMaterial)
	assert(_material_bond_3 is CapsuleStickMaterial)
	
	_single_stick_multimesh.set_mesh_override(in_theme.create_stick_mesh_order_1())
	_single_stick_multimesh.set_material_override(_material_bond_1)
	_double_stick_multimesh.set_mesh_override(in_theme.create_stick_mesh_order_2())
	_double_stick_multimesh.set_material_override(_material_bond_2)
	_tripple_stick_multimesh.set_mesh_override(in_theme.create_stick_mesh_order_3())
	_tripple_stick_multimesh.set_material_override(_material_bond_3)
	
	_material_bond_1.copy_state_from(old_order_1_material)
	_material_bond_2.copy_state_from(old_order_2_material)
	_material_bond_3.copy_state_from(old_order_3_material)


func saturate() -> void:
	_material_bond_1.saturate()
	_material_bond_2.saturate()
	_material_bond_3.saturate()


func desaturate() -> void:
	_material_bond_1.desaturate()
	_material_bond_2.desaturate()
	_material_bond_3.desaturate()


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.create_state_snapshot()
	snapshot["_capsule_material.snapshot"] = _capsule_material.create_state_snapshot()
	return snapshot
	

func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_snapshot)
	_capsule_material.apply_state_snapshot(in_snapshot["_capsule_material.snapshot"])
