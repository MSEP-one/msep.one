class_name SpringSelectionPreview extends Node3D
## Responsible for presenting springs in selection preview panel

var _multimesh: MultiMesh
var _particles_transforms: Array[Transform3D] = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_multimesh = $MultiMeshInstance3D.multimesh


func clear() -> void:
	_multimesh.visible_instance_count = 0
	_multimesh.instance_count = 0
	_particles_transforms.clear()


func add(in_atom_positions: PackedVector3Array, in_anchor_positions: PackedVector3Array) -> void:
	assert(in_atom_positions.size() == in_anchor_positions.size())
	var new_particle_count: int = in_atom_positions.size()
	for idx: int in new_particle_count:
		var atom_pos: Vector3 = in_atom_positions[idx]
		var anchor_pos: Vector3 = in_anchor_positions[idx]
		var direction_to_atom: Vector3 = anchor_pos.direction_to(atom_pos)
		var anchor_radius: float = NanoVirtualAnchor.MODEL_SIZE * 0.5
		anchor_pos += direction_to_atom * anchor_radius
		var distance: float = atom_pos.distance_to(anchor_pos)
		var spring_transform := Transform3D(Basis(), atom_pos)
		var spring_scale: Vector3 = Vector3(SpringRenderer.MODEL_THICKNESS, SpringRenderer.MODEL_THICKNESS, distance)
		spring_transform = spring_transform.looking_at(anchor_pos).scaled_local(spring_scale)
		_particles_transforms.append(spring_transform)


func render() -> void:
	var nmb_of_particles: int = _particles_transforms.size()
	if _multimesh.instance_count < nmb_of_particles:
		_multimesh.instance_count = nmb_of_particles
	_multimesh.visible_instance_count = nmb_of_particles
	for idx: int in nmb_of_particles:
		_multimesh.set_instance_transform(idx, _particles_transforms[idx])
