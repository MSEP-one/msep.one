class_name SpringModel extends Node3D


var _mesh_instance: MeshInstance3D


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_mesh_instance = $Circle


func show_in_selection_preview() -> void:
	_mesh_instance.set_layer_mask_value(Rendering.SELECTION_PREVIEW_LAYER_BIT, true)


func hide_from_selection_preview() -> void:
	_mesh_instance.set_layer_mask_value(Rendering.SELECTION_PREVIEW_LAYER_BIT, false)
