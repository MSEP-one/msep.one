shader_type sky;

uniform sampler2D background: source_color;

void sky() {
	COLOR = texture(background, SCREEN_UV).rgb;
}
