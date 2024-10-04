extends Node3D


var _mesh: MeshInstance3D


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_mesh = $RingMenu_TextCircle
		assert(_mesh.get_layer_mask_value(RingMenu3D.LIGHT_LAYER_HIGHLIGHT), "VisualInstance has lost it's layer")


