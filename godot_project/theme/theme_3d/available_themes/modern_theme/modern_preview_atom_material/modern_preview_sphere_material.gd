extends PreviewSphereMaterial


func apply_element_data(in_element_data: ElementData) -> void:
	var albedo_color: Color = in_element_data.color
	var noise_color: Color = in_element_data.noise_color
	var noise_texture_id: float = in_element_data.noise_atlas_id
	set_shader_parameter(&"albedo", albedo_color)
	set_shader_parameter(&"noise_albedo", noise_color)
	set_shader_parameter(&"atlas_id", noise_texture_id)
