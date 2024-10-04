class_name EnhancedCapsuleStickRepresentation
extends CapsuleStickRepresentation


const _SHADER_ENHANCED_SINGLE_BOND_MESH_CAPS_STARTS_AT_LOCAL_Z = 0.44
const _SHADER_ENHANCED_DOUBLE_BOND_MESH_CAPS_STARTS_AT_LOCAL_Z = 0.44
const _SHADER_ENHANCED_TRIPPLE_BOND_MESH_CAPS_STARTS_AT_LOCAL_Z = 0.44


func _init_material_uniforms() -> void:
	super._init_material_uniforms()
	_single_stick_multimesh.get_material_override().set_caps_starts_at_local_z(_SHADER_ENHANCED_SINGLE_BOND_MESH_CAPS_STARTS_AT_LOCAL_Z)
	_double_stick_multimesh.get_material_override().set_caps_starts_at_local_z(_SHADER_ENHANCED_DOUBLE_BOND_MESH_CAPS_STARTS_AT_LOCAL_Z)
	_tripple_stick_multimesh.get_material_override().set_caps_starts_at_local_z(_SHADER_ENHANCED_TRIPPLE_BOND_MESH_CAPS_STARTS_AT_LOCAL_Z)
	_update_is_selectable_uniform()


func apply_theme(in_theme: Theme3D) -> void:
	var old_order_1_material: ShaderMaterial = _material_bond_1
	var old_order_2_material: ShaderMaterial = _material_bond_2
	var old_order_3_material: ShaderMaterial = _material_bond_3
	
	_material_bond_1 = in_theme.create_enhanced_stick_order_1_material()
	_material_bond_2 = in_theme.create_enhanced_stick_order_2_material()
	_material_bond_3 = in_theme.create_enhanced_stick_order_3_material()
	
	assert(_material_bond_1 is CapsuleStickMaterial)
	assert(_material_bond_2 is CapsuleStickMaterial)
	assert(_material_bond_3 is CapsuleStickMaterial)
	
	_single_stick_multimesh.set_mesh_override(in_theme.create_enhanced_stick_mesh_order_1())
	_single_stick_multimesh.set_material_override(_material_bond_1)
	_double_stick_multimesh.set_mesh_override(in_theme.create_enhanced_stick_mesh_order_2())
	_double_stick_multimesh.set_material_override(_material_bond_2)
	_tripple_stick_multimesh.set_mesh_override(in_theme.create_enhanced_stick_mesh_order_3())
	_tripple_stick_multimesh.set_material_override(_material_bond_3)
	
	_material_bond_1.copy_state_from(old_order_1_material)
	_material_bond_2.copy_state_from(old_order_2_material)
	_material_bond_3.copy_state_from(old_order_3_material)
