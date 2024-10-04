// Adapted from https://godotshaders.com/shader/pixel-perfect-outline-shader/
// by axilirate (CC0 license)

shader_type spatial;
render_mode unshaded,cull_front,depth_draw_opaque,shadows_disabled;

global uniform vec4 active_object_outline_color: source_color;
global uniform vec4 active_hover_object_outline_color: source_color;
global uniform vec4 unactive_hover_object_outline_color: source_color;
uniform float outline_width = 3;
uniform bool is_active = true;
uniform bool is_hover = false;
varying vec4 outline_color;

const float SRGB_ALPHA = 0.055;


float srgb_to_linear_component(float component) {
	if (component <= 0.04045)
		return component / 12.92;
	else
		return pow((component + SRGB_ALPHA) / (1.0 + SRGB_ALPHA), 2.4);
}

vec4 srgb_to_linear(vec4 sRGB) {
	sRGB.x = srgb_to_linear_component(sRGB.x);
	sRGB.y = srgb_to_linear_component(sRGB.y);
	sRGB.z = srgb_to_linear_component(sRGB.z);
	return sRGB;
}


void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	
	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_position.w * outline_width * 2.0;
	
	clip_position.xy += offset;
	
	POSITION = clip_position;
	
	if (is_active) {
		if (is_hover){
			outline_color = srgb_to_linear(active_hover_object_outline_color);
		} else {
			outline_color = srgb_to_linear(active_object_outline_color);
		}
	} else {
		if (is_hover){
			outline_color = srgb_to_linear(unactive_hover_object_outline_color);
		} else {
			outline_color = vec4(0.0);
		}
	}
}

void fragment() {
	if (outline_color.a < 0.01) {
		discard;
	}
	ALBEDO = outline_color.rgb;
}
