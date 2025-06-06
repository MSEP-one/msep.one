class_name NanoParticleEmitter extends NanoStructure


signal transform_changed(new_transform: Transform3D)
signal parameters_changed(in_parameters: NanoParticleEmitterParameters)


const DEFAULT_ROTATION = Quaternion(Vector3.RIGHT, deg_to_rad(90))
const DEFAULT_TRANSFORM = Transform3D(Basis(DEFAULT_ROTATION))
# Safety margin is an extra space between spawned molecules to ensure the vdW forces
# of the previous molecule doesn't affect the initial speed of the following molecule
const INSTANCE_SAFETY_MARGIN = 0.05 # nanometers

@export var _transform := DEFAULT_TRANSFORM
@export var _parameters: NanoParticleEmitterParameters
var _frame_length_nanoseconds: float

var _instances_group: AtomicStructure
var _instances_atom_ids: Array[PackedInt32Array]
var _instances_bond_ids: Array[PackedInt32Array]
var _instance_offset_cache_radius: float = -1
var _instance_offset_cache: Dictionary[int, Vector3]
var _instance_offset_candidates: Array = []
var _instance_offset_last_candidate: int = -1


func get_total_molecule_instance_count() -> int:
	# Limit is time, be it the entire simulation or some value configured
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	assert(workspace.has_structure(self), "get_total_molecule_instance_count() can only " +
		"be called while workspace is being edited!")
	return calculate_total_molecule_instance_count(_parameters, workspace)


static func calculate_total_molecule_instance_count(
		in_parameters: NanoParticleEmitterParameters, in_workspace: Workspace) -> int:
	if in_parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.INSTANCE_COUNT:
		return in_parameters.get_stop_emitting_after_count()
	else:
		var step_count: int = in_workspace.simulation_parameters.total_step_count
		var step_size_femtoseconds: float = in_workspace.simulation_parameters.step_size_in_femtoseconds
		var simulation_time_femtoseconds: float = step_count * step_size_femtoseconds
		var emit_time: float
		if in_parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.TIME:
			var configured_time_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(
				in_parameters.get_stop_emitting_after_nanoseconds(), TimeSpanPicker.Unit.NANOSECOND)
			if configured_time_femtoseconds > simulation_time_femtoseconds:
				configured_time_femtoseconds = simulation_time_femtoseconds
			emit_time = configured_time_femtoseconds - in_parameters.get_initial_delay_in_nanoseconds()
		elif in_parameters.get_limit_type() == NanoParticleEmitterParameters.LimitType.NEVER:
			emit_time = simulation_time_femtoseconds - in_parameters.get_initial_delay_in_nanoseconds()
		var instance_rate_femtoseconds: float = TimeSpanPicker.unit_to_femtoseconds(
				in_parameters.get_instance_rate_time_in_nanoseconds(), TimeSpanPicker.Unit.NANOSECOND)
		var instantation_count : int = floori(emit_time / instance_rate_femtoseconds)
		var total_instance_count: int = instantation_count * in_parameters.get_molecules_per_instance()
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
	var molecules_per_instance: int = _parameters.get_molecules_per_instance()
	var total_count: int = get_total_molecule_instance_count()
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	var step_size_femtoseconds: float = workspace.simulation_parameters.step_size_in_femtoseconds
	var step_size_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
		step_size_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	var steps_per_report: int = workspace.simulation_parameters.steps_per_report
	_frame_length_nanoseconds = step_size_nanoseconds * steps_per_report
	for i in total_count:
		var emission_id: int = floori(float(i) / float(molecules_per_instance))
		var emit_index: int = i - (molecules_per_instance * emission_id)
		var offset: Vector3 = calculate_instance_offset(emit_index)
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
				_transform.origin + positions[atom_idx] + offset
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
func seek_simulation(in_frame: float) -> void:
	if _instances_atom_ids.is_empty():
		return
	assert(_instances_group != null, "Attempted to seek simulation when no instances where created")
	var delay: float = _parameters.get_initial_delay_in_nanoseconds()
	var rate: float = _parameters.get_instance_rate_time_in_nanoseconds()
	var molecules_per_instance: int = _parameters.get_molecules_per_instance()
	var spawned_before_seek: bool = true
	_instances_group.start_edit()
	for instance_idx in _instances_atom_ids.size():
		if spawned_before_seek:
			# This is an optimization to stop doing this math after the first match
			var time: float = delay + rate * floorf(float(instance_idx) / float(molecules_per_instance))
			var frame: float = time / _frame_length_nanoseconds
			spawned_before_seek = frame < in_frame or is_equal_approx(frame, in_frame)
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


func calculate_instance_offset(in_instance_idx: int) -> Vector3:
	var radius: float = _parameters.get_molecule_template().get_aabb().get_longest_axis_size() * 0.5 + INSTANCE_SAFETY_MARGIN
	
	# First let's see if is already been calculated
	if _instance_offset_cache_radius != radius:
		_instance_offset_cache_radius = radius
		_instance_offset_cache.clear()
		_instance_offset_candidates.clear()
		_instance_offset_last_candidate = -1
	if _instance_offset_cache.has(in_instance_idx):
		return _instance_offset_cache[in_instance_idx]
	
	# Not found in the cache, let's calculate and store it
	var grid_spacing: float = 2 * radius * 1.05  # safe margin

	# Generate a deterministic, ordered grid of candidates
	if _instance_offset_candidates.is_empty():
		var radius_guess: int = ceili(float(in_instance_idx + 1) ** (1.0/3.0) * 2.5)  # conservative cube radius
		for x in range(-radius_guess, radius_guess + 1):
			for y in range(-radius_guess, radius_guess + 1):
				for z in range(-radius_guess, radius_guess + 1):
					var offset_coord := Vector3i(x, y, z)
					var pos: Vector3 = Vector3(offset_coord) * grid_spacing
					var dist: float = pos.length_squared()
					_instance_offset_candidates.append([dist, offset_coord, pos])
		
		var sorter: Callable = func(a: Array, b: Array) -> bool:
			if a[0] != b[0]:
				return a[0] < b[0]
			var a_coord: Vector3i = a[1] as Vector3i
			var b_coord: Vector3i = b[1] as Vector3i
			const XYZ = [0, 1, 2]
			for axis: int in XYZ:
				if a_coord[axis] == b_coord[axis]:
					continue
				return a_coord[axis] < b_coord[axis]
			return true
		# Sort by distance, then lexicographically by grid coordinates
		_instance_offset_candidates.sort_custom(sorter)

	# Place spheres up to index in_instance_idx
	for candidate_idx: int in range(_instance_offset_last_candidate + 1, _instance_offset_candidates.size()):
		_instance_offset_last_candidate = candidate_idx
		var c: Array = _instance_offset_candidates[candidate_idx]
		var pos: Vector3 = c[2] as Vector3
		var valid: bool = true
		for prev_instance_idx: int in candidate_idx:
			# Candidate is too close to a previously placed molecule
			var placed_at: Vector3 = _instance_offset_cache[prev_instance_idx]
			if (pos - placed_at).length() < 2 * radius:
				valid = false
				break
		if valid:
			_instance_offset_cache[in_instance_idx] = pos
			return pos
	return Vector3.ZERO


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
		var group_structure_context: StructureContext = \
			MolecularEditorContext.get_current_workspace_context().\
			get_nano_structure_context_from_id(group_id)
		_instances_group = group_structure_context.nano_structure as AtomicStructure
		_instances_group.apply_state_snapshot(in_state_snapshot["_instances_group_state"])
		group_structure_context.get_collision_engine().rebuild(group_structure_context)
		var workspace_cotext: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
		var rendering: Rendering = workspace_cotext.get_rendering()
		var renderer := rendering._get_renderer_for_atomic_structure(_instances_group)
		renderer.apply_state_snapshot(in_state_snapshot["_instances_group_renderer_state"])
