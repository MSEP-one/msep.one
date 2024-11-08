// "cap" in context of this file means part of capsule sphere (rounded start and ending)

shader_type spatial;

render_mode skip_vertex_transform,blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,vertex_lighting; 

#include "res://editor/rendering/atomic_structure_renderer/representation/hydrogens.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/outlines.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/selectable.gdshaderinc"

// half of the mesh size along z axis, depending on the mesh
const float MODEL_LENGTH = 0.5;

const float NUMERICAL_PRECISION = 0.0001;

// model z position above and below which there is capsule cap 
uniform float caps_starts_at_local_z_position = 0.235;
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


uniform float flat_saturation: hint_range(0,1) = 0.75;
uniform float flat_outline_selection_thickness = 0.6;
uniform float flat_outline_default_thickness = 0.15;


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
	COLOR.rgb = apply_selectable_dimming(COLOR).rgb;
	custom_color = apply_selectable_dimming(INSTANCE_CUSTOM).rgb;
	
	float right_active = is_first_atom_selected(COLOR.a) * is_bond_influence_highlight_enabled;
	float left_active = is_second_atom_selected(COLOR.a) * is_bond_influence_highlight_enabled;
	
	COLOR.rgb = _apply_bond_highlight_factor(COLOR.rgb, right_active);
	custom_color.rgb = _apply_bond_highlight_factor(custom_color.rgb, left_active);
	
	float is_preview = _unpack_flag(SELECTION_PREVIEW_VISUAL_LAYER, int(CAMERA_VISIBLE_LAYERS));
	is_outline = uv_is_outline(UV);
	is_instance_hovered = is_atom_or_bond_hovered(COLOR.a);
	VERTEX += flat_calculate_bond_outline_displacement(VERTEX, NORMAL, UV, MODEL_MATRIX, CAMERA_POSITION_WORLD, COLOR) * float_not(is_preview);
	
	//helper to prevent numerical errors
	float cap_vertexes_above_local_pos = caps_starts_at_local_z_position - NUMERICAL_PRECISION;
	
	//
	ROUGHNESS=roughness;
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	
	//
	vec3 position = VERTEX;
	mat4 modelview = MODELVIEW_MATRIX;
	mat3 rotation = mat3(modelview);
	vec3 scale = vec3(length(rotation[0]), length(rotation[1]), length(rotation[2]));
	
	percent = position.z;
	
	//apply width
	position.xy *= scale.x;
	
	// shift caps locally to proper positions
	float bond_length = scale.z;
	float cap_offset = MODEL_LENGTH - caps_starts_at_local_z_position;
	float cap_starting_point = MODEL_LENGTH * bond_length - caps_starts_at_local_z_position - cap_offset;
	position.z += first_greater_then_second(position.z, cap_vertexes_above_local_pos) * cap_starting_point;
	position.z -= first_lower_then_second(position.z, -cap_vertexes_above_local_pos) * cap_starting_point;
	
	//apply transform, exclude scale (scale already applied in form of width and caps shift
	rotation[0] /= scale.x;
	rotation[1] /= scale.y;
	rotation[2] /= scale.z;
	position /= scale;
	position = (modelview * vec4(position, 1.0)).xyz;
	
	//preview visibility
	position *= float_or(float_not(is_preview), is_atom_or_bond_selected(COLOR.a));
	
	VERTEX = position;
	VERTEX = hide_hydrogen_bonds(VERTEX, COLOR.a, INSTANCE_CUSTOM.a);
	VERTEX *= is_atom_or_bond_visible(COLOR.a);
}


void fragment() {
	vec2 base_uv = UV;
	vec3 albedo = vec3(0);
	
	// split model into two colors
	albedo += COLOR.rgb * first_lower_then_second(percent, 0.0);
	albedo += custom_color.rgb * first_greater_then_second(percent, 0.0);
	albedo *= flat_saturation;
	ALBEDO = flat_outline_color(albedo, COLOR);
	
	//
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
}
