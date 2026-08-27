shader_type spatial;
render_mode cull_back, unshaded;

#include "res://editor/rendering/atomic_structure_renderer/representation/float_operations.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/constants.gdshaderinc"
#include "res://editor/rendering/atomic_structure_renderer/representation/instance_state.gdshaderinc"

// Wireframe shader with line thickness support.
//
// This shader only works on flat shaded meshes. The VERTEX_ID from the vertex()
// function is not reliable with smooth meshes.
//
// Modified from https://godotshaders.com/shader/wireframe-shader-godot-4-0/

instance uniform float selectable :hint_range(0.0, 1.0) = 1.0;
instance uniform float selected : hint_range(0.0, 1.0) = 0.0;
instance uniform float hovered : hint_range(0.0, 1.0) = 0.0;

uniform float default_wire_width : hint_range(0.0, 10.0) = 1.2;
uniform float hovered_wire_width : hint_range(0.0, 10.0) = 2.4;

global uniform vec4 reference_shape_wireframe_color;
global uniform vec4 reference_shape_selected_wireframe_color;
global uniform vec4 reference_shape_hovered_wireframe_color;

varying vec3 barys;
varying float is_preview;


void vertex() {
	int index = VERTEX_ID % 3;
	barys = vec3(0.0);
	barys[index] = 1.0;
	
	//selection preview
	is_preview = _unpack_flag(SELECTION_PREVIEW_VISUAL_LAYER, int(CAMERA_VISIBLE_LAYERS));
	VERTEX *= float_or(float_not(is_preview), selected);
}


void fragment() {
	vec4 color = mix(reference_shape_wireframe_color * 0.5, reference_shape_wireframe_color, selectable);
	color = mix(color, reference_shape_selected_wireframe_color, selected);
	float use_hover_color = float_and(hovered, float_not(is_preview));
	color = mix(color, reference_shape_hovered_wireframe_color, use_hover_color);
	ALBEDO = color.rgb;
	
	// Change the wireframe width based on the hover state
	float wire_width = mix(default_wire_width, hovered_wire_width, use_hover_color);
	
	// For anti-aliasing purposes
	float epsilon = fwidth(UV.x * UV.y);
	
	// Calculate which fragment is close enough to an edge and hide everything else
	vec3 deltas = fwidth(barys);
	vec3 barys_s = smoothstep(deltas * wire_width - epsilon, deltas * wire_width + epsilon, barys);
	float is_wireframe = min(barys_s.x, min(barys_s.y, barys_s.z));
	ALPHA = color.a * (1.0 - is_wireframe);
}