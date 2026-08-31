class_name SpringMaterial extends StructureRepresentationMaterial


const UNIFORM_ALBEDO := &"albedo"


func _init() -> void:
	RenderingUtils.has_uniforms(self, [UNIFORM_SHOW_HYDROGENS, UNIFORM_ALBEDO])


func set_color(in_color: Color) -> SpringMaterial:
	set_shader_parameter(UNIFORM_ALBEDO, in_color)
	return self


func copy_state_from(in_from_material: ShaderMaterial) -> void:
	RenderingUtils.copy_uniforms_from(in_from_material, self)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.create_state_snapshot()
	snapshot[UNIFORM_ALBEDO] = get_shader_parameter(UNIFORM_ALBEDO)
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	set_shader_parameter(UNIFORM_ALBEDO, in_snapshot[UNIFORM_ALBEDO])
	super.apply_state_snapshot(in_snapshot)
