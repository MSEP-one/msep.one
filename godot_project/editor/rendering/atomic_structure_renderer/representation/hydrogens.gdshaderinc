// Holds the logic to detect and hide hydrogen atoms
#include "constants.gdshaderinc"
#include "float_operations.gdshaderinc"
#include "instance_state.gdshaderinc"


const float HYDROGEN_LABEL_ID = 0.0;
const vec3 HYDROGEN_ATOM_COLOR = vec3(0.549,  0.471,   0.0);
const vec3 HYDROGEN_BOND_COLOR = vec3(1.0,    0.7843,  0.0);
const float HYDROGEN_SPRING_ALPHA = 0.1;

uniform float show_hydrogens: hint_range(0.0, 1.0, 1.0) = 1.0;

float _is_in_range(vec3 point, vec3 target) {
	vec3 minRange = target - vec3(0.01);
	vec3 maxRange = target + vec3(0.01);
	return float(all(lessThanEqual(minRange, point)) && all(lessThanEqual(point, maxRange)));
}

float _should_hide_hydrogen_atom(float alpha) {
	return float_and(is_hydrogen(alpha), float_not(show_hydrogens));
}


float _should_hide_hydrogen_bond(float alpha_1, float alpha_2) {
	float is_hydrogen_bond = float_or(is_hydrogen(alpha_1), is_hydrogen(alpha_2));
	return float_and(is_hydrogen_bond, float_not(show_hydrogens));
}

float _should_hide_hydrogen_label(float element_id) {
	float is_hydrogen_label = float_eq(element_id, HYDROGEN_LABEL_ID);
	return float_and(is_hydrogen_label, float_not(show_hydrogens));
}

float _should_hide_hydrogen_spring(float color_alpha) {
	float is_hydrogen_spring = is_hydrogen(color_alpha);
	return float_and(is_hydrogen_spring, float_not(show_hydrogens));
}

// Usage:
// VERTEX = hide_hydrogen_atoms(VERTEX, COLOR.a);
vec3 hide_hydrogen_atoms(vec3 vertex, float color_alpha) {
	return vertex - vertex * _should_hide_hydrogen_atom(color_alpha);
}


// Usage:
// VERTEX = hide_hydrogen_bonds(VERTEX, COLOR.a, INSTANCE_CUSTOM.a);
vec3 hide_hydrogen_bonds(vec3 vertex, float alpha_1, float alpha_2) {
	return vertex - vertex * _should_hide_hydrogen_bond(alpha_1, alpha_2);
}


// Usage:
// VERTEX = hide_hydrogen_labels(VERTEX, element_id);
vec3 hide_hydrogen_labels(vec3 vertex, float element_id) {
	return vertex - vertex * _should_hide_hydrogen_label(element_id);
}

// Usage:
// VERTEX = hide_hydrogen_springs(VERTEX, COLOR.a);
vec3 hide_hydrogen_springs(vec3 vertex, float color_a) {
	return vertex - vertex * _should_hide_hydrogen_spring(color_a);
}
