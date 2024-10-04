extends PreviewBondMaterial

const SHADER_PARAM_COLOR_FIRST = "first_color"
const SHADER_PARAM_COLOR_SECOND = "second_color"

func apply_element_data(in_first_data: ElementData, in_second_data: ElementData) -> void:
	var first_color: Color = in_first_data.bond_color
	var second_color: Color = in_second_data.bond_color
	set_shader_parameter(SHADER_PARAM_COLOR_FIRST, first_color)
	set_shader_parameter(SHADER_PARAM_COLOR_SECOND, second_color)
