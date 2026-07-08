shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;

const vec2 a1_uv = vec2(0.5, -0.5);
const vec2 a2_uv = vec2(0.5, 0.5);
uniform float n = 2.0;
uniform float m = 2.0;
uniform float nprime = 2.0;
uniform float mprime = 2.0;
uniform float repetitions = 0.5;
uniform float u_offset: hint_range(-1.0, 1.0, 0.05);
uniform vec3 atom_color: source_color = vec3(0.5);
uniform vec3 highlight_color: source_color = vec3(1.0);
uniform float[2] selection;
uniform sampler2D pattern;

varying vec3 color;
varying vec3 back_color;

vec3 darken(vec3 col) {
	return col * 0.4;
}

vec3 lighten(vec3 col) {
	col.r += (1.0 - col.r) * 0.1;
	col.g += (1.0 - col.g) * 0.1;
	col.b += (1.0 - col.b) * 0.1;
	return col;
}

void vertex() {
	color = mix(atom_color, highlight_color, selection[int(round(UV.y))]);
	float value = (color.r + color.g + color.b) / 3.0;
	back_color = mix(lighten(color), darken(color), round(value));
	
	vec2 c = a1_uv * n + a2_uv * m;
	vec2 t = a1_uv * nprime - a2_uv * mprime;
	vec2 u = (UV.x + u_offset) * c;
	vec2 v = UV.y * t * repetitions;
	
	UV = u + v;
}

void fragment() {
	if (texture(pattern, UV).a < 0.05) {
		discard;
	}
	
	ALBEDO = mix(back_color, color, float(FRONT_FACING));
}