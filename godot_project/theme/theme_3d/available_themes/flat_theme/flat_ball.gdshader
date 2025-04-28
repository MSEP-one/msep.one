// NOTE: Shader automatically converted from Godot Engine 4.2.3.rc's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_lambert,specular_schlick_ggx,vertex_lighting;

#include "res://editor/rendering/atomic_structure_renderer/representation/gizmo_transform_delta.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/hydrogens.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/outlines.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/selectable.gdshaderinc"

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform float specular;
uniform float metallic;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;

uniform float scale = 0.01;

uniform float flat_saturation: hint_range(0,1) = 0.75;
uniform float flat_outline_selection_thickness = 0.6;
uniform float flat_outline_default_thickness = 0.15;


vec3 displace_outline(vec3 vertex, vec2 uv, mat4 model_matrix, vec3 camera_position_world, vec4 color) {
	// COLOR.a > 2.0 always means the atom is selected
	float object_is_selected = clamp(step(2.0, color.a), 0.0, 1.0);
	vec3 model_origin_pos_in_world_space = (model_matrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float inverse_scale = 1.0 / length(vec3(model_matrix[0][0], model_matrix[0][1], model_matrix[0][2]));
	vec3 dir = normalize(vec3(vertex.x, vertex.y, 0.0));
	float distance_to_camera = length(camera_position_world - model_origin_pos_in_world_space);
	
	float should_show_selection_outline = is_atom_or_bond_hovered(color.a);
	should_show_selection_outline = float_or(should_show_selection_outline, is_hovered);
	should_show_selection_outline = float_or(object_is_selected, should_show_selection_outline);
	float should_show_default_outline = float_not(should_show_selection_outline);
	float outline_thickness_min = (should_show_selection_outline * flat_outline_selection_thickness) * 0.025;
	float outline_thickness_max = (should_show_selection_outline * flat_outline_selection_thickness) * 0.012;
	outline_thickness_min = outline_thickness_min + (flat_outline_default_thickness * should_show_default_outline) * 0.025;
	outline_thickness_max = outline_thickness_max + (flat_outline_default_thickness * should_show_default_outline) * 0.12;
	
	float outline_displace = clamp(distance_to_camera * outline_thickness*0.001, outline_thickness_min, outline_thickness_max);
	return uv_is_outline(uv) * dir * inverse_scale * outline_displace * (1.0 / scale);
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
	
	ROUGHNESS=roughness;
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	
	// outline
	float is_preview = _unpack_flag(SELECTION_PREVIEW_VISUAL_LAYER, int(CAMERA_VISIBLE_LAYERS));
	is_instance_hovered = is_atom_or_bond_hovered(COLOR.a);
	is_outline = uv_is_outline(UV);
	VERTEX += displace_outline(VERTEX, UV, MODEL_MATRIX, CAMERA_POSITION_WORLD, COLOR) * float_not(is_preview);;
	
	// Calculate rotation matrix to align model with camera
	vec3 camera_right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 camera_up = normalize(INV_VIEW_MATRIX[1].xyz);
	mat4 billboard_rot = mat4(
		vec4(normalize(camera_right), 0.0),
		vec4(normalize(camera_up), 0.0),
		vec4(cross(normalize(camera_right), normalize(camera_up)), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	vec3 final_vertex = (billboard_rot * vec4(VERTEX, 1.0)).xyz;
	
	//apply scale
	final_vertex = final_vertex * scale;
	
	//apply rotation
	final_vertex += get_rotation_delta(COLOR, MODEL_MATRIX);

	//apply translation delta
	final_vertex += get_translation_delta(COLOR, MODEL_MATRIX);
	
	//preview visibility
	final_vertex *= float_or(float_not(is_preview), is_atom_or_bond_selected(COLOR.a));
	
	VERTEX = hide_hydrogen_atoms(final_vertex, COLOR.a);
}


void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	albedo_tex *= COLOR;
	ALBEDO = albedo.rgb * albedo_tex.rgb * flat_saturation;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	ALBEDO = flat_outline_color(ALBEDO, COLOR);
}

