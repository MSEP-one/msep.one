shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_toon,specular_disabled;

#include "res://editor/rendering/atomic_structure_renderer/representation/outlines.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/selectable.gdshaderinc"

uniform vec4 albedo : source_color;
uniform float roughness : hint_range(0,1);
uniform float specular;
uniform float metallic;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;

uniform float is_selected: hint_range(0.0, 1.0, 1.0) = 0.0;
// Simulates COLOR using the is_selected uniform
varying vec4 color;

vec3 _calculate_motor_outline_displacement(vec3 vertex, vec2 uv, mat4 model_matrix, vec3 camera_position_world, float scale) {
	// COLOR.a > 2.0 always means the atom is selected	
	float object_is_selected = clamp(step(2.0, color.a), 0.0, 1.0);
	vec3 model_origin_pos_in_world_space = (model_matrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float inverse_scale = 1.0 / length(vec3(model_matrix[0][0], model_matrix[0][1], model_matrix[0][2]));
	vec3 dir = normalize(vertex);
	float distance_to_camera = length(camera_position_world - model_origin_pos_in_world_space);
	float outline_thickness_min = outline_thickness * 0.025;
	float outline_thickness_max = outline_thickness * 0.12;
	float outline_displace = clamp(distance_to_camera * outline_thickness*0.001, outline_thickness_min, outline_thickness_max);
	float should_show_outline = float_or(is_selected, is_hovered);
	should_show_outline = float_or(object_is_selected, should_show_outline);
	outline_displace = mix(-length(vertex), inverse_scale * outline_displace * scale, should_show_outline);
	return uv_is_outline(uv) * dir * outline_displace;
}

void vertex() {
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	
	is_outline = uv_is_outline(UV);
	// Not a multimesh, is_instance_hovered is not used
	is_instance_hovered = is_hovered;
	const float SCALE = 0.3;
	color = vec4(albedo.rbg, is_selected + 1.0);
	VERTEX += _calculate_motor_outline_displacement(VERTEX, UV, MODEL_MATRIX, CAMERA_POSITION_WORLD, SCALE);
}


void fragment() {
	// Selectable dimming
	vec3 dimmed_albedo = apply_selectable_dimming(albedo).rgb;
	// An internal error fails to parse this code, so instead i copypasted the code to workaround the issue
	// ALBEDO = calculate_outline_color(dimmed_albedo, fake_color);
	float strength = color.a + is_instance_hovered;
	vec4 outline_color = mix(selected_atom_outline_color, hovered_atom_outline_color, is_instance_hovered);
	ALBEDO = mix(dimmed_albedo.rgb, outline_color.rgb * strength, is_outline);
	// end of workaround
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}

void light() {
	float dot_product = clamp(dot(NORMAL, LIGHT), -0.9, 0.9);
	vec3 light_color = clamp(LIGHT_COLOR * dot_product * 0.4, 0.0, 1.0);
	DIFFUSE_LIGHT += mix(light_color, vec3(0.5), is_outline);
}