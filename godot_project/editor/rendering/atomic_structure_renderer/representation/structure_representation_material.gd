"@abstract_class"
class_name StructureRepresentationMaterial extends ShaderMaterial


const UNIFORM_SHOW_HYDROGENS = &"show_hydrogens"
const UNIFORM_IS_SELECTABLE := &"is_selectable"


func enable_hydrogen_rendering() -> void:
	const SHOW_HYDROGENS = 1.0
	set_shader_parameter(UNIFORM_SHOW_HYDROGENS, SHOW_HYDROGENS)


func disable_hydrogen_rendering() -> void:
	const HIDE_HYDROGENS = 0.0
	set_shader_parameter(UNIFORM_SHOW_HYDROGENS, HIDE_HYDROGENS)


func copy_state_from(_in_from_material: ShaderMaterial) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot[UNIFORM_SHOW_HYDROGENS] = get_shader_parameter(UNIFORM_SHOW_HYDROGENS)
	snapshot[UNIFORM_IS_SELECTABLE] = get_shader_parameter(UNIFORM_IS_SELECTABLE)
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	set_shader_parameter(UNIFORM_SHOW_HYDROGENS, in_snapshot[UNIFORM_SHOW_HYDROGENS])
	set_shader_parameter(UNIFORM_IS_SELECTABLE, in_snapshot[UNIFORM_IS_SELECTABLE])
