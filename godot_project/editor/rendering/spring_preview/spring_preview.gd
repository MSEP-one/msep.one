class_name SpringPreview extends Node3D


@onready var _multimesh: MultiMesh = $MultiMeshInstance3D.multimesh
var _anchor_position: Vector3


func show_preview() -> void:
	show()


func hide_preview() -> void:
	hide()


func set_end_position(new_anchor_position: Vector3) -> void:
	_anchor_position = new_anchor_position


func update(in_atom_positions: PackedVector3Array, new_anchor_position: Vector3 = _anchor_position) -> void:
	_anchor_position = new_anchor_position
	
	var nmb_of_springs: int = in_atom_positions.size()
	if _multimesh.instance_count < nmb_of_springs:
		_multimesh.instance_count = nmb_of_springs
	if _multimesh.instance_count > nmb_of_springs * 1.5:
		_multimesh.instance_count = nmb_of_springs
	_multimesh.visible_instance_count = nmb_of_springs
	
	for particle_idx: int in nmb_of_springs:
		var start_pos: Vector3 = in_atom_positions[particle_idx]
		var direction_to_atom: Vector3 = _anchor_position.direction_to(start_pos)
		var anchor_radius: float = NanoVirtualAnchor.MODEL_SIZE * 0.5
		var end_pos: Vector3 = _anchor_position + direction_to_atom * anchor_radius
		var distance: float = start_pos.distance_to(end_pos)
		var spring_transform := Transform3D(Basis(), start_pos)
		var spring_scale: Vector3 = Vector3(SpringRenderer.MODEL_THICKNESS, SpringRenderer.MODEL_THICKNESS, distance)
		spring_transform = spring_transform.looking_at(end_pos).scaled_local(spring_scale)
		_multimesh.set_instance_transform(particle_idx, spring_transform)

