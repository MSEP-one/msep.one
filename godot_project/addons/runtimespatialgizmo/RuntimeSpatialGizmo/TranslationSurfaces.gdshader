shader_type canvas_item;

uniform float u_circle_size : hint_range(.001, 2.0, .01) = 2.0;
uniform float u_intensity_factor : hint_range(.1, 1.0, .01) = .54;
uniform float u_intensitiy_bottom_threshold : hint_range(0.2, 1.0, 0.01) = .95;

void fragment() {
	// Radial gradient.
	vec2 circleUV = (vec2(length(UV + .5))) / u_circle_size;
	float circle = 1.0 - circleUV.x * circleUV.y;
	vec3 color_intensity = clamp(vec3(circle) * u_intensity_factor, .0, 1.0) + u_intensitiy_bottom_threshold;
	vec4 color = COLOR * vec4(color_intensity, 1.0);
	
	COLOR = color;
}
