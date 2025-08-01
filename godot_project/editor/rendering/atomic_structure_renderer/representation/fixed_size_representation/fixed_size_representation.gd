class_name FixedSizeRepresentation
extends SphereRepresentation

static var FixedSizeMaterial: SphereMaterial = load("res://editor/rendering/atomic_structure_renderer/representation/fixed_size_representation/assets/multimesh_fixed_size_material.tres")


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_material = FixedSizeMaterial.duplicate()
		_segmented_multimesh = $SegmentedMultiMesh
		_segmented_multimesh.set_material_override(_material)


func apply_theme(_in_theme: Theme3D) -> void:
	# Far away atoms will look the same regardless of the theme (but will still
	# respect the atoms colors). The parent function will override the fixed
	# size material, so it's not called.
	var is_built: bool = _workspace_context != null
	if is_built:
		_update_is_selectable_uniform()
