class_name VirtualAnchorModel extends Node3D

var _materials: Array[ShaderMaterial]
var _model: SpringModel

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		# Initialize Materials
		_materials = []
		_model = $SpringModel
		_seek_materials_recursively(_model)


func _seek_materials_recursively(out_node: Node) -> void:
	var mesh_instance: MeshInstance3D = out_node as MeshInstance3D
	if is_instance_valid(mesh_instance) and is_instance_valid(mesh_instance.mesh):
		for i: int in mesh_instance.mesh.get_surface_count():
			var mat: Material = mesh_instance.mesh.surface_get_material(i)
			assert(mat is ShaderMaterial, "Did not replace material of %s:material[%d]" % [get_path_to(mesh_instance), i])
			var shader_mat: ShaderMaterial = mat.duplicate() as ShaderMaterial
			assert(RenderingUtils.has_uniform(shader_mat, "is_hovered"),
					"Missing uniform 'is_hovered' in %s:material[%d]" % [get_path_to(mesh_instance), i])
			assert(RenderingUtils.has_uniform(shader_mat, "is_selected"),
					"Missing uniform 'is_selected' in %s:material[%d]" % [get_path_to(mesh_instance), i])
			mesh_instance.set_surface_override_material(i, shader_mat)
			_materials.push_back(shader_mat)
	# recursively seek
	for child: Node in out_node.get_children():
		_seek_materials_recursively(child)


func _set_shader_uniform(in_uniform: StringName, in_value: Variant) -> void:
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter(in_uniform, in_value)


func _get_shader_uniform(in_uniform: StringName) -> Variant:
	return _materials[0].get_shader_parameter(in_uniform)


func show_in_selection_preview() -> void:
	_model.show_in_selection_preview()


func hide_from_selection_preview() -> void:
	_model.hide_from_selection_preview()
