// Holds the logic to apply translation and orbitation offsets of selected objects
// Is used in combination with TransformGizmo

#include "float_operations.gdshaderinc"
#include "instance_state.gdshaderinc"

// atom selection movement shift
uniform vec3 selection_delta = vec3(0,0,0);
uniform vec3 gizmo_origin;
uniform mat4 gizmo_rotation;

float _can_apply_offset(vec4 color) {
	return is_atom_or_bond_selected(color.a);
}


// Usage:
// VERTEX += get_rotation_delta(COLOR, MODEL_MATRIX);
vec3 get_rotation_delta(vec4 color, mat4 model_mat) {
	vec3 local_parent_pos = (inverse(model_mat) * vec4(gizmo_origin, 1.0)).xyz;
	vec3 delta_from_model_to_gizmo = -local_parent_pos;
	vec4 modelRotatedPos = gizmo_rotation * vec4(delta_from_model_to_gizmo, 1.0);
	vec3 new_model_origin = local_parent_pos.xyz + modelRotatedPos.xyz;
	return new_model_origin * _can_apply_offset(color);
}

// Usage;
// VERTEX += get_bond_rotation_delta(VERTEX, COLOR, MODEL_MATRIX);
vec3 get_bond_rotation_delta(vec3 vertex, vec4 color, mat4 model_mat) {
	float left_active = is_first_atom_selected(color.a);
	float right_active = is_second_atom_selected(color.a);
	vec4 local_parent_pos = (inverse(model_mat) * vec4(gizmo_origin, 1.0));
	vec3 vertex_global_pos = (model_mat * vec4(vertex, 1.0)).xyz;
	vec4 global_delta_from_gizmo_to_vertex = vec4(vertex_global_pos, 1.0) - vec4(gizmo_origin, 1.0);
	vec4 rotated_global_pos = gizmo_rotation * global_delta_from_gizmo_to_vertex;
	vec4 rotated_local_pos = (inverse(model_mat) * vec4(rotated_global_pos));
	vec4 transformed_final_local_pos = rotated_local_pos + local_parent_pos;
	vec3 transform_delta = transformed_final_local_pos.xyz - vertex;
	return left_active * right_active * transform_delta;
}

// Usage:
// VERTEX += get_translation_delta(COLOR, MODEL_MATRIX);
vec3 get_translation_delta(vec4 color, mat4 model_mat) {
	vec4 delta_pos_in_object_space = inverse(model_mat) * vec4(selection_delta, 0.0) * _can_apply_offset(color);
	return delta_pos_in_object_space.xyz;
}

// Usage;
// VERTEX += get_bond_translation_delta(VERTEX, COLOR, MODEL_MATRIX);
vec3 get_bond_translation_delta(vec3 vertex, vec4 color, mat4 model_mat) {
	float left_active = is_first_atom_selected(color.a);
	float right_active = is_second_atom_selected(color.a);
	//factor is -1 on the left side, 0.5 in the middle  and 1.0 at right side
	//	float factor = 0.0;
	//	if (left_active == 1.0) {
	//		factor = vertex_position.z - 0.5;
	//	}
	//	if (right_active == 1.0) {
	//		factor = vertex_position.z + 0.5;
	//	}
	//	if (left_active == 1.0 && right_active == 1.0) {
	//		factor = 1.0;
	//	}
	//	The logic below does the same as the comment in more gpu friendly way
	float left_step = step(0.9, left_active);
	float right_step = step(0.9, right_active);
	float both_movement_factor = 1.0 * left_step * right_step;
	float left_movement_factor = (vertex.z - 0.5) * left_step;
	float right_movement_factor = (vertex.z + 0.5) * right_step;
	float factor = both_movement_factor + float_neq(left_step, right_step) * (left_movement_factor + right_movement_factor);
	vec4 delta_pos_in_object_space = inverse(model_mat) * vec4(selection_delta * factor, 0.0) * left_active * right_active;
	return delta_pos_in_object_space.xyz;
}
