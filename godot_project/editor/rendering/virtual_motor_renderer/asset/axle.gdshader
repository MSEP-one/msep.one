shader_type spatial;
render_mode unshaded;

uniform vec3 axle_color : source_color = vec3(1.0);
uniform float axle_thickness = 3.0;
uniform float axle_length = 2.0;

void vertex() {
	vec3 model_origin_pos_in_world_space = (MODEL_MATRIX * vec4(0.0, 0.0, axle_length / 2.0, 1.0)).xyz;
	float distance_to_camera = length(CAMERA_POSITION_WORLD - model_origin_pos_in_world_space);
	VERTEX -= NORMAL; // Switch cylinder radius from 1 meter to 0 meter
	VERTEX += NORMAL * distance_to_camera * axle_thickness * 0.0001; // Scale back up based on camera distance
	VERTEX.z *= axle_length;
}

void fragment() {
	ALBEDO = axle_color;
}