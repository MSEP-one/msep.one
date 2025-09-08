class_name NanoParticleEmitter extends NanoStructure

## Creates particles over time during a simulation
##
## Due to how openMM works, every particles that should be emitted are created
## and added to the structure in advance, but they are marked as invalid until
## it's time (for each particle) to be emitted.


signal transform_changed(new_transform: Transform3D)
signal parameters_changed(in_parameters: NanoParticleEmitterParameters)


const DEFAULT_ROTATION = Quaternion(Vector3.RIGHT, deg_to_rad(90))
const DEFAULT_TRANSFORM = Transform3D(Basis(DEFAULT_ROTATION))
# Safety margin is an extra space between spawned molecules to ensure the vdW forces
# of the previous molecule doesn't affect the initial speed of the following molecule
const INSTANCE_SAFETY_MARGIN = 0.05 # nanometers

@export var _transform := DEFAULT_TRANSFORM
@export var _parameters: NanoParticleEmitterParameters: set = set_parameters

var _frame_length_nanoseconds: float
var _debug_show_unspawned_instances: bool = false
var _instances_group: AtomicStructure
var _instances_atom_ids: Array[PackedInt32Array]
var _instances_bond_ids: Array[PackedInt32Array]
var _instance_offset_cache_radius: float = -1
var _instance_offset_cache: Dictionary[int, Vector3]
var _instance_offset_candidates: Array = []
var _instance_offset_last_candidate: int = -1
var _instances_reference_transform: Transform3D

# Atoms positions before a simulation starts and moves them away
var _instances_original_positions: Dictionary[int, Vector3] = {}


func _init() -> void:
	_debug_show_unspawned_instances = FeatureFlagManager.get_flag_value(
		FeatureFlagManager.FEATURE_FLAG_EMITTERS_SHOW_UNSPAWNED_INSTANCES
	)
	var on_feature_flag_toggled: Callable = func(path: String, new_value: bool) -> void:
		if path == FeatureFlagManager.FEATURE_FLAG_EMITTERS_SHOW_UNSPAWNED_INSTANCES:
			_debug_show_unspawned_instances = new_value
	FeatureFlagManager.on_feature_flag_toggled.connect(on_feature_flag_toggled)


func notify_added_to_workspace(in_workspace_context: WorkspaceContext) -> void:
	var workspace: Workspace = in_workspace_context.workspace
	if not workspace.structure_reparented.is_connected(_on_structure_reparented):
		workspace.structure_reparented.connect(_on_structure_reparented)
	if not workspace.structure_about_to_remove.is_connected(_on_structure_about_to_remove):
		workspace.structure_about_to_remove.connect(_on_structure_about_to_remove)
	if not workspace.simulation_parameters.changed.is_connected(_on_parameters_changed):
		workspace.simulation_parameters.changed.connect(_on_parameters_changed)
	if not in_workspace_context.about_to_apply_simulation.is_connected(_on_about_to_apply_simulation):
		in_workspace_context.about_to_apply_simulation.connect(_on_about_to_apply_simulation)

	_instances_group = workspace.get_structure_by_int_guid(int_parent_guid)
	_instances_reference_transform = _transform
	ensure_instances_exists()


func get_total_molecule_instance_count() -> int:
	# Limit is time, be it the entire simulation or some value configured
	var workspace: Workspace = MolecularEditorContext.find_workspace_possessing_structure(self)
	assert(workspace != null, "get_total_molecule_instance_count() can only " +
		"be called when present in a workspace")
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


## Count how many instances are currently tracked by this emitter, and either add the missing
## ones, or remove the extra instances. Called when:
## + Creating the particle emitter
## + The parameters have been modified (changing the total expected particle count)
## + A simulation is applied
func ensure_instances_exists() -> void:
	assert(_instances_group, "Structure is not initialized yet")
	var template: AtomicStructure = _parameters.get_molecule_template()
	if template == null:
		return
	
	# If molecules_per_instance changed, discard the current instances and recreate everything
	var molecules_per_instance: int = _parameters.get_molecules_per_instance()
	var expected_atoms_count_per_instance: int = template.get_valid_atoms_count() * molecules_per_instance
	if not _instances_atom_ids.is_empty():
		var first_instance: PackedInt32Array = _instances_atom_ids[0]
		if expected_atoms_count_per_instance != first_instance.size():
			# TODO: There's currently no way to remove an invalid atom, so they just stay in memory for now
			_instances_atom_ids.clear()
			_instances_bond_ids.clear()
	
	var total_count: int = get_total_molecule_instance_count()
	var current_count: int = _instances_atom_ids.size()
	if current_count == total_count:
		return
	
	if current_count > total_count:
		# Too many instances, delete the extra ones.
		_instances_atom_ids.resize(total_count)
		_instances_bond_ids.resize(total_count)
		_update_instances_original_positions() # Could be optimized
		return
	
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
	var workspace: Workspace = MolecularEditorContext.find_workspace_possessing_structure(self)
	var step_size_femtoseconds: float = workspace.simulation_parameters.step_size_in_femtoseconds
	var step_size_nanoseconds: float = TimeSpanPicker.femtoseconds_to_unit(
		step_size_femtoseconds, TimeSpanPicker.Unit.NANOSECOND)
	var steps_per_report: int = workspace.simulation_parameters.steps_per_report
	_frame_length_nanoseconds = step_size_nanoseconds * steps_per_report
	for i in total_count - current_count:
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
			var new_atom_id: int = _instances_group.add_atom(params)
			instance_atom_map[atom_idx] = new_atom_id
			this_instance_atoms.push_back(new_atom_id)
			_instances_original_positions[new_atom_id] = params.position
		for bond_idx: int in bonds.size():
			var atom1: int = instance_atom_map[bonds[bond_idx].x]
			var atom2: int = instance_atom_map[bonds[bond_idx].y]
			var bond_order: int = bonds[bond_idx].z
			var new_bond_id: int = _instances_group.add_bond(atom1, atom2, bond_order)
			this_instance_bonds.push_back(new_bond_id)
	
	# Mark all atoms as invalid
	# TODO: this could use a specific API instead of relying on the current implementation details
	for instance: PackedInt32Array in _instances_atom_ids:
		for atom_id: int in instance:
			if _instances_group.is_atom_valid(atom_id):
				_instances_group.remove_atom(atom_id)
	for instance: PackedInt32Array in _instances_bond_ids:
		for bond_id: int in instance:
			if _instances_group.is_bond_valid(bond_id):
				_instances_group.remove_bond(bond_id)
	_instances_group.end_edit()


## Called just before starting a simulation.
## Makes all instances visible, otherwise they will be ignored for the simulation.
func revalidate_all_instances() -> void:
	var expected_instance_count: int = get_total_molecule_instance_count()
	var current_instance_count: int = _instances_atom_ids.size()
	assert(expected_instance_count == current_instance_count, "Emitter instances are outdated")
	
	_instances_group.start_edit()
	for instance: PackedInt32Array in _instances_atom_ids:
		for atom_id: int in instance:
			_instances_group.revalidate_atom(atom_id)
	for instance: PackedInt32Array in _instances_bond_ids:
		for bond_id: int in instance:
			_instances_group.revalidate_bond(bond_id)
	_instances_group.end_edit()


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
			spawned_before_seek = frame < in_frame or (in_frame != .0 and is_equal_approx(frame, in_frame))
		var first_atom_id: int = _instances_atom_ids[instance_idx][0]
		if _debug_show_unspawned_instances or spawned_before_seek:
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
	
	# If the emitter moved, the existing instances must be moved too or they will be emitted
	# from the wrong place. 
	if not _transform.is_equal_approx(_instances_reference_transform):
		_instances_original_positions.clear()
		var reference_inverse: Transform3D = _instances_reference_transform.affine_inverse()
		_instances_group.start_edit()
		for instance: PackedInt32Array in _instances_atom_ids:
			for atom_id: int in instance:
				if _instances_group.is_atom_valid(atom_id):
					continue # Don't move instances already emitted.
				var local_pos: Vector3 = reference_inverse * _instances_group.atom_get_position(atom_id)
				var new_pos: Vector3 = _transform * local_pos
				_instances_group.atom_set_position(atom_id, new_pos)
				_instances_original_positions[atom_id] = new_pos
		_instances_group.end_edit()
	_instances_reference_transform = _transform


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
	if _parameters and _parameters.changed.is_connected(_on_parameters_changed):
		_parameters.changed.disconnect(_on_parameters_changed)
	_parameters = new_parameters
	_parameters.changed.connect(_on_parameters_changed)
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


func get_aabb(in_bounds_type := AtomicStructure.AABB_BoundsType.AtomsPositions) -> AABB:
	if _parameters == null or _parameters.get_molecule_template() == null:
		var aabb := AABB(_transform.origin, Vector3())
		aabb = aabb.grow(0.5)
		return aabb.abs()
	else:
		var aabb: AABB = _parameters.get_molecule_template().get_aabb(in_bounds_type)
		# Move the box relative to particle emitter position
		aabb.position = _transform.origin - aabb.size / 2.0
		return aabb


func is_particle_emitter_within_screen_rect(in_camera: Camera3D, screen_rect: Rect2i) -> bool:
	var emitter_screen_position: Vector2 = in_camera.unproject_position(_transform.origin)
	if screen_rect.abs().has_point(emitter_screen_position):
		return true
	return false


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = super.create_state_snapshot()
	state_snapshot["script.resource_path"] = get_script().resource_path
	state_snapshot["_transform"] = _transform
	state_snapshot["_instances_reference_transform"] = _instances_reference_transform
	state_snapshot["_parameters_snapshot"] = _parameters.create_state_snapshot()
	state_snapshot["_instances_atom_ids"] = _instances_atom_ids.duplicate(false)
	state_snapshot["_instances_bond_ids"] = _instances_bond_ids.duplicate(false)
	state_snapshot["_instances_group_id"] = -1 if _instances_group == null else _instances_group.int_guid
	state_snapshot["_instances_original_positions"] = _instances_original_positions.duplicate(false)
	state_snapshot["_frame_length_nanoseconds"] = _frame_length_nanoseconds
	
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_state_snapshot)
	_transform = in_state_snapshot["_transform"]
	_instances_reference_transform = in_state_snapshot["_instances_reference_transform"]
	if _parameters == null:
		_parameters = NanoParticleEmitterParameters.new()
	_parameters.apply_state_snapshot(in_state_snapshot["_parameters_snapshot"])
	_instances_atom_ids = in_state_snapshot["_instances_atom_ids"].duplicate(false)
	_instances_bond_ids = in_state_snapshot["_instances_bond_ids"].duplicate(false)
	_instances_original_positions = in_state_snapshot["_instances_original_positions"].duplicate(false)
	_frame_length_nanoseconds = in_state_snapshot["_frame_length_nanoseconds"]
	var workspace: Workspace = MolecularEditorContext.find_workspace_possessing_structure(self)
	assert(workspace != null, "Workspace not found!")
	var instances_group_id: int = in_state_snapshot["_instances_group_id"]
	if instances_group_id == -1:
		_instances_group = null
	else:
		_instances_group = workspace.get_structure_by_int_guid(instances_group_id)
	
	# If the emitter was deleted during a simulation and restored, the instances it tracks
	# could be already emitted, or moved away by openMM, and needs to be updated.
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(workspace)
	if not workspace_context.is_simulating():
		_stop_tracking_emitted_instances()
		_reset_hidden_instances_positions()
		ensure_instances_exists()


func _stop_tracking_emitted_instances() -> void:
	var instance_id: int = 0
	while instance_id < _instances_atom_ids.size():
		var first_atom_id: int = _instances_atom_ids[instance_id][0]
		if _instances_group.is_atom_valid(first_atom_id):
			# Instance was emitted, it's no longer handled by this emitter.
			var instance: PackedInt32Array = _instances_atom_ids[instance_id]
			for atom_id in instance:
				_instances_original_positions.erase(atom_id)
			_instances_atom_ids.remove_at(instance_id)
			_instances_bond_ids.remove_at(instance_id)
		else:
			# Instance was not emitted yet
			instance_id += 1


func _update_instances_original_positions() -> void:
	var workspace: Workspace = MolecularEditorContext.find_workspace_possessing_structure(self)
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(workspace)
	assert(not workspace_context.is_simulating(), "Calling this during a simulation will yield invalid positions.")
	
	_instances_original_positions.clear()
	for instance in _instances_atom_ids:
		for atom_id in instance:
			_instances_original_positions[atom_id] = _instances_group.atom_get_position(atom_id)


## Hidden instances are moved away before the simulation starts.
## This reposition them to their initial position.
func _reset_hidden_instances_positions() -> void:
	if _instances_original_positions.is_empty():
		return
	_instances_group.start_edit()
	for instance in _instances_atom_ids:
		for atom_id in instance:
			_instances_group.atom_set_position(atom_id, _instances_original_positions[atom_id])
	_instances_group.end_edit()


## Called when either the particle parameters or the simulation parameters are modified
func _on_parameters_changed() -> void:
	ensure_instances_exists()


func _on_structure_reparented(in_structure: NanoStructure, in_new_parent: NanoStructure) -> void:
	if in_structure != self or in_new_parent == _instances_group:
		return
	
	_instances_atom_ids.clear()
	_instances_bond_ids.clear()
	_instances_group = in_new_parent
	ensure_instances_exists()


## When a simulation is applied, any atom that was emitted should remain
## in the group and stop being tracked by this particle emitter. The other
## atoms (still marked as invalid) should stay there.
## This must happen before the snapshot is created.
func _on_about_to_apply_simulation() -> void:
	_stop_tracking_emitted_instances()
	_reset_hidden_instances_positions()
	if MolecularEditorContext.find_workspace_possessing_structure(self): # Check if necessary
		ensure_instances_exists()


func _on_structure_about_to_remove(in_structure: NanoStructure) -> void:
	if in_structure != self:
		return
	
	var workspace: Workspace = MolecularEditorContext.find_workspace_possessing_structure(self)
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(workspace)
	if workspace.structure_reparented.is_connected(_on_structure_reparented):
		workspace.structure_reparented.disconnect(_on_structure_reparented)
	if workspace.structure_about_to_remove.is_connected(_on_structure_about_to_remove):
		workspace.structure_about_to_remove.disconnect(_on_structure_about_to_remove)
	if workspace.simulation_parameters.changed.is_connected(_on_parameters_changed):
		workspace.simulation_parameters.changed.disconnect(_on_parameters_changed)
	if workspace_context.about_to_apply_simulation.is_connected(_on_about_to_apply_simulation):
		workspace_context.about_to_apply_simulation.disconnect(_on_about_to_apply_simulation)

	# If the emitter is deleted because of a user action, update the molecular
	# structure state before the snapshot is created.
	# Ignore if the emitter is removed because of undo / redo (as the state is
	# already contained in the snapshot)
	if not workspace_context.is_applying_snapshot():
		_stop_tracking_emitted_instances()
		_reset_hidden_instances_positions()
