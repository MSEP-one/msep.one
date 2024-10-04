extends PreviewSphereMaterial


func apply_element_data(in_element_data: ElementData) -> void:
	var albedo_color: Color = in_element_data.color
	set_shader_parameter(&"albedo", albedo_color)
