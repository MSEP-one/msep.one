shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest_mipmap;

void fragment() {
	COLOR = COLOR * textureLod(screen_texture, SCREEN_UV, .9);
}
