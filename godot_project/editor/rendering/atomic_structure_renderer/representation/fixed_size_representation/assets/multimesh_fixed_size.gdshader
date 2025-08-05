shader_type spatial;
render_mode unshaded;

#include "res://editor/rendering/atomic_structure_renderer/representation/gizmo_transform_delta.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/hydrogens.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/selectable.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/billboard.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/outlines.gdshaderinc"

const float COLOR_ADDITIONAL_POWER = 0.05;

uniform float size = 1.0;


void vertex() {
	// Fixed Size
	float sc = 0.0;
	if (PROJECTION_MATRIX[3][3] != 0.0) {
		// Orthogonal matrix; try to do about the same with viewport size.
		float h = abs(1.0 / (2.0 * PROJECTION_MATRIX[1][1]));
		// Consistent with vertical FOV (Keep Height).
		sc = (h * 2.0) * size * 8.0;
		MODELVIEW_MATRIX[0] *= sc;
		MODELVIEW_MATRIX[1] *= sc;
		MODELVIEW_MATRIX[2] *= sc;
	} else {
		// Scale by depth.
		sc = -(MODELVIEW_MATRIX)[3].z * size;
		MODELVIEW_MATRIX[0] *= sc;
		MODELVIEW_MATRIX[1] *= sc;
		MODELVIEW_MATRIX[2] *= sc;
	}

	VERTEX = hide_hydrogen_atoms(VERTEX, COLOR.a);
	COLOR.rgb = apply_selectable_dimming(COLOR).rgb;

	vec3 final_vertex = billboard_atom(VERTEX, INV_VIEW_MATRIX);
	final_vertex += get_rotation_delta(COLOR, MODEL_MATRIX) / sc;
	final_vertex += get_translation_delta(COLOR, MODEL_MATRIX) / sc;
	final_vertex *= is_atom_or_bond_visible(COLOR.a);
	VERTEX = final_vertex;

	float is_preview = _unpack_flag(SELECTION_PREVIEW_VISUAL_LAYER, int(CAMERA_VISIBLE_LAYERS));
	is_instance_hovered = float_and(is_atom_or_bond_hovered(COLOR.a), float_not(is_preview));
	is_outline = 1.0;
}


void fragment() {
	vec4 albedo = COLOR;
	float strength = 1.5 + is_instance_hovered;

	ALBEDO = albedo.rgb + albedo.rgb * COLOR_ADDITIONAL_POWER;
	ALBEDO *= strength;

	vec3 outline_color = calculate_outline_color(ALBEDO, COLOR);
	float is_selected = float(is_atom_or_bond_selected(COLOR.a));
	ALBEDO = mix(ALBEDO, outline_color, is_selected);
}