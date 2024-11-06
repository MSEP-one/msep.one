// NOTE: Shader automatically converted from Godot Engine 4.2.3.rc's StandardMaterial3D.
shader_type spatial;
render_mode blend_mix,depth_draw_always,cull_disabled,diffuse_burley,specular_schlick_ggx;

#include "res://editor/rendering/atomic_structure_renderer/representation/hydrogens.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/instance_state.gdshaderinc"

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear,repeat_enable;
uniform float alpha_scissor_threshold;
uniform float point_size : hint_range(0,128);
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_g,filter_linear,repeat_enable;
uniform float specular;
uniform float metallic;
uniform sampler2D texture_normal : hint_roughness_normal,filter_linear,repeat_enable;
uniform float normal_scale : hint_range(-16,16);
uniform sampler2D texture_ambient_occlusion : hint_default_white, filter_linear,repeat_enable;
uniform vec4 ao_texture_channel;
uniform float ao_light_affect;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

const float SPRING_DENSITY_FACTOR = 15.0;

void vertex() {
	VERTEX = hide_hydrogen_springs(VERTEX, COLOR.a);
	
	float is_preview = _unpack_flag(SELECTION_PREVIEW_VISUAL_LAYER, int(CAMERA_VISIBLE_LAYERS));
	float is_selected = is_atom_or_bond_selected(COLOR.a);
	VERTEX *= float_or(float_not(is_preview), is_selected);
	
	mat3 basis = mat3(MODELVIEW_MATRIX);
	vec3 scale = vec3(length(basis[0]), length(basis[1]), length(basis[2]));
	UV = UV * vec2(scale.z * SPRING_DENSITY_FACTOR, 1.0);
}


void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	ALBEDO = albedo.rgb * COLOR.rgb * albedo_tex.rgb;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(0.0,1.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	NORMAL_MAP = texture(texture_normal,base_uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	ALPHA *= albedo.a * albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	AO = dot(texture(texture_ambient_occlusion,base_uv),ao_texture_channel);
	AO_LIGHT_AFFECT = ao_light_affect;
}
