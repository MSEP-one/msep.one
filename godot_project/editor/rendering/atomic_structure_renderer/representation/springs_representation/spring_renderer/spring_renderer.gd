# Responsible for spring rendering
class_name SpringRenderer extends Node3D

const MODEL_THICKNESS: float = 0.07
const REPEAT_OFFSET := MODEL_THICKNESS
const ALPHA_DEFAULT := 0.0

var _structure_id: int = Workspace.INVALID_STRUCTURE_ID
var _workspace_context: WorkspaceContext
var _multimesh: SegmentedMultimesh
var _transform_handler: TransformHandler
var _material: SpringMaterial


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_multimesh = get_node("SegmentedMultiMesh")
		_material = _multimesh.get_material_override()
		_transform_handler = TransformHandler.new(self)


func initialize(in_structure_context: StructureContext) -> void:
	_structure_id = in_structure_context.get_int_guid()
	_workspace_context = in_structure_context.workspace_context
	_multimesh.prepare()
	var nano_struct: NanoStructure = in_structure_context.nano_structure
	var springs: PackedInt32Array = nano_struct.springs_get_all()
	for spring_id in springs:
		var anchor_pos: Vector3 = nano_struct.spring_get_anchor_position(spring_id, in_structure_context)
		var atom_id: int = nano_struct.spring_get_atom_id(spring_id)
		var atom_pos: Vector3 = nano_struct.atom_get_position(atom_id)
		var direction_to_atom: Vector3 = anchor_pos.direction_to(atom_pos)
		var anchor_radius: float = NanoVirtualAnchor.MODEL_SIZE * 0.5
		anchor_pos += direction_to_atom * anchor_radius
		var state := Representation.InstanceState.new()
		state.is_selected = in_structure_context.is_spring_selected(spring_id)
		state.is_hydrogen = nano_struct.atom_get_atomic_number(atom_id) == PeriodicTable.ATOMIC_NUMBER_HYDROGEN
		add_spring(spring_id, atom_pos, anchor_pos, state.to_float())
	_multimesh.bake()


func add_spring(in_spring_id: int, in_position_begin: Vector3, in_position_end: Vector3, in_alpha: float) -> void:
	var distance: float = in_position_begin.distance_to(in_position_end)
	var start_position := in_position_begin
	var spring_transform := Transform3D(Basis(), start_position)
	spring_transform = spring_transform.looking_at(in_position_end).scaled_local(Vector3(MODEL_THICKNESS, 
			MODEL_THICKNESS, distance))
	var color: Color = Color(Color.WHITE, in_alpha)
	_multimesh.add_particle(in_spring_id, spring_transform, color, Color())


func refresh_spring_position(in_spring_id: int, in_position_start: Vector3, in_position_end: Vector3) -> void:
	var distance: float = in_position_start.distance_to(in_position_end)
	var spring_transform := Transform3D(Basis(), in_position_start)
	var scale_to_apply: Vector3 = Vector3(MODEL_THICKNESS,MODEL_THICKNESS,distance)
	spring_transform = spring_transform.looking_at(in_position_end).scaled_local(scale_to_apply)
	_multimesh.update_particle_transform(in_spring_id, spring_transform)


## call after all springs has been added / refreshed
func rebuild_check() -> void:
	_multimesh.rebuild_if_needed()


func prepare_spring_for_removal(spring_id: int) -> void:
	_transform_handler.stop_tracking_spring(spring_id)
	_multimesh.queue_particle_removal(spring_id)


func apply_prepared_removals() -> void:
	_multimesh.apply_queued_removals()


func handle_anchor_transform_progress(in_anchor: NanoVirtualAnchor,  in_selection_initial_pos: Vector3,
			in_initial_nano_struct_transform: Transform3D, in_gizmo_transform: Transform3D) -> void:
	_transform_handler.handle_anchor_transform_progress(in_anchor, in_selection_initial_pos,
			in_initial_nano_struct_transform, in_gizmo_transform)


func handle_atom_delta_progress(in_delta: Vector3, in_highlighted_atoms: PackedInt32Array) -> void:
	_transform_handler.handle_atom_delta_progress(in_delta, in_highlighted_atoms)


func handle_atom_rotation_progress(in_pivot: Vector3, in_rotation_to_apply: Basis,
			in_highlighted_atoms: PackedInt32Array) -> void:
	_transform_handler.handle_atom_rotation_progress(in_pivot, in_rotation_to_apply, in_highlighted_atoms)


func hide_spring(in_spring_id: int) -> void:
	var zero_scale_transform: Transform3D = Transform3D().scaled_local(Vector3.ZERO)
	_multimesh.update_particle_transform(in_spring_id, zero_scale_transform)


func show_spring(in_spring_id: int) -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_structure_id)
	var nano_struct: NanoStructure = structure_context.nano_structure
	var atom_id: int = nano_struct.spring_get_atom_id(in_spring_id)
	var atom_position: Vector3 = nano_struct.atom_get_position(atom_id)
	var anchor_position: Vector3 = nano_struct.spring_get_anchor_position(in_spring_id, structure_context)
	var direction_to_atom: Vector3 = anchor_position.direction_to(atom_position)
	var anchor_radius: float = NanoVirtualAnchor.MODEL_SIZE * 0.5
	anchor_position += direction_to_atom * anchor_radius
	refresh_spring_position(in_spring_id, atom_position, anchor_position)


func hide_hydrogen_springs() -> void:
	_material.disable_hydrogen_rendering()


func show_hydrogen_springs() -> void:
	_material.enable_hydrogen_rendering()


func change_spring_color(in_spring_id: int, in_color: Color, is_selected: bool) -> void:
	var state := Representation.InstanceState.new(_multimesh.get_particle_color(in_spring_id).a)
	state.is_selected = is_selected
	in_color.a = state.to_float()
	_multimesh.update_particle_color(in_spring_id, in_color, Color())


func set_global_color(in_color: Color) -> void:
	_material.set_color(in_color)


func change_look(in_mesh: Mesh, in_material: Material) -> void:
	_multimesh.set_mesh_override(in_mesh).set_material_override(in_material)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_structure_id"] = _structure_id
	snapshot["_transform_handler.snapshot"] = _transform_handler.create_state_snapshot()
	snapshot["_multimesh.snapshot"] = _multimesh.create_state_snapshot()
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_workspace_context = in_snapshot["_workspace_context"]
	_structure_id = in_snapshot["_structure_id"]
	_multimesh.apply_state_snapshot(in_snapshot["_multimesh.snapshot"])
	_transform_handler.apply_state_snapshot(in_snapshot["_transform_handler.snapshot"])


func get_structure_context() -> StructureContext:
	return _workspace_context.get_structure_context(_structure_id)


class TransformHandler:
	var _spring_renderer: SpringRenderer
	
	var _anchor_to_transform_position: Dictionary = {
		#anchor_id<int>: position<Vector3> 
	}
	var _atom_to_transform_position: Dictionary = {
		#atom_id<int> : position<Vector3>
	}

	var _springs_to_update: Dictionary = {
		#spring_id<int> : true<bool>
	}
	var _atoms_delta_pos: Vector3
	var _atom_rotation_pivot: Vector3
	var _atom_rotation: Basis
	var _is_queued: bool = false
	
	
	func _init(in_spring_renderer: SpringRenderer) -> void:
		_spring_renderer = in_spring_renderer
	
	
	func stop_tracking_spring(in_spring_id: int) -> void:
		_springs_to_update.erase(in_spring_id)
	
	
	func handle_anchor_transform_progress(in_anchor: NanoVirtualAnchor,  in_selection_initial_pos: Vector3,
				in_initial_nano_struct_transform: Transform3D, in_gizmo_transform: Transform3D) -> void:
		var structure_context: StructureContext = _spring_renderer.get_structure_context()
		var nano_struct: NanoStructure = structure_context.nano_structure
		var delta_pos: Vector3 = in_initial_nano_struct_transform.origin - in_selection_initial_pos
		var new_pos: Vector3 = in_gizmo_transform.origin + in_gizmo_transform.basis * delta_pos
		_anchor_to_transform_position[in_anchor.int_guid] = new_pos
		var springs: PackedInt32Array = in_anchor.get_related_springs(nano_struct.get_int_guid())
		var atomic_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
		var need_queue: bool = false
		for spring_id: int in springs:
			if atomic_structure.spring_is_visible(spring_id):
				need_queue = true
				_springs_to_update[spring_id] = true
		if need_queue:
			_queue_handle_gizmo_movement()
	
	
	func handle_atom_delta_progress(in_delta: Vector3, in_highlighted_atoms: PackedInt32Array) -> void:
		_atoms_delta_pos = in_delta
		var structure_context: StructureContext = _spring_renderer.get_structure_context()
		var nano_struct: NanoStructure = structure_context.nano_structure
		for atom_id in in_highlighted_atoms:
			var related_springs: PackedInt32Array = nano_struct.atom_get_springs(atom_id)
			for spring_id: int in related_springs:
				_springs_to_update[spring_id] = true
			var atom_position: Vector3 = nano_struct.atom_get_position(atom_id)
			_atom_to_transform_position[atom_id] = atom_position + in_delta
		_queue_handle_gizmo_movement()


	func handle_atom_rotation_progress(in_pivot: Vector3, in_rotation_to_apply: Basis,
				in_highlighted_atoms: PackedInt32Array) -> void:
		var structure_context: StructureContext = _spring_renderer.get_structure_context()
		var nano_struct: NanoStructure = structure_context.nano_structure
		_atom_rotation_pivot = in_pivot
		_atom_rotation = in_rotation_to_apply
		for atom_id in in_highlighted_atoms:
			var related_springs: PackedInt32Array = nano_struct.atom_get_springs(atom_id)
			for spring_id: int in related_springs:
				_springs_to_update[spring_id] = true
			
			var atom_position: Vector3 = nano_struct.atom_get_position(atom_id)
			var delta_pos: Vector3 = atom_position - in_pivot
			_atom_to_transform_position[atom_id] = in_pivot + in_rotation_to_apply * delta_pos
		_queue_handle_gizmo_movement()
	
	
	func _queue_handle_gizmo_movement() -> void:
		if _is_queued:
			return
		_is_queued = true
		_guarded_handle_gizmo_movement.call_deferred()
	
	
	func _guarded_handle_gizmo_movement() -> void:
		if _is_queued:
			# ensure call do not happens in the case when the request has been served manually in the mean time
			_handle_gizmo_movement()
	
	
	func _handle_gizmo_movement() -> void:
		_is_queued = false
		var structure_context: StructureContext = _spring_renderer.get_structure_context()
		var nano_struct: NanoStructure = structure_context.nano_structure
		var related_nanostructure: AtomicStructure = nano_struct as AtomicStructure
		var springs_to_update: PackedInt32Array = PackedInt32Array(_springs_to_update.keys())
		for spring_id: int in springs_to_update:
			if not related_nanostructure.spring_is_visible(spring_id):
				continue
			var atom_id: int = related_nanostructure.spring_get_atom_id(spring_id)
			var anchor_id: int = related_nanostructure.spring_get_anchor_id(spring_id)
			var atom_position: Vector3 = _atom_to_transform_position.get(atom_id, 
					related_nanostructure.atom_get_position(atom_id))
			var anchor_position: Vector3 = _anchor_to_transform_position.get(anchor_id,
					related_nanostructure.spring_get_anchor_position(spring_id, structure_context))
			var direction_to_atom: Vector3 = anchor_position.direction_to(atom_position)
			var anchor_radius: float = NanoVirtualAnchor.MODEL_SIZE * 0.5
			anchor_position += direction_to_atom * anchor_radius
			_spring_renderer.refresh_spring_position(spring_id, atom_position, anchor_position)
		_clear_movement_progress()
	
	
	func create_state_snapshot() -> Dictionary:
		if _is_queued:
			# apply the state before performing a snapshot
			_refresh_springs(_springs_to_update.keys())
			_is_queued = false
		var snapshot: Dictionary = {}
		snapshot["_anchor_to_transform_position"] = _anchor_to_transform_position.duplicate(true)
		snapshot["_atom_to_transform_position"] = _atom_to_transform_position.duplicate(true)
		snapshot["_springs_to_update"] = _springs_to_update.duplicate(true)
		snapshot["_atoms_delta_pos"] = _atoms_delta_pos
		snapshot["_atom_rotation_pivot"] = _atom_rotation_pivot
		snapshot["_atom_rotation"] = _atom_rotation
		snapshot["_is_queued"] = _is_queued
		return snapshot
	
	
	func apply_state_snapshot(in_snapshot: Dictionary) -> void:
		_anchor_to_transform_position = in_snapshot["_anchor_to_transform_position"].duplicate(true)
		_atom_to_transform_position = in_snapshot["_atom_to_transform_position"].duplicate(true)
		_springs_to_update = in_snapshot["_springs_to_update"].duplicate(true)
		_atoms_delta_pos = in_snapshot["_atoms_delta_pos"]
		_atom_rotation_pivot = in_snapshot["_atom_rotation_pivot"]
		_atom_rotation = in_snapshot["_atom_rotation"]
		_is_queued = in_snapshot["_is_queued"]
	
	
	func _refresh_springs(in_springs_to_update: PackedInt32Array) -> void:
		var structure_context: StructureContext = _spring_renderer.get_structure_context()
		var nano_struct: NanoStructure = structure_context.nano_structure
		var related_nanostructure: AtomicStructure = nano_struct as AtomicStructure
		for spring_id: int in in_springs_to_update:
			if not related_nanostructure.spring_is_visible(spring_id):
				continue
			var atom_id: int = related_nanostructure.spring_get_atom_id(spring_id)
			var atom_position: Vector3 = related_nanostructure.atom_get_position(atom_id)
			var anchor_position: Vector3 = related_nanostructure.spring_get_anchor_position(spring_id, structure_context)
			var direction_to_atom: Vector3 = anchor_position.direction_to(atom_position)
			var anchor_radius: float = NanoVirtualAnchor.MODEL_SIZE * 0.5
			anchor_position += direction_to_atom * anchor_radius
			_spring_renderer.refresh_spring_position(spring_id, atom_position, anchor_position)
	
	
	func _clear_movement_progress() -> void:
		_atom_rotation = Basis()
		_atoms_delta_pos = Vector3.ZERO
		_atom_rotation_pivot = Vector3()
		_anchor_to_transform_position.clear()
		_atom_to_transform_position.clear()
		_springs_to_update.clear()
