// Holds the logic to draw outlines on meshes when they are meant to

#include "float_operations.gdshaderinc"
#include "instance_state.gdshaderinc"

uniform float outline_thickness = 0.2;


global uniform vec4 selected_atom_outline_color = vec4(1.0);
global uniform vec4 hovered_atom_outline_color = vec4(1.0);
global uniform float is_bond_influence_highlight_enabled = 0.0;


uniform float is_hovered: hint_range(0.0, 1.0, 1.0) = 0.0;

// Usage:
// void vertex() { is_outline = uv_is_outline(UV); }
varying float is_outline;

// Usage:
// void vertex() { is_instance_hovered = is_multimesh_instance_hovered(COLOR); }
varying float is_instance_hovered;


float uv_is_outline(vec2 uv) {
	// UV with x component less than 0 means the mesh is an outline, and can me grown
	return step(uv.x, 0.0); // 0.0 < uv.x ? 0.0 /* not outline */ : 1.0 /* outline */
}

// Usage:
// VERTEX += calculate_outline_displacement(VERTEX, UV, MODEL_MATRIX, CAMERA_POSITION_WORLD, COLOR, scale);
vec3 calculate_outline_displacement(vec3 vertex, vec2 uv, mat4 model_matrix, vec3 camera_position_world, vec4 color, float scale) {
	float object_is_selected = is_atom_or_bond_selected(color.a);
	vec3 model_origin_pos_in_world_space = (model_matrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float inverse_scale = 1.0 / length(vec3(model_matrix[0][0], model_matrix[0][1], model_matrix[0][2]));
	vec3 dir = normalize(vec3(vertex.x, vertex.y, 0.0));
	float distance_to_camera = length(camera_position_world - model_origin_pos_in_world_space);
	float outline_thickness_min = outline_thickness * 0.025;
	float outline_thickness_max = outline_thickness * 0.12;
	float outline_displace = clamp(distance_to_camera * outline_thickness*0.001, outline_thickness_min, outline_thickness_max);
	float should_show_outline = is_atom_or_bond_hovered(color.a);
	should_show_outline = float_or(should_show_outline, is_hovered);
	should_show_outline = float_or(object_is_selected, should_show_outline);
	return uv_is_outline(uv) * mix(-vertex, dir * inverse_scale * outline_displace * (1.0 / scale), should_show_outline);
}

// Usage:
// VERTEX += calculate_bond_outline_displacement(VERTEX, NORMAL, UV, MODEL_MATRIX, CAMERA_POSITION_WORLD, COLOR);
vec3 calculate_bond_outline_displacement(vec3 vertex, vec3 normal, vec2 uv, mat4 model_matrix, vec3 camera_position_world, vec4 color) {
	float bond_hovered = float_or(is_atom_or_bond_hovered(color.a), is_hovered);
	float bond_selected = is_atom_or_bond_selected(color.a);
	float right_active = float_or(float_and(is_first_atom_selected(color.a), is_bond_influence_highlight_enabled), bond_selected);
	float left_active = float_or(float_and(is_second_atom_selected(color.a), is_bond_influence_highlight_enabled), bond_selected);
	
	float vertex_active = 0.0;
	vertex_active += float_and(float_eq(sign(vertex.z), -1.0), right_active);
	vertex_active += float_and(float_eq(sign(vertex.z), +1.0), left_active);
	vec3 model_origin_pos_in_world_space = (model_matrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float inverse_scale = 1.0 / length(vec3(model_matrix[0][0], model_matrix[0][1], model_matrix[0][2]));
	float distance_to_camera = length(camera_position_world - model_origin_pos_in_world_space);
	float outline_thickness_min = outline_thickness * 0.025;
	float outline_thickness_max = outline_thickness * 0.12;
	float outline_displace = clamp(distance_to_camera * outline_thickness*0.001, outline_thickness_min, outline_thickness_max) * 0.5;
	float should_show_outline = float_or(bond_hovered, vertex_active);
	vec3 dir = -normal;
	return uv_is_outline(uv) * mix(-vertex, dir * inverse_scale * outline_displace, should_show_outline);
}

// Usage:
// ALBEDO = calculate_outline_color(ALBEDO, COLOR);
vec3 calculate_outline_color(vec3 in_albedo, vec4 instance_color) {
	float strength = 2.5;
	vec4 outline_color = mix(selected_atom_outline_color, hovered_atom_outline_color, is_instance_hovered);
	return mix(in_albedo, outline_color.rgb * strength, is_outline);
}
