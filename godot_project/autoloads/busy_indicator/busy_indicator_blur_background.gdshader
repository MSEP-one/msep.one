shader_type canvas_item;

uniform float blur: hint_range(0.0, 4.0, 0.1) = 1.0;
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;

void fragment() {
	COLOR.rgb = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur).rgb;
}
