class_name NanoParticleEmitter extends NanoStructure

signal transform_changed(new_transform: Transform3D)
signal parameters_changed(in_parameters: NanoParticleEmitterParameters)

const DEFAULT_ROTATION = Quaternion(Vector3.RIGHT, deg_to_rad(90))
const DEFAULT_TRANSFORM = Transform3D(Basis(DEFAULT_ROTATION))

@export var _transform := DEFAULT_TRANSFORM
@export var _parameters: NanoParticleEmitterParameters


func get_transform() -> Transform3D:
	return _transform


func set_transform(new_transform: Transform3D) -> void:
	if new_transform == _transform:
		return
	_transform = new_transform
	transform_changed.emit(new_transform)


func set_position(new_position: Vector3) -> void:
	if _transform.origin == new_position:
		return
	_transform.origin = new_position
	transform_changed.emit(_transform)


func get_position() -> Vector3:
	return _transform.origin


func set_parameters(new_parameters: NanoParticleEmitterParameters) -> void:
	if new_parameters == _parameters:
		return
	_parameters = new_parameters
	parameters_changed.emit(_parameters)


func get_parameters() -> NanoParticleEmitterParameters:
	return _parameters


func get_type() -> StringName:
	return &"ParticleEmitter"


func get_readable_type() -> String:
	return "Particle Emitter"


## Returns a texture to represent the structure in the UI, it can be a predefined
## icon or a thumbnail of the actual structure
func get_icon() -> Texture2D:
	return preload("res://editor/icons/MolecularStructure_x28.svg")


func get_aabb() -> AABB:
	var aabb := AABB(_transform.origin, Vector3())
	aabb = aabb.grow(0.5)
	return aabb.abs()


func is_particle_emitter_within_screen_rect(in_camera: Camera3D, screen_rect: Rect2i) -> bool:
	var emitter_screen_position: Vector2 = in_camera.unproject_position(_transform.origin)
	if screen_rect.abs().has_point(emitter_screen_position):
		return true
	return false


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = super.create_state_snapshot()
	state_snapshot["script.resource_path"] = get_script().resource_path
	state_snapshot["_transform"] = _transform
	state_snapshot["_parameters_snapshot"] = _parameters.create_state_snapshot()
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_state_snapshot)
	_transform = in_state_snapshot["_transform"]
	if _parameters == null:
		_parameters = NanoParticleEmitterParameters.new()
	_parameters.apply_state_snapshot(in_state_snapshot["_parameters_snapshot"])
