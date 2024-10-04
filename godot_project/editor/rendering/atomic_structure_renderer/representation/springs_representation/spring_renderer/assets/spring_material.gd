class_name SpringMaterial extends StructureRepresentationMaterial


const UNIFORM_ALBEDO := &"albedo"


func _init() -> void:
	RenderingUtils.has_uniforms(self, [UNIFORM_SHOW_HYDROGENS, UNIFORM_ALBEDO])


func set_color(in_color: Color) -> SpringMaterial:
	set_shader_parameter(UNIFORM_ALBEDO, in_color)
	return self


func copy_state_from(in_from_material: ShaderMaterial) -> void:
	RenderingUtils.copy_uniforms_from(in_from_material, self)
