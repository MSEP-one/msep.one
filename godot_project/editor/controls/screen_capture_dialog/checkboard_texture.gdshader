shader_type canvas_item;

uniform int checkboard_size: hint_range(4, 100, 1) = 10;
uniform vec3 color_a: source_color;
uniform vec3 color_b: source_color;


void fragment() {
	int color_id = (int(FRAGCOORD.x) / checkboard_size + int(FRAGCOORD.y) / checkboard_size) % 2;
	COLOR.rgb = mix(color_a, color_b, float(color_id));
}
