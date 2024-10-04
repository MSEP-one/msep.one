class_name CapsuleStickMaterial extends StructureRepresentationMaterial


const INSTANCE_UNIFORM_BASE_SCALE: StringName = &"base_scale"
const UNIFORM_CAPS_STARTS_AT_LOCAL_Z: StringName = &"caps_starts_at_local_z_position"
const UNIFORM_OUTLINE_THICKNESS = &"outline_thickness"
const UNIFORM_IS_HOVERED = &"is_hovered"


func _init() -> void:
	RenderingUtils.has_uniforms(self, [INSTANCE_UNIFORM_BASE_SCALE,
			UNIFORM_CAPS_STARTS_AT_LOCAL_Z, UNIFORM_OUTLINE_THICKNESS])


func set_scale(new_scale: float) -> CapsuleStickMaterial:
	set_shader_parameter(INSTANCE_UNIFORM_BASE_SCALE, new_scale)
	return self


func set_selectable(in_is_selectable: bool) -> CapsuleStickMaterial:
	const SELECTABLE = 1.0
	const NON_SELECTABLE = 1.0
	var value_to_apply: float = SELECTABLE if in_is_selectable else NON_SELECTABLE
	set_shader_parameter(UNIFORM_IS_SELECTABLE, value_to_apply)
	return self


func set_hovered(in_is_hovered: bool) -> CapsuleStickMaterial:
	const HOVERED_VALUE = 1.0
	const NON_HOVERED_VALUE = 0.0
	var value_to_apply: float = HOVERED_VALUE if in_is_hovered else NON_HOVERED_VALUE
	set_shader_parameter(UNIFORM_IS_HOVERED, value_to_apply)
	return self


func set_caps_starts_at_local_z(in_start_distance: float) -> CapsuleStickMaterial:
	set_shader_parameter(UNIFORM_CAPS_STARTS_AT_LOCAL_Z, in_start_distance)
	return self


func copy_state_from(_in_from_material: ShaderMaterial) -> void:
	return # no need in this case


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.create_state_snapshot()
	snapshot[UNIFORM_CAPS_STARTS_AT_LOCAL_Z] = get_shader_parameter(UNIFORM_CAPS_STARTS_AT_LOCAL_Z)
	snapshot[UNIFORM_OUTLINE_THICKNESS] = get_shader_parameter(UNIFORM_OUTLINE_THICKNESS)
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_snapshot)
	set_shader_parameter(UNIFORM_CAPS_STARTS_AT_LOCAL_Z, in_snapshot[UNIFORM_CAPS_STARTS_AT_LOCAL_Z])
	set_shader_parameter(UNIFORM_OUTLINE_THICKNESS, in_snapshot[UNIFORM_OUTLINE_THICKNESS])
