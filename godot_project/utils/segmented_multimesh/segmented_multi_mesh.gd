class_name SegmentedMultimesh extends Node

const SEGMENT_SIZE = 2.5
const _SEGMENT_REBUILD_ABOVE_UNUSED_PARTICLES_COUNT = 250

@export var multimesh: MultiMesh
@export var use_custom_data: bool = false
@export_range(0, 128) var _lod_bias: float = 1.0
@export var _material_override: Material = null
@export var _mesh_override: Mesh = null
@export var _visible: bool = true
@export var update_segments_on_movement: bool = false
@export_flags_3d_render var visual_layers: int = 1

var _id_to_segment_map := {
	#Vector3i : Segment
}
var _external_id_to_particle: Dictionary = {
	#<int> : <Particle>
}
var _segments_to_rebuild: Dictionary = {
	#id<Vector3i> : true<bool>
}

var _instance_uniforms: Dictionary = {
#	uniform_property_path<StringName> = value<Variant>
}

var _is_initialized: bool = false
var _queued_particles_to_removal: Array[Particle] = []
var _material_overlay: Material
var _transparency: float = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_POSTINITIALIZE:
		if is_instance_valid(_mesh_override):
			multimesh.mesh = _mesh_override


func _process(_in_delta_time: float) -> void:
	# just in case, if we will find good use case we can remove it
	assert(_segments_to_rebuild.is_empty(), "Probably new atoms were added but 'rebuild_if_needed()' was never called")
	assert(_queued_particles_to_removal.is_empty(), "Particles removal queued but apply_queued_removals() was never called")
	return


func set_material_override(in_material: Material) -> SegmentedMultimesh:
	_material_override = in_material
	for segment: Segment in _id_to_segment_map.values():
		assert(segment, "Invalid value %s in _id_to_segment_map" % [str(segment)])
		segment.multimesh_instance.material_override = _material_override
	return self


func get_material_override() -> Material:
	return _material_override


func set_mesh_override(in_mesh: Mesh) -> SegmentedMultimesh:
	_mesh_override = in_mesh
	if is_instance_valid(multimesh):
		multimesh.mesh = _mesh_override
	for segment: Segment in _id_to_segment_map.values():
		assert(segment, "Invalid value %s in _id_to_segment_map" % [str(segment)])
		segment.multimesh_instance.multimesh.mesh = _mesh_override
	return self


func set_material_instance_uniform(in_uniform_name: StringName, in_value: Variant) -> SegmentedMultimesh:
	var uniform_property_path: StringName = "instance_shader_parameters/" + in_uniform_name
	_instance_uniforms[uniform_property_path] = in_value
	for segment: Segment in _id_to_segment_map.values():
		segment.multimesh_instance.set(uniform_property_path, in_value)
	return self


func set_bias(new_bias: float) -> SegmentedMultimesh:
	_lod_bias = new_bias
	for segment: Segment in _id_to_segment_map.values():
		assert(segment, "Invalid value %s in _id_to_segment_map" % [str(segment)])
		segment.multimesh_instance.lod_bias = _lod_bias
	return self


func get_particle_color(in_external_id: int) -> Color:
	var particle_data: Particle = _external_id_to_particle[in_external_id]
	return particle_data.color


func get_particle_additional_data(in_external_id: int) -> Color:
	var particle_data: Particle = _external_id_to_particle[in_external_id]
	return particle_data.additional_data


func set_transparency(in_transparency: float) -> SegmentedMultimesh:
	_transparency = in_transparency
	for segment: Segment in _id_to_segment_map.values():
		segment.multimesh_instance.transparency = in_transparency
	return self


func prepare() -> void:
	for child in get_children():
		child.queue_free()
	_id_to_segment_map.clear()
	_segments_to_rebuild.clear()
	_external_id_to_particle.clear()


func bake() -> void:
	var segments_ids: Array = _id_to_segment_map.keys()
	for segment_id: Vector3i in segments_ids:
		_rebuild_segment(_id_to_segment_map[segment_id])
	_segments_to_rebuild.clear()
	set_bias(_lod_bias)
	_is_initialized = true


## needs to be called directly after new particles has been added
func rebuild_if_needed() -> void:
	if not _is_initialized:
		return
	if is_queued_for_deletion():
		return
	for segment_id: Vector3i in _segments_to_rebuild:
		var segment: Segment = _id_to_segment_map[segment_id]
		_rebuild_segment(segment)
	_segments_to_rebuild.clear()


func _rebuild_segment(in_segment: Segment) -> void:
	var segment_multimesh: MultiMesh = in_segment.multimesh_instance.multimesh
	var multimesh_instance: MultiMeshInstance3D = in_segment.multimesh_instance
	multimesh_instance.multimesh.instance_count = in_segment.particles_in_segment.size()
	multimesh_instance.multimesh.visible_instance_count = in_segment.particles_in_segment.size()
	multimesh_instance.material_overlay = _material_overlay
	segment_multimesh.instance_count = in_segment.particles_in_segment.size()
	for particle in in_segment.particles_in_segment:
		_apply_particle_data(in_segment, particle)


func set_material_overlay(in_material_overlay: Material) -> void:
	_material_overlay = in_material_overlay
	for segment: Segment in _id_to_segment_map.values():
		assert(segment, "Invalid value %s in _id_to_segment_map" % [str(segment)])
		segment.multimesh_instance.material_overlay = in_material_overlay


func _apply_particle_data(in_segment: Segment, in_particle_to_apply: Particle) -> void:
	var segment_multimesh: MultiMesh = in_segment.multimesh_instance.multimesh
	var multimesh_instance: MultiMeshInstance3D = in_segment.multimesh_instance
	var particle_transform: Transform3D = in_particle_to_apply.global_transform
	var final_transform: Transform3D = multimesh_instance.transform.inverse() * particle_transform
	segment_multimesh.set_instance_transform(in_particle_to_apply.id, final_transform)
	segment_multimesh.set_instance_color(in_particle_to_apply.id, in_particle_to_apply.color)
	if use_custom_data:
		segment_multimesh.set_instance_custom_data(in_particle_to_apply.id, in_particle_to_apply.additional_data)


## Adds new particle to rendering.
## Returns ID of this particle which can be used to update the particle state
func add_particle(in_external_id: int, in_transform: Transform3D, in_color: Color, in_additional_data: Color) -> void:
	var segment: Segment = _get_segment_from_position(in_transform.origin)
	var particle: Particle = _get_initialized_particle_for_segment(segment)
	particle.global_transform = in_transform
	particle.color = in_color
	particle.additional_data = in_additional_data
	if _is_initialized:
		_segments_to_rebuild[segment.id] = true
	
	assert(not _external_id_to_particle.has(in_external_id), "This external id is known, the same external id
			cannot be added twice without removing it first")
	_external_id_to_particle[in_external_id] = particle


func _get_initialized_particle_for_segment(in_segment: Segment) -> Particle:
	var are_particles_waiting_to_be_reused: bool = not in_segment.free_particle_ids_pool.is_empty()
	if are_particles_waiting_to_be_reused:
		var particle_id: int = in_segment.free_particle_ids_pool.pop_back()
		var particle: Particle = in_segment.particles_in_segment[particle_id]
		particle.enabled = true
		return particle

	var new_particle: Particle = Particle.new(in_segment.id, in_segment.particles_in_segment.size())
	in_segment.particles_in_segment.append(new_particle)
	return new_particle


func _get_segment_from_position(in_position: Vector3) -> Segment:
	var segment_id: Vector3i = Vector3i((in_position / SEGMENT_SIZE).round())
	return _get_segment_from_id(segment_id)


func _get_segment_from_id(in_segment_id: Vector3i) -> Segment:
	if _id_to_segment_map.has(in_segment_id):
		return _id_to_segment_map[in_segment_id]
	else:
		return _create_segment_from_id(in_segment_id)


func _create_segment_from_id(in_segment_id: Vector3i) -> Segment:
	assert(not _id_to_segment_map.has(in_segment_id))
	var new_segment := Segment.new()
	new_segment.id = in_segment_id
	new_segment.multimesh_instance = MultiMeshInstance3D.new()
	new_segment.multimesh_instance.layers = visual_layers
	new_segment.multimesh_instance.multimesh = multimesh.duplicate(true)
	new_segment.multimesh_instance.lod_bias = _lod_bias
	new_segment.multimesh_instance.visible = _visible
	new_segment.multimesh_instance.material_overlay = _material_overlay
	new_segment.multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	new_segment.multimesh_instance.material_override = _material_override
	new_segment.multimesh_instance.transparency = _transparency
	for uniform_property_path: StringName in _instance_uniforms.keys():
		new_segment.multimesh_instance.set(uniform_property_path, _instance_uniforms[uniform_property_path])
	_id_to_segment_map[in_segment_id] = new_segment
	new_segment.multimesh_instance.position = Vector3(in_segment_id) * SEGMENT_SIZE
	add_child(new_segment.multimesh_instance)
	return new_segment


func show() -> void:
	_set_visible(true)


func hide() -> void:
	_set_visible(false)


func _set_visible(in_visible: bool) -> void:
	_visible = in_visible
	for segment: Segment in _id_to_segment_map.values():
		assert(segment, "Invalid value %s in _id_to_segment_map" % [str(segment)])
		segment.multimesh_instance.visible = in_visible


func is_external_id_known(in_external_id: int) -> bool:
	return _external_id_to_particle.has(in_external_id)


func update_particle(in_external_id: int, new_transform: Transform3D, new_color: Color) -> void:
	var particle_data: Particle = _ensure_particle_in_proper_segment(in_external_id, new_transform.origin)
	var segment: Segment = _id_to_segment_map[particle_data.segment_id]
	particle_data.global_transform = new_transform
	particle_data.color = new_color
	if not _segments_to_rebuild.has(segment.id):
		_apply_particle_data(segment, particle_data)


func update_particle_position(in_external_id: int, new_translation: Vector3) -> void:
	var particle_data: Particle = _ensure_particle_in_proper_segment(in_external_id, new_translation)
	var segment: Segment = _id_to_segment_map[particle_data.segment_id]
	particle_data.global_transform.origin = new_translation
	if not _segments_to_rebuild.has(segment.id):
		_apply_particle_data(segment, particle_data)


func update_particle_transform(in_external_id: int, new_transform: Transform3D) -> void:
	var particle_data: Particle = _ensure_particle_in_proper_segment(in_external_id, new_transform.origin)
	var segment: Segment = _id_to_segment_map[particle_data.segment_id]
	particle_data.global_transform = new_transform
	if not _segments_to_rebuild.has(segment.id):
		_apply_particle_data(segment, particle_data)
	

func update_particle_transform_and_color(in_external_id: int, new_transform: Transform3D, new_color: Color,
			 in_additional_data: Color) -> void:
	var particle_data: Particle = _ensure_particle_in_proper_segment(in_external_id, new_transform.origin)
	var segment: Segment = _id_to_segment_map[particle_data.segment_id]
	particle_data.global_transform = new_transform
	particle_data.color = new_color
	particle_data.additional_data = in_additional_data
	if not _segments_to_rebuild.has(segment.id):
		_apply_particle_data(segment, particle_data)


func _ensure_particle_in_proper_segment(in_particle_external_id: int, in_particle_new_position: Vector3) -> Particle:
	var particle_data: Particle = _external_id_to_particle[in_particle_external_id]
	assert(particle_data._is_correct(self), "external particle id and internal data are not in sync!")
	if not update_segments_on_movement:
		return particle_data
	
	var old_segment: Segment = _id_to_segment_map[particle_data.segment_id]
	var new_segment: Segment = _get_segment_from_position(in_particle_new_position)
	var target_particle: Particle = particle_data
	if old_segment != new_segment:
		_queued_particles_to_removal.append(particle_data)
		target_particle = _get_initialized_particle_for_segment(new_segment)
		target_particle.color = particle_data.color
		target_particle.additional_data = particle_data.additional_data
		target_particle.enabled = particle_data.enabled
		target_particle.global_transform = particle_data.global_transform
		_external_id_to_particle[in_particle_external_id] = target_particle
		_segments_to_rebuild[new_segment.id] = true
	return target_particle


func update_particle_color(in_external_id: int, new_color: Color, in_additional_data: Color) -> void:
	var particle_data: Particle = _external_id_to_particle[in_external_id]
	var segment: Segment = _id_to_segment_map[particle_data.segment_id]
	particle_data.color = new_color
	particle_data.additional_data = in_additional_data
	if not _segments_to_rebuild.has(segment.id):
		_apply_particle_data(segment, particle_data)


## Need to call apply_queued_removals() after all changes are queued
func queue_particle_removal(in_external_id: int) -> void:
	var particle_data: Particle = _external_id_to_particle[in_external_id]
	_queued_particles_to_removal.append(particle_data)
	_external_id_to_particle.erase(in_external_id)


func apply_queued_removals() -> void:
	var segments_to_refresh: Array[Segment] = []
	for particle in _queued_particles_to_removal:
		var segment: Segment = _id_to_segment_map[particle.segment_id]
		_disable_particle(particle)
		if segment.free_particle_ids_pool.size() == _SEGMENT_REBUILD_ABOVE_UNUSED_PARTICLES_COUNT:
			# this == is correct, if it would be >= then segment would be added to segments_to_refresh multiple times
			segments_to_refresh.append(segment)
	_queued_particles_to_removal.clear()

	for segment in segments_to_refresh:
		_clean_segment_from_disabled_particles(segment)
		_rebuild_segment(segment)


func _disable_particle(in_particle: Particle) -> void:
	var segment: Segment = _id_to_segment_map[in_particle.segment_id]
	in_particle.enabled = false
	segment.free_particle_ids_pool.append(in_particle.id)
	in_particle.global_transform = in_particle.global_transform.scaled(Vector3(0.0,0.0,0.0))
	segment.multimesh_instance.multimesh.set_instance_transform(in_particle.id, in_particle.global_transform)


func _clean_segment_from_disabled_particles(segment: Segment) -> void:
	var new_particle_array: Array[Particle] = []
	var particles_in_segment: Array[Particle] = segment.particles_in_segment
	for particle in particles_in_segment:
		if particle.enabled:
			var new_id: int = new_particle_array.size()
			particle.id = new_id
			new_particle_array.append(particle)
	
	segment.free_particle_ids_pool.clear()
	segment.particles_in_segment.clear()
	segment.particles_in_segment = new_particle_array


func create_state_snapshot() -> Dictionary:
	assert(_segments_to_rebuild.is_empty())
	var snapshot: Dictionary = {}
	snapshot["multimesh"] = multimesh.duplicate(true)
	snapshot["use_custom_data"] = use_custom_data
	snapshot["_lod_bias"] = _lod_bias
	snapshot["_mesh_override"] = _mesh_override.duplicate() if is_instance_valid(_mesh_override) else null
	snapshot["_visible"] = _visible
	snapshot["update_segments_on_movement"] = update_segments_on_movement
	
	var segment_map_snapshot: Dictionary = {}
	for id: Vector3i in _id_to_segment_map:
		var segment: Segment = _id_to_segment_map[id]
		segment_map_snapshot[id] = segment.create_state_snapshot(self)
	snapshot["segment_map_snapshot"] = segment_map_snapshot
	
	snapshot["_external_id_to_particle"] = _external_id_to_particle.duplicate()
	snapshot["_segments_to_rebuild"] = _segments_to_rebuild.duplicate(true)
	snapshot["_instance_uniforms"] = _instance_uniforms.duplicate(true)
	snapshot["_is_initialized"] = _is_initialized
	snapshot["_queued_particles_to_removal"] = _queued_particles_to_removal.duplicate(true)
	snapshot["_material_overlay"] = _material_overlay.duplicate(true) if is_instance_valid(_material_overlay) else null
	snapshot["_transparency"] = _transparency
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	assert(_segments_to_rebuild.is_empty())
	multimesh = in_snapshot["multimesh"].duplicate(true)
	use_custom_data = in_snapshot["use_custom_data"]
	_lod_bias = in_snapshot["_lod_bias"]
	_mesh_override = in_snapshot["_mesh_override"].duplicate(true) if is_instance_valid(in_snapshot["_mesh_override"]) else null
	_visible = in_snapshot["_visible"]
	update_segments_on_movement = in_snapshot["update_segments_on_movement"]
	_external_id_to_particle = in_snapshot["_external_id_to_particle"].duplicate()
	_segments_to_rebuild = in_snapshot["_segments_to_rebuild"].duplicate(true)
	_instance_uniforms = in_snapshot["_instance_uniforms"].duplicate(true)
	_is_initialized = in_snapshot["_is_initialized"]
	_queued_particles_to_removal = in_snapshot["_queued_particles_to_removal"].duplicate(true)
	_material_overlay = in_snapshot["_material_overlay"].duplicate() if is_instance_valid(in_snapshot["_material_overlay"]) else null
	_transparency = in_snapshot["_transparency"]
	
	var segment_map_snapshot: Dictionary = in_snapshot["segment_map_snapshot"].duplicate(true)
	for segment_id: Vector3i in segment_map_snapshot:
		if not _id_to_segment_map.has(segment_id):
			var segment: Segment = _create_segment_from_id(segment_id)
			_id_to_segment_map[segment_id] = segment
		
		var segment_snapshot: Dictionary = segment_map_snapshot[segment_id]
		var segment: Segment = _id_to_segment_map[segment_id]
		segment.apply_state_snapshot(segment_snapshot, self)
	
	var ids_to_remove: Array[Vector3i] = []
	for segment_id: Vector3i in _id_to_segment_map:
		if not segment_map_snapshot.has(segment_id):
			var segment: Segment = _id_to_segment_map[segment_id]
			segment.multimesh_instance.queue_free()
			segment.multimesh_instance.set_name("removal_" + segment.multimesh_instance.get_name())
			ids_to_remove.append(segment_id)
	for id: Vector3i in ids_to_remove:
		_id_to_segment_map.erase(id)


class Segment:
	var multimesh_instance: MultiMeshInstance3D
	var particles_in_segment: Array[Particle] = []
	var id: Vector3i
	var free_particle_ids_pool: Array[int] = []
	
	
	func create_state_snapshot(_in_parent_segmented_multimesh: SegmentedMultimesh) -> Dictionary:
		var snapshot: Dictionary = {}
		snapshot["multimesh.buffer"] = multimesh_instance.multimesh.buffer.duplicate()
		snapshot["multimesh.visible_instance_count"] = multimesh_instance.multimesh.visible_instance_count
		snapshot["multimesh.instance_count"] = multimesh_instance.multimesh.instance_count
		snapshot["particles_in_segment"] = particles_in_segment.duplicate()
		
		var particles_snapshots: Dictionary = {}
		for particle: Particle in particles_in_segment:
			particles_snapshots[particle.id] = particle.create_state_snapshot()
		snapshot["particles_snapshots"] = particles_snapshots
		
		snapshot["id"] = Vector3i(id)
		snapshot["free_particle_ids_pool"] = free_particle_ids_pool.duplicate(true)
		return snapshot
	
	
	func apply_state_snapshot(in_state_snapshot: Dictionary, in_parent_segmented_multimesh: SegmentedMultimesh) -> void:
		multimesh_instance.multimesh.instance_count = in_state_snapshot["multimesh.instance_count"]
		multimesh_instance.multimesh.visible_instance_count = in_state_snapshot["multimesh.visible_instance_count"]
		multimesh_instance.multimesh.buffer = in_state_snapshot["multimesh.buffer"].duplicate()
		
		id = Vector3i(in_state_snapshot["id"])
		free_particle_ids_pool = in_state_snapshot["free_particle_ids_pool"].duplicate(true)
		
		particles_in_segment = in_state_snapshot["particles_in_segment"].duplicate()
		var particles_snapshots: Dictionary = in_state_snapshot["particles_snapshots"]
		
		for particle_id: int in particles_in_segment.size():
			var particle: Particle = particles_in_segment[particle_id]
			particle.apply_state_snapshot(particles_snapshots[particle_id])
			assert(particle._is_correct(in_parent_segmented_multimesh))

# TODO: convert to struct when this feature is available
class Particle:
	var segment_id: Vector3i
	var id: int
	var global_transform: Transform3D
	var color: Color
	var additional_data: Color
	var enabled: bool = true
	
	func _init(in_segment_id: Vector3i, in_particle_id: int) -> void:
		segment_id = in_segment_id
		id = in_particle_id
	
	#  helper for assertions
	func _is_correct(in_parent_segmented_multimesh: SegmentedMultimesh) -> bool:
		var segment: Segment = in_parent_segmented_multimesh._id_to_segment_map[segment_id]
		var particle_data: Particle = segment.particles_in_segment[id]
		if segment_id != particle_data.segment_id:
			return false
		if id != particle_data.id:
			return false
		if global_transform != particle_data.global_transform:
			return false
		if color != particle_data.color:
			return false
		if additional_data != particle_data.additional_data:
			return false
		if enabled != particle_data.enabled:
			return false
		return true
	
	
	func create_state_snapshot() -> Dictionary:
		var snapshot: Dictionary = {}
		snapshot["segment_id"] = segment_id
		snapshot["id"] = id
		snapshot["global_transform"] = global_transform
		snapshot["color"] = color
		snapshot["additional_data"] = additional_data
		snapshot["enabled"] = enabled
		return snapshot
	
	
	func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
		segment_id = in_state_snapshot["segment_id"]
		id = in_state_snapshot["id"]
		global_transform = in_state_snapshot["global_transform"]
		color = in_state_snapshot["color"]
		additional_data = in_state_snapshot["additional_data"]
		enabled = in_state_snapshot["enabled"]

