// NOTE: Shader automatically converted from Godot Engine 4.0.3.stable's StandardMaterial3D.

shader_type spatial;

render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,vertex_lighting;

#include "res://editor/rendering/atomic_structure_renderer/representation/hydrogens.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/outlines.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/gizmo_transform_delta.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/selectable.gdshaderinc"

// atom selection movement shift
uniform vec3 camera_up_vector;
uniform vec3 camera_right_vector;

uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform float specular;
uniform float metallic;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;


void vertex() {
	// Hide hydrogens if necesary
	// SingleAtomRepresentation uses bond color for atoms instead of atom color
	// Because of that we use hide_hydrogen_bonds() instead
	VERTEX = hide_hydrogen_bonds(VERTEX, COLOR.a, INSTANCE_CUSTOM.a);
	COLOR.rgb = apply_selectable_dimming(COLOR).rgb;
	
	
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
	}
	
	// COLOR.a > 2.0 always means the atom is selected	

	// Make the outline mesh visible if the atom is selected
	is_outline = uv_is_outline(UV);
	is_instance_hovered = is_atom_or_bond_hovered(COLOR.a);
	VERTEX += calculate_outline_displacement(VERTEX, UV, MODEL_MATRIX, CAMERA_POSITION_WORLD, COLOR, 1.0);
	
	// Calculate rotation matrix to align model with camera
	mat4 billboard_rot = mat4(
		vec4(normalize(camera_right_vector), 0.0),
		vec4(normalize(camera_up_vector), 0.0),
		vec4(cross(normalize(camera_right_vector), normalize(camera_up_vector)), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	
	// Transform the vertex using the billboard rotation
	vec3 final_vertex = (billboard_rot * vec4(VERTEX, 1.0)).xyz;

	//apply rotation
	final_vertex += get_rotation_delta(COLOR, MODEL_MATRIX);

	//apply translation delta
	final_vertex += get_translation_delta(COLOR, MODEL_MATRIX);
	
	final_vertex *= is_atom_or_bond_visible(COLOR.a);
	VERTEX = final_vertex;
	
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	MODELVIEW_NORMAL_MATRIX = mat3(inverse(MODEL_MATRIX));
	
}


void fragment() {
	vec2 base_uv = UV;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	
	ALBEDO = calculate_outline_color(COLOR.rgb, COLOR);
}
