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

uniform float wire_width : hint_range(0.0, 10.0) = 0.8;

global uniform vec4 simulation_boundaries_wireframe_color;

varying vec3 barys;


void vertex() {
	int index = VERTEX_ID % 3;
	barys = vec3(0.0);
	barys[index] = 1.0;
	
}


void fragment() {
	vec4 color = simulation_boundaries_wireframe_color;
	ALBEDO = color.rgb;
	
	// For anti-aliasing purposes
	float epsilon = fwidth(UV.x * UV.y);
	
	// Calculate which fragment is close enough to an edge and hide everything else
	vec3 deltas = fwidth(barys);
	vec3 barys_s = smoothstep(deltas * wire_width - epsilon, deltas * wire_width + epsilon, barys);
	float is_wireframe = min(barys_s.x, min(barys_s.y, barys_s.z));
	ALPHA = color.a * (1.0 - is_wireframe);
}