
shader_type spatial;

render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,vertex_lighting; 

#include "res://editor/rendering/atomic_structure_renderer/representation/hydrogens.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/outlines.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/selectable.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/gizmo_transform_delta.gdshaderinc"

// half of the mesh size along z axis, depending on the mesh
const float MODEL_LENGTH = 0.5;

const float NUMERICAL_PRECISION = 0.0001;

// "cap" in context of this file means part of capsule sphere (rounded start and ending)
// model z position above and below which there is capsule cap 
uniform float caps_starts_at_local_z_position = 0.235;
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform float specular;
uniform float metallic;
varying float percent;
varying vec3 custom_color;


float first_lower_then_second(float x, float y) {
  return max(sign(y - x), 0.0);
}


float first_greater_then_second(float x, float y) {
  return max(sign(x - y), 0.0);
}

// Usage:
// COLOR.rgb = _apply_bond_highlight_factor(COLOR.rgb, is_left_selected);
vec3 _apply_bond_highlight_factor(vec3 color, float is_selected) {
	return mix(color, color * BOND_HIGHLIGHT_FACTOR, is_selected);
}


void vertex() {
	// Common
	ROUGHNESS=roughness;
	percent = VERTEX.z;

	// Make the capsule match the bond length.
	// The capsule can't be scaled on the Z axis, or the end caps lose their round shape.
	// Instead the existing scale is reverted and the caps are moved as one block
	// to their end position.
	float scale_z = length(MODELVIEW_MATRIX[2]); // Bond length
	float cap_vertexes_above_local_pos = caps_starts_at_local_z_position - NUMERICAL_PRECISION;
	float cap_length = MODEL_LENGTH - caps_starts_at_local_z_position;
	float bond_length = scale_z + (cap_length * 0.5); // Increase bond length by the caps length to make the sticks connect
	float new_cap_starting_point = MODEL_LENGTH * bond_length - caps_starts_at_local_z_position - cap_length;
	VERTEX.z += first_greater_then_second(VERTEX.z, cap_vertexes_above_local_pos) * new_cap_starting_point;
	VERTEX.z -= first_lower_then_second(VERTEX.z, -cap_vertexes_above_local_pos) * new_cap_starting_point;
	VERTEX.z /= scale_z; // Cancel old scaling on Z
	
	// Gizmo delta
	vec3 vertex_position = VERTEX;
	vertex_position += get_bond_rotation_delta(VERTEX, COLOR, MODEL_MATRIX);
	vertex_position += get_bond_translation_delta(VERTEX, COLOR, MODEL_MATRIX);
	VERTEX = vertex_position;
	
	// Color
	COLOR.rgb = apply_selectable_dimming(COLOR).rgb;
	custom_color = apply_selectable_dimming(INSTANCE_CUSTOM).rgb;
	
	float right_active = is_first_atom_selected(COLOR.a) * is_bond_influence_highlight_enabled;
	float left_active = is_second_atom_selected(COLOR.a) * is_bond_influence_highlight_enabled;
	
	COLOR.rgb = _apply_bond_highlight_factor(COLOR.rgb, right_active);
	custom_color.rgb = _apply_bond_highlight_factor(custom_color.rgb, left_active);
	
	// Outline
	is_outline = uv_is_outline(UV);
	float is_preview = _unpack_flag(SELECTION_PREVIEW_VISUAL_LAYER, int(CAMERA_VISIBLE_LAYERS));
	is_instance_hovered = float_and(is_atom_or_bond_hovered(COLOR.a), float_not(is_preview));
	VERTEX += calculate_bond_outline_displacement(VERTEX, NORMAL, UV, MODEL_MATRIX, CAMERA_POSITION_WORLD, COLOR, is_preview);
	
	// Visibility
	VERTEX = hide_hydrogen_bonds(VERTEX, COLOR.a, INSTANCE_CUSTOM.a);
	VERTEX *= is_atom_or_bond_visible(COLOR.a);
	VERTEX *= float_or(float_not(is_preview), is_atom_or_bond_selected(COLOR.a));
}


void fragment() {
	vec2 base_uv = UV;
	vec3 albedo = vec3(0);
	
	// split model into two colors
	albedo += COLOR.rgb * first_lower_then_second(percent, 0.0);
	albedo += custom_color.rgb * first_greater_then_second(percent, 0.0);
	ALBEDO = calculate_outline_color(albedo, COLOR);
	ALBEDO.rgb = apply_saturation(ALBEDO.rgb);
	ALBEDO.rgb = apply_value(ALBEDO.rgb);
	
	//
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
}
