// Holds the logic to detect and hide hydrogen atoms
#include "constants.gdshaderinc"
#include "float_operations.gdshaderinc"


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

float _is_hydrogen_atom(vec3 color){
	float is_dimmed_hydrogen = _is_in_range(color, HYDROGEN_ATOM_COLOR);
	float is_hydrogen = _is_in_range(color, HYDROGEN_ATOM_COLOR);
	return float_or(is_dimmed_hydrogen, is_hydrogen);
}


float _is_hydrogen_bond_end(vec3 color){
	float is_dimmed_hydrogen = _is_in_range(color,HYDROGEN_BOND_COLOR * DIMM_FACTOR);
	float is_unselected_hydrogen = _is_in_range(color, HYDROGEN_BOND_COLOR);
	float is_selected_hydrogen = _is_in_range(color, HYDROGEN_BOND_COLOR * BOND_HIGHLIGHT_FACTOR);
	return float_or_3(is_dimmed_hydrogen, is_unselected_hydrogen, is_selected_hydrogen);
}

float _should_hide_hydrogen_atom(vec3 color) {
	return float_and(_is_hydrogen_atom(color), float_not(show_hydrogens));
}


float _should_hide_hydrogen_bond(vec3 color_1, vec3 color_2) {
	float is_hydrogen_bond = float_or(_is_hydrogen_bond_end(color_1), _is_hydrogen_bond_end(color_2));
	return float_and(is_hydrogen_bond, float_not(show_hydrogens));
}

float _should_hide_hydrogen_label(float element_id) {
	float is_hydrogen_label = float_eq(element_id, HYDROGEN_LABEL_ID);
	return float_and(is_hydrogen_label, float_not(show_hydrogens));
}

float _should_hide_hydrogen_spring(float color_alpha) {
	float is_hydrogen_spring = float_eq(color_alpha, HYDROGEN_SPRING_ALPHA);
	return float_and(is_hydrogen_spring, float_not(show_hydrogens));
}


// Usage:
// VERTEX = hide_hydrogen_atoms(VERTEX, COLOR.rgb);
vec3 hide_hydrogen_atoms(vec3 vertex, vec3 color) {
	return vertex - vertex * _should_hide_hydrogen_atom(color);
}


// Usage:
// VERTEX = hide_hydrogen_bonds(VERTEX, COLOR.rgb, INSTANCE_CUSTOM.rgb);
vec3 hide_hydrogen_bonds(vec3 vertex, vec3 color_1, vec3 color_2) {
	return vertex - vertex * _should_hide_hydrogen_bond(color_1, color_2);
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
