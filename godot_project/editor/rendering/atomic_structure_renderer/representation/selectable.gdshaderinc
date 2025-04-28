// Holds the logic to dimm the color of objects when they are non selectable/editable

#include "constants.gdshaderinc"
#include "float_operations.gdshaderinc"

uniform float is_selectable: hint_range(0.0, 1.0, 1.0) = 1.0;
uniform float saturation: hint_range(0.0, 1.0, 0.1) = 1.0;
uniform float value_correction: hint_range(0.0, 1.0, 0.1) = 1.0;

// Usage:
// COLOR.rgb = apply_selectable_dimming(COLOR).rgb;
// Custom Data Usage:
// custom_data = apply_selectable_dimming(INSTANCE_CUSTOM);
vec4 apply_selectable_dimming(vec4 color) {
	
	float selectable_factor = mix(DIMM_FACTOR, 1.0, is_selectable);
	return color * selectable_factor;
}


vec3 apply_saturation(vec3 color) {
	vec3 desaturated_color = vec3((color.r + color.g + color.b) / 3.0);
	return mix(desaturated_color, color, saturation);
}


vec3 apply_value(vec3 color) {
	return color * value_correction;
}