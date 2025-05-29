class_name NanoParticleEmitter extends NanoStructure


signal transform_changed(new_transform: Transform3D)
signal parameters_changed(in_parameters: NanoParticleEmitterParameters)


const DEFAULT_ROTATION = Quaternion(Vector3.RIGHT, deg_to_rad(90))
const DEFAULT_TRANSFORM = Transform3D(Basis(DEFAULT_ROTATION))


@export var _transform := DEFAULT_TRANSFORM
@export var _parameters: NanoParticleEmitterParameters


var _instances_group: AtomicStructure
var _instances_atom_ids: Array[PackedInt32Array]
var _instances_bond_ids: Array[PackedInt32Array]


func calculate_total_molecule_instance_count() -> int:
	if _parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.INSTANCE_COUNT:
		return _parameters.get_stop_emitting_after_count()
	else:
		# Limit is time, be it the entire simulation or some value configured
		var workspace: Workspace = MolecularEditorContext.get_current_workspace()
		assert(workspace.has_structure(self), "calculate_total_molecule_instance_count() can only " +
			"be called while workspace is being edited!")
		var step_count: int = workspace.simulation_parameters.total_step_count
		var step_size_femtoseconds: float = workspace.simulation_parameters.step_size_in_femtoseconds
		var simulation_time_femtoseconds: float = step_count * step_size_femtoseconds
		var emit_time: float
		if _parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.TIME:
			var configured_time_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(
				_parameters.get_stop_emitting_after_nanoseconds(), TimeSpanPicker.Unit.NANOSECOND)
			if configured_time_femtoseconds > simulation_time_femtoseconds:
				configured_time_femtoseconds = simulation_time_femtoseconds
			emit_time = configured_time_femtoseconds - _parameters.get_initial_delay_in_nanoseconds()
		elif _parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.NEVER:
			emit_time = simulation_time_femtoseconds - _parameters.get_initial_delay_in_nanoseconds()
		var instance_rate_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(
				_parameters.get_instance_rate_time_in_nanoseconds(), TimeSpanPicker.Unit.NANOSECOND)
		var instantation_count : int = floori(emit_time / instance_rate_femtoseconds)
		var total_instance_count: int = instantation_count * _parameters.get_molecules_per_instance()
		return total_instance_count


func create_instances(out_group: AtomicStructure) -> void:
	assert(_instances_atom_ids.is_empty() and _instances_bond_ids.is_empty() and
		_instances_group == null, "Attempting to create instances when instances already exists!")
	assert(out_group != null)
	var template: AtomicStructure = _parameters.get_molecule_template()
	if template == null:
		return
	_instances_group = out_group
	_instances_group.start_edit()
	# collect template data
	var template_atoms: PackedInt32Array = template.get_valid_atoms()
	var template_bonds: PackedInt32Array = template.get_valid_bonds()
	var elements: PackedInt32Array = []
	var positions: PackedVector3Array = []
	var bonds: Array[Vector3i] = []
	# NOTE: This code assumes template has no gaps in atom and bond IDs
	# This is possible because of the current implementation on how templates are created
	# If this assumption is ever broken this code needs to change to map the id of the old atom IDs
	# to the corresponding AddAtomParameters
	for atom_id: int in template_atoms:
		elements.push_back(template.atom_get_atomic_number(atom_id))
		positions.push_back(template.atom_get_position(atom_id))
	for bond_id: int in template_bonds:
		bonds.push_back(template.get_bond(bond_id))
	# Create as many instances
	var params: NanoMolecularStructure.AddAtomParameters = null
	for i in calculate_total_molecule_instance_count():
		var offset: Vector3 = _calculate_instance_offset(i)
		var instance_atom_map: Dictionary[int, int] = {
			# old_id = new_id
		}
		var this_instance_atoms: PackedInt32Array
		var this_instance_bonds: PackedInt32Array
		_instances_atom_ids.push_back(this_instance_atoms)
		_instances_bond_ids.push_back(this_instance_bonds)
		for atom_idx: int in elements.size():
			params = NanoMolecularStructure.AddAtomParameters.new(
				elements[atom_idx],
				positions[atom_idx] + offset
			)
			var new_atom_id: int = out_group.add_atom(params)
			instance_atom_map[atom_idx] = new_atom_id
			this_instance_atoms.push_back(new_atom_id)
		for bond_idx: int in bonds.size():
			var atom1: int = instance_atom_map[bonds[bond_idx].x]
			var atom2: int = instance_atom_map[bonds[bond_idx].y]
			var bond_order: int = bonds[bond_idx].z
			var new_bond_id: int = out_group.add_bond(atom1, atom2, bond_order)
			this_instance_bonds.push_back(new_bond_id)
	_instances_group.end_edit()


func destroy_instances() -> void:
	if _instances_atom_ids.is_empty() or _instances_group == null:
		return
	_instances_group.start_edit()
	for instance_idx in _instances_atom_ids.size():
		var first_atom_id: int = _instances_atom_ids[instance_idx][0]
		if _instances_group.is_atom_valid(first_atom_id):
			for bond_id in _instances_bond_ids[instance_idx]:
				_instances_group.remove_bond(bond_id)
			for atom_id in _instances_atom_ids[instance_idx]:
				_instances_group.remove_atom(atom_id)
	_instances_group.end_edit()
	_instances_group = null
	_instances_atom_ids = []
	_instances_bond_ids = []


func get_instance_atoms_ids() -> Array[PackedInt32Array]:
	return _instances_atom_ids.duplicate(true)


## This method does not update the position of particles, only takes care of validity of the atoms
## Making them visible/invisible, valid/invalid in the workspace
func seek_simulation(in_time: float) -> void:
	if _instances_atom_ids.is_empty():
		return
	assert(_instances_group != null, "Attempted to seek simulation when no instances where created")
	var delay: float = _parameters.get_initial_delay_in_nanoseconds()
	var rate: float = _parameters.get_instance_rate_time_in_nanoseconds()
	var molecules_per_instane: int = _parameters.get_molecules_per_instance()
	var spawned_before_seek: bool = true
	_instances_group.start_edit()
	for instance_idx in _instances_atom_ids.size():
		if spawned_before_seek:
			# This is an optimization to stop doing this math after the first match
			var time: float = delay + rate * floorf(float(instance_idx) / float(molecules_per_instane))
			spawned_before_seek = time <= in_time
		var first_atom_id: int = _instances_atom_ids[instance_idx][0]
		if spawned_before_seek:
			if not _instances_group.is_atom_valid(first_atom_id):
				for atom_id in _instances_atom_ids[instance_idx]:
					_instances_group.revalidate_atom(atom_id)
				for bond_id in _instances_bond_ids[instance_idx]:
					_instances_group.revalidate_bond(bond_id)
		else:
			if _instances_group.is_atom_valid(first_atom_id):
				for bond_id in _instances_bond_ids[instance_idx]:
					_instances_group.remove_bond(bond_id)
				for atom_id in _instances_atom_ids[instance_idx]:
					_instances_group.remove_atom(atom_id)
	_instances_group.end_edit()


func notify_apply_simulation() -> void:
	# When simulation is applyed, any atom that was create in instance should remain
	# in the group and stop beign tracked by particle emitter
	_instances_group = null
	_instances_atom_ids = []
	_instances_bond_ids = []


func _calculate_instance_offset(_in_instance_idx: int) -> Vector3:
	# TODO: Find the formula to use here...
	var instance_offset: Vector3 = Vector3.ZERO
	return _transform.origin + instance_offset


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


func create_state_snapshot(in_with_instances: bool = false) -> Dictionary:
	var state_snapshot: Dictionary = super.create_state_snapshot()
	state_snapshot["script.resource_path"] = get_script().resource_path
	state_snapshot["_transform"] = _transform
	state_snapshot["_parameters_snapshot"] = _parameters.create_state_snapshot()
	if in_with_instances:
		if _instances_group == null:
			state_snapshot["_instances_group"] = Workspace.INVALID_STRUCTURE_ID
			state_snapshot["_instances_group_state"] = {} 
			state_snapshot["_instances_group_renderer_state"] = {} 
		else:
			state_snapshot["_instances_group"] = _instances_group.int_guid
			state_snapshot["_instances_group_state"] = _instances_group.create_state_snapshot()
			var workspace_cotext: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
			var rendering: Rendering = workspace_cotext.get_rendering()
			var renderer := rendering._get_renderer_for_atomic_structure(_instances_group)
			state_snapshot["_instances_group_renderer_state"] = renderer.create_state_snapshot()
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary, in_with_instances: bool = false) -> void:
	super.apply_state_snapshot(in_state_snapshot)
	_transform = in_state_snapshot["_transform"]
	if _parameters == null:
		_parameters = NanoParticleEmitterParameters.new()
	_parameters.apply_state_snapshot(in_state_snapshot["_parameters_snapshot"])
	if in_with_instances:
		var group_id: int = in_state_snapshot["_instances_group"]
		if group_id == Workspace.INVALID_STRUCTURE_ID:
			return
		_instances_group = MolecularEditorContext.get_current_workspace(). \
			get_structure_by_int_guid(group_id) as AtomicStructure
		_instances_group.apply_state_snapshot(in_state_snapshot["_instances_group_state"])
		var workspace_cotext: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
		var rendering: Rendering = workspace_cotext.get_rendering()
		var renderer := rendering._get_renderer_for_atomic_structure(_instances_group)
		renderer.apply_state_snapshot(in_state_snapshot["_instances_group_renderer_state"])
