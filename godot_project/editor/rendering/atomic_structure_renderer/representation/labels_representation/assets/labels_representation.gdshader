// NOTE: Shader automatically converted from Godot Engine 4.0.3.stable's StandardMaterial3D.
shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx, unshaded;

#include "res://editor/rendering/atomic_structure_renderer/representation/hydrogens.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/gizmo_transform_delta.gdshaderinc"

// determines the relationship between atom size and label size
const float LABEL_SCALE = 0.6;

// our atlas have 11 * 11 regions, one region takes this much % from the whole atlas
//const float ROW_COUNT = 11.0; // commented because unused
const float COLUMN_COUNT = 11.0;
const float region_percent_size = 1.0 / COLUMN_COUNT; 
const vec2 region_percent_size_vec = vec2(region_percent_size);

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float distance_fade_min;
uniform float distance_fade_max;

// camera info
uniform vec3 camera_forward_vector;
uniform vec3 camera_up_vector;
uniform vec3 camera_right_vector;
uniform float camera_size;

// atom scale
uniform float scale = 1.0;

varying vec2 detail_uv;

void vertex() {
	
	mat4 inv_model_mat = inverse(MODEL_MATRIX);
	vec3 model_origin_pos_in_world_space = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 model_to_camera = normalize(CAMERA_POSITION_WORLD - model_origin_pos_in_world_space);

	// Calculate rotation matrix to align model with camera
	mat4 billboard_rot = mat4(
		vec4(normalize(camera_right_vector), 0.0),
		vec4(normalize(camera_up_vector), 0.0),
		vec4(model_to_camera, 0.0), // Already normalized
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	
	VERTEX = (billboard_rot * vec4(VERTEX, 1.0)).xyz;
	
	// apply scale
	VERTEX *= scale * LABEL_SCALE;
	
	// apply rotation
	VERTEX += get_rotation_delta(COLOR, MODEL_MATRIX);
	
	// apply translation delta
	VERTEX += get_translation_delta(COLOR, MODEL_MATRIX);
	
	// move a bit in front of the atoms
	vec3 localCameraFacingVector = (inv_model_mat * vec4(camera_forward_vector, 0.0)).xyz;
	float atom_radius = COLOR.b;
	// determined experimentally by checking how small and big atom's labels are behaving on minimal and maximal scale
	float additional_distance_factor = 0.12 * scale - atom_radius * scale * 0.12;
	VERTEX += normalize(localCameraFacingVector) * (atom_radius * scale + additional_distance_factor);
	
	
	// use proper atlas region
	float id = COLOR.g;
	vec2 delta = vec2( mod(id, COLUMN_COUNT) , floor(id / COLUMN_COUNT));
	const float UNLOCKED_ID = 119.0; // A fully empty quadrant in the atlas
	const float LOCKED_ID = 120.0;   // A quadrant with an Anchor "⚓" symbol drawn on it
	float detail_id = mix(UNLOCKED_ID, LOCKED_ID, is_atom_locked(COLOR.a));
	vec2 detail_coord = vec2(mod(detail_id, COLUMN_COUNT), floor(detail_id / COLUMN_COUNT));
	detail_uv = UV * region_percent_size_vec + detail_coord * region_percent_size;
	UV = UV * region_percent_size_vec + delta * region_percent_size;
	VERTEX = hide_hydrogen_labels(VERTEX, id);
	VERTEX *= is_atom_or_bond_visible(COLOR.a);
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	vec4 detail_tex = texture(texture_albedo,detail_uv);
	albedo_tex = mix(albedo_tex, detail_tex, detail_tex.a);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	ALPHA *= albedo.a * albedo_tex.a;
	
	float distance_fade_perspective = clamp(smoothstep(distance_fade_min, distance_fade_max, length(VERTEX)), 0.0, 1.0);
	float fade_min_orthogonal = distance_fade_min * 0.3;
	float fade_max_orthogonal = distance_fade_max * 0.3;
	float distance_fade_orthogonal = clamp(smoothstep(fade_min_orthogonal, fade_max_orthogonal, camera_size), 0.0, 1.0);
	float is_orthogonal = PROJECTION_MATRIX[3][3];
	ALPHA *= mix(distance_fade_perspective, distance_fade_orthogonal, is_orthogonal);
}
