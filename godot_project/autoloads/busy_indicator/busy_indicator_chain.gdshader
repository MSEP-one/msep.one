shader_type canvas_item;

uniform float time = 0;
uniform float spin_factor = 0;
uniform float spin_speed = -1.57;

void vertex() {
	UV.x += time * spin_speed * spin_factor;
}