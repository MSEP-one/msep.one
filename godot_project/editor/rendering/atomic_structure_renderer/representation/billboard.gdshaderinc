// Usage
// VERTEX = billboard_atom(VERTEX, INV_VIEW_MATRIX);
vec3 billboard_atom(vec3 vertex, mat4 inv_view_matrix) {
	// Calculate rotation matrix to align model with camera
	vec3 camera_right = normalize(inv_view_matrix[0].xyz);
	vec3 camera_up = normalize(inv_view_matrix[1].xyz);
	mat4 billboard_rot = mat4(
		vec4(camera_right, 0.0),
		vec4(camera_up, 0.0),
		vec4(normalize(cross(camera_right, camera_up)), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	
	// Transform the vertex using the billboard rotation
	return (billboard_rot * vec4(vertex, 1.0)).xyz;
}