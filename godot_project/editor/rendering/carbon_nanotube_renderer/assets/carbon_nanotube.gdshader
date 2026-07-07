shader_type spatial;
render_mode unshaded, depth_draw_opaque, depth_test_disabled;

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

void vertex() {
	color = mix(atom_color, highlight_color, selection[int(round(UV.y))]);
	
	vec2 c = a1_uv * n + a2_uv * m;
	vec2 t = a1_uv * nprime - a2_uv * mprime;
	vec2 u = (UV.x + u_offset) * c;
	vec2 v = UV.y * t * repetitions;
	
	UV = u + v;
}

void fragment() {
	vec4 c = texture(pattern, UV);
	if (c.a < 0.05) {
		discard;
	}
	ALBEDO = c.rgb * color;
	ALPHA = c.a;
}