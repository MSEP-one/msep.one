// Holds the logic to dimm the color of objects when they are non selectable/editable

#include "constants.gdshaderinc"
#include "float_operations.gdshaderinc"

uniform float is_selectable: hint_range(0.0, 1.0, 1.0) = 1.0;


// Usage:
// COLOR.rgb = apply_selectable_dimming(COLOR).rgb;
// Custom Data Usage:
// custom_data = apply_selectable_dimming(INSTANCE_CUSTOM);
vec4 apply_selectable_dimming(vec4 color) {
	
	float selectable_factor = mix(DIMM_FACTOR, 1.0, is_selectable);
	return color * selectable_factor;
}