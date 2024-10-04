// NOTE: Shader automatically converted from Godot Engine 4.0.beta3's StandardMaterial3D.

shader_type spatial;

render_mode blend_mix,depth_draw_always,cull_back,diffuse_burley,specular_schlick_ggx,vertex_lighting;

#include "res://editor/rendering/atomic_structure_renderer/representation/hydrogens.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/selectable.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/gizmo_transform_delta.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/outlines.gdshaderinc"

//
const float SRGB_ALPHA = 0.055;
const float BOND_ATOM_RADIUS_FACTOR = 35.0; //to make bond roughly 1/3 size of the atom

uniform float atom_scale = 1.0;

uniform sampler2D texture_color_curve: repeat_disable;
uniform float emission_energy = 0.0;
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform float specular;
uniform float metallic;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
varying float percent;
varying vec3 custom_color;
instance uniform float base_scale = 1.0;

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

// Usage:
// COLOR.rgb = _apply_bond_highlight_factor(COLOR.rgb, is_left_selected);
vec3 _apply_bond_highlight_factor(vec3 color, float is_selected) {
	return mix(color, color * BOND_HIGHLIGHT_FACTOR, is_selected);
}

void vertex() {
	COLOR.rgb = apply_selectable_dimming(COLOR).rgb;
	custom_color = srgb_to_linear(apply_selectable_dimming(INSTANCE_CUSTOM)).rgb;
	
	float right_active = is_first_atom_selected(COLOR.a);
	float left_active = is_second_atom_selected(COLOR.a);
	
	COLOR.rgb = _apply_bond_highlight_factor(COLOR.rgb, right_active * is_bond_influence_highlight_enabled);
	custom_color.rgb = _apply_bond_highlight_factor(custom_color.rgb, left_active * is_bond_influence_highlight_enabled);
	
	is_outline = uv_is_outline(UV);
	is_instance_hovered = is_atom_or_bond_hovered(COLOR.a);
	VERTEX += calculate_bond_outline_displacement(VERTEX, NORMAL, UV, MODEL_MATRIX, CAMERA_POSITION_WORLD, COLOR);
	
	// bond radius
	float atom_radius = INSTANCE_CUSTOM.a;
	VERTEX.x = VERTEX.x * atom_radius * atom_scale * BOND_ATOM_RADIUS_FACTOR * base_scale;
	VERTEX.y = VERTEX.y * atom_radius * atom_scale * BOND_ATOM_RADIUS_FACTOR * base_scale;
	
	vec3 vertex_position = VERTEX;
	ROUGHNESS=roughness;
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	percent = vertex_position.z;
	
	// rotation
	vertex_position += get_bond_rotation_delta(VERTEX, COLOR, MODEL_MATRIX);
	
	// translation
	//vertex_position += (inv_model_mat * vec4(selection_delta * factor, 0.0)).xyz * right_active * left_active;
	vertex_position += get_bond_translation_delta(VERTEX, COLOR, MODEL_MATRIX);
	//
	VERTEX = vertex_position;
	VERTEX = hide_hydrogen_bonds(VERTEX, COLOR.rgb, INSTANCE_CUSTOM.rgb);
	VERTEX *= is_atom_or_bond_visible(COLOR.a);
}


void fragment() {
	vec2 base_uv = UV;
	vec3 albedo = srgb_to_linear(COLOR).rgb;
	
	float curve_percent = texture(texture_color_curve, vec2(percent + 0.5)).r;
	albedo = mix(albedo, custom_color, curve_percent);
	ALBEDO = calculate_outline_color(albedo, COLOR);
	EMISSION = albedo * emission_energy;
	
	//
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
}
