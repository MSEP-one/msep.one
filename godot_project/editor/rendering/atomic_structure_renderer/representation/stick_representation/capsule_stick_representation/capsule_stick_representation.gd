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
	if _is_preview:
		_capsule_material.set_selectable(true)
		return
	var _structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var is_editable: bool = _structure_context.is_editable()
	_capsule_material.set_selectable(is_editable)


func _calculate_bond_transform(in_nano_structure: AtomicStructure, in_bond: Vector3i) -> Transform3D:
	var bond_order: int = in_bond.z
	var first_atom_id: int = in_bond.x
	var second_atom_id: int = in_bond.y
	var first_atom_position: Vector3 = in_nano_structure.atom_get_position(first_atom_id)
	var second_atom_position: Vector3 = in_nano_structure.atom_get_position(second_atom_id)
	var dir_from_first_to_second: Vector3 = first_atom_position.direction_to(second_atom_position)
	var up_vector: Vector3 = StickRepresentation._calc_up_vect_for_single_bond(dir_from_first_to_second) if bond_order == 1 else \
			StickRepresentation._calc_up_vector_for_higher_bond(first_atom_id, second_atom_id, first_atom_position,
					second_atom_position, in_nano_structure, get_viewport().get_camera_3d())
	var new_transform: Transform3D = calculate_transform_for_bond(first_atom_position,
			second_atom_position, up_vector)
	return new_transform


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
	var old_capsule_material: ShaderMaterial = _capsule_material
	
	_capsule_material = in_theme.create_stick_order_1_material()
	_material_bond_1 = _capsule_material
	_material_bond_2 = _capsule_material
	_material_bond_3 = _capsule_material
	
	assert(_material_bond_1 is CapsuleStickMaterial)
	assert(_material_bond_2 is CapsuleStickMaterial)
	assert(_material_bond_3 is CapsuleStickMaterial)
	
	_single_stick_multimesh.set_mesh_override(in_theme.create_stick_mesh_order_1())
	_single_stick_multimesh.set_material_override(_material_bond_1)
	_double_stick_multimesh.set_mesh_override(in_theme.create_stick_mesh_order_2())
	_double_stick_multimesh.set_material_override(_material_bond_2)
	_tripple_stick_multimesh.set_mesh_override(in_theme.create_stick_mesh_order_3())
	_tripple_stick_multimesh.set_material_override(_material_bond_3)
	
	if old_capsule_material:
		# Old material could be null if theme is set before initialization
		_capsule_material.copy_state_from(old_capsule_material)
	
	var is_built: bool = _workspace_context != null
	if is_built:
		_update_is_selectable_uniform()


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
