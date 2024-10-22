// NOTE: Shader automatically converted from Godot Engine 4.2.3.rc's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_lambert_wrap,specular_schlick_ggx,vertex_lighting;

#include "res://editor/rendering/atomic_structure_renderer/representation/hydrogens.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/selectable.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/gizmo_transform_delta.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/outlines.gdshaderinc"


const float BOND_ATOM_RADIUS_FACTOR = 35.0; //to make bond roughly 1/3 size of the atom
const float SRGB_ALPHA = 0.055;

//uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float point_size : hint_range(0,128);
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform float specular;
uniform float metallic;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;


uniform sampler2D texture_color_curve: repeat_disable;
varying float percent;
varying vec3 custom_color;

uniform float flat_saturation: hint_range(0,1) = 0.75;
uniform float flat_outline_selection_thickness = 0.6;
uniform float flat_outline_default_thickness = 0.15;

uniform float atom_scale = 1.0;
instance uniform float base_scale = 1.0;

// Usage:
// COLOR.rgb = _apply_bond_highlight_factor(COLOR.rgb, is_left_selected);
vec3 _apply_bond_highlight_factor(vec3 color, float is_selected) {
	return mix(color, color * BOND_HIGHLIGHT_FACTOR, is_selected);
}


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


vec3 flat_calculate_bond_outline_displacement(vec3 vertex, vec3 normal, vec2 uv, mat4 model_matrix, vec3 camera_position_world, vec4 color) {
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
	float should_show_selection_outline = float_or(bond_hovered, vertex_active);
	float should_show_default_outline = float_not(should_show_selection_outline);
	
	float outline_thickness_min = (should_show_selection_outline * flat_outline_selection_thickness) * 0.025;
	float outline_thickness_max = (should_show_selection_outline * flat_outline_selection_thickness) * 0.012;
	outline_thickness_min = outline_thickness_min + (flat_outline_default_thickness * should_show_default_outline) * 0.025;
	outline_thickness_max = outline_thickness_max + (flat_outline_default_thickness * should_show_default_outline) * 0.12;
	float outline_displace = clamp(distance_to_camera * outline_thickness*0.001, outline_thickness_min, outline_thickness_max) * 0.5;
	vec3 dir = -normal;
	return uv_is_outline(uv) * dir * inverse_scale * outline_displace;
}


vec3 flat_outline_color(vec3 in_albedo, vec4 instance_color) {
	float strength = 2.5 * 1.0/flat_saturation;
	float object_is_selected = is_atom_or_bond_selected(instance_color.a);
	float should_show_selection_outline = is_atom_or_bond_hovered(instance_color.a);
	should_show_selection_outline = float_or(should_show_selection_outline, is_hovered);
	should_show_selection_outline = float_or(object_is_selected, should_show_selection_outline);
	vec4 selection_outline_color = mix(selected_atom_outline_color, hovered_atom_outline_color, is_instance_hovered);
	vec4 flat_outline_color = vec4(in_albedo * 0.125, 1.0) * flat_saturation;
	vec4 outline_color = mix(flat_outline_color, selection_outline_color, should_show_selection_outline);
	return mix(in_albedo, outline_color.rgb * strength, is_outline);
}


void vertex() {
	
	// bond radius
	float atom_radius = INSTANCE_CUSTOM.a;
	VERTEX.x = VERTEX.x * atom_radius * atom_scale * BOND_ATOM_RADIUS_FACTOR * base_scale;
	VERTEX.y = VERTEX.y * atom_radius * atom_scale * BOND_ATOM_RADIUS_FACTOR * base_scale;
	
	COLOR.rgb = apply_selectable_dimming(COLOR).rgb;
	custom_color = srgb_to_linear(apply_selectable_dimming(INSTANCE_CUSTOM)).rgb;
	
	float right_active = is_first_atom_selected(COLOR.a);
	float left_active = is_second_atom_selected(COLOR.a);
	
	COLOR.rgb = _apply_bond_highlight_factor(COLOR.rgb, right_active * is_bond_influence_highlight_enabled);
	custom_color.rgb = _apply_bond_highlight_factor(custom_color.rgb, left_active * is_bond_influence_highlight_enabled);
	
	is_outline = uv_is_outline(UV);
	is_instance_hovered = is_atom_or_bond_hovered(COLOR.a);
	VERTEX += flat_calculate_bond_outline_displacement(VERTEX, NORMAL, UV, MODEL_MATRIX, CAMERA_POSITION_WORLD, COLOR);
	
	vec3 vertex_position = VERTEX;
	ROUGHNESS=roughness;
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	percent = vertex_position.z;
	
	// rotation
	vertex_position += get_bond_rotation_delta(VERTEX, COLOR, MODEL_MATRIX);
	
	// translation
	vertex_position += get_bond_translation_delta(VERTEX, COLOR, MODEL_MATRIX);
	
	//
	VERTEX = vertex_position;
	VERTEX = hide_hydrogen_bonds(VERTEX, COLOR.a, INSTANCE_CUSTOM.a);
	VERTEX *= is_atom_or_bond_visible(COLOR.a);
}


void fragment() {
	vec2 base_uv = UV;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	
	//
	vec3 albedo = srgb_to_linear(COLOR).rgb  * flat_saturation;;
	float curve_percent = texture(texture_color_curve, vec2(percent + 0.5)).r;
	albedo = mix(albedo, custom_color, curve_percent);
	ALBEDO = flat_outline_color(albedo, COLOR);
}
