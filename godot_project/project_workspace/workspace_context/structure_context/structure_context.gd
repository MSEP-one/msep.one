class_name StructureContext extends Node

const DATABASE_DIRECTORY = "/workspace_databases/"

signal selection_changed()
signal atom_selection_changed()
signal atoms_deselected(in_deselected_atoms: PackedInt32Array)
signal virtual_object_selection_changed(is_selected: bool)
signal dna_control_points_selection_changed()
signal dna_control_points_deselected(in_deselected_control_points: PackedInt32Array)

const AlignSelectionGroupingPolicy = AlignSelectionParameters.AlignSelectionGroupingPolicy

var workspace_context: WorkspaceContext

var nano_structure : NanoStructure:
	get:
		if is_template():
			return _template_nano_struct_ref
		return workspace_context.workspace.get_structure_by_int_guid(int_guid)
	set(v):
		nano_structure = v
		
var _template_nano_struct_ref: NanoStructure = null

# TODO: should be private
var int_guid: int

var _lmdb: LightningMemoryMappedDatabase = null
var _collision_engine: CollisionEngine
var _selection_db: SelectionDB
var _last_obb: OBB = null

var _init_called: bool = false

var _is_editable_dirty: bool = true
var _is_editable: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_collision_engine = get_node("CollisionEngine")
		_selection_db = get_node("SelectionDB")
		_lmdb = get_node("LightningMemoryMappedDatabase") as LightningMemoryMappedDatabase
		_selection_db.selection_changed.connect(_on_selection_db_selection_changed)
		_selection_db.atom_selection_changed.connect(_on_selection_db_atom_selection_changed)
		_selection_db.atoms_deselected.connect(_on_selection_db_atoms_deselected)
		_selection_db.virtual_object_selection_changed.connect(_on_virtual_object_selection_changed)
		_selection_db.dna_control_points_selection_changed.connect(_on_dna_control_points_selection_changed)
		_selection_db.dna_control_points_deselected.connect(_on_dna_control_points_deselected)
	if what == NOTIFICATION_READY:
		assert(_init_called)
		pass


func initialize(in_workspace_context: WorkspaceContext,
			in_guid: int,
			in_nano_structure: NanoStructure = null) -> void:
	assert(in_guid != Workspace.INVALID_STRUCTURE_ID, "ID is invalid, most probably should be initialized as template")
	_init_called = true
	workspace_context = in_workspace_context
	int_guid = in_guid
	if in_nano_structure is LMDBNanoStruct:
		var path: String = OS.get_user_data_dir() + DATABASE_DIRECTORY
		if not DirAccess.dir_exists_absolute(path):
			DirAccess.make_dir_absolute(path)
		_lmdb.initialize(path)
		in_nano_structure.initialize(_lmdb)
	workspace_context.history_changed.connect(_on_workspace_context_history_changed)
		
	if in_nano_structure.visibility_changed.is_connected(_on_nano_structure_visibility_changed):
		in_nano_structure.visibility_changed.connect(_on_nano_structure_visibility_changed)
	
	_selection_db.initialize(self)
	_collision_engine.initialize(self)


func initialize_as_template(in_workspace_context: WorkspaceContext, in_nano_structure: NanoStructure) -> void:
	int_guid = Workspace.INVALID_STRUCTURE_ID
	_init_called = true
	workspace_context = in_workspace_context
	in_nano_structure.visibility_changed.connect(_on_nano_structure_visibility_changed)
	_template_nano_struct_ref = in_nano_structure


func is_template() -> bool:
	return int_guid == Workspace.INVALID_STRUCTURE_ID


func finalize_template() -> void:
	assert(int_guid != Workspace.INVALID_STRUCTURE_ID)
	if not _selection_db.is_initialized():
		_selection_db.initialize(self)
	if not _collision_engine.is_initialized():
		_collision_engine.initialize(self)


func get_int_guid() -> int:
	return int_guid


func is_created() -> bool:
	return int_guid != Workspace.INVALID_STRUCTURE_ID


func is_inside_workspace() -> bool:
	return workspace_context.workspace.has_structure_with_int_guid(int_guid)


func is_active() -> bool:
	if !is_instance_valid(workspace_context):
		return false
	return workspace_context.get_current_structure_context() == self


func _on_workspace_context_history_changed() -> void:
	_last_obb = null


func _on_nano_structure_visibility_changed(_in_visible: bool) -> void:
	mark_is_editable_dirty()


func is_context_of_object_being_created() -> bool:
	var peek_callback: Callable = func(in_object: NanoStructure) -> bool:
		return nano_structure == in_object
	return workspace_context.peek_object_being_created(peek_callback)


func is_editable() -> bool:
	if is_context_of_object_being_created():
		return true
	if _is_editable_dirty:
		_is_editable_dirty = false
		if workspace_context == null or workspace_context.get_current_structure_context() == null:
			_is_editable = false
		elif nano_structure == null or not nano_structure.get_visible():
			_is_editable = false
		else:
			_is_editable = is_active() or workspace_context.workspace.is_a_ancestor_of_b(
					workspace_context.get_current_structure_context().nano_structure,
					nano_structure)
	return _is_editable


func mark_is_editable_dirty() -> void:
	_is_editable_dirty = true


func get_edit_subviewport() -> WorkspaceEditorViewport:
	return workspace_context.get_editor_viewport()


func get_collision_engine() -> CollisionEngine:
	return _collision_engine


func get_rendering() -> Rendering:
	return workspace_context.get_editor_viewport().get_rendering()


func _process(_delta: float) -> void:
	if _lmdb.is_active():
		_lmdb.commit()

# # Selection
# # # # # #
func has_selection(in_recursive: bool = false) -> bool:
	if _selection_db.has_selection():
		return true
	if in_recursive:
		var children_structures: Array[NanoStructure] = workspace_context.workspace.get_child_structures(nano_structure)
		for child: NanoStructure in children_structures:
			if workspace_context.get_nano_structure_context(child).has_selection(true):
				return true
	return false


func has_transformable_selection() -> bool:
	return is_any_atom_selected() \
		or _selection_db.is_virtual_object_selected() \
		or _selection_db.get_selected_dna_spline_control_points().size() > 0


func has_cached_selection_set() -> bool:
	return _selection_db.has_cached_selection_set()


func is_any_atom_selected() -> bool:
	return _selection_db.is_any_atom_selected()


func are_many_atom_selected() -> bool:
	return _selection_db.are_many_atom_selected()


func is_any_bond_selected() -> bool:
	return _selection_db.is_any_bond_selected()


func is_any_spring_selected() -> bool:
	return _selection_db.is_any_spring_selected()


func is_atom_selected(in_atom_id: int) -> bool:
	return _selection_db.is_atom_selected(in_atom_id)


func is_bond_selected(in_bond_id: int) -> bool:
	return _selection_db.is_bond_selected(in_bond_id)


func is_spring_selected(in_spring_id: int) -> bool:
	return _selection_db.is_spring_selected(in_spring_id)


func dna_structure_has_selection() -> bool:
	if not nano_structure is DnaStructure:
		return false
	if _selection_db.get_selected_dna_spline_control_points().size() > 0:
		return true
	return false


func is_dna_structure_fully_selected() -> bool:
	if not nano_structure is DnaStructure:
		return false
	var dna_structure := nano_structure as DnaStructure
	return _selection_db.get_selected_dna_spline_control_points().size() == dna_structure.get_control_point_count()


func is_virtual_object_selected() -> bool:
	assert(nano_structure.is_virtual_object())
	# This method does not care of the type of virtual object, use with care
	return _selection_db.is_virtual_object_selected()


func is_shape_selected() -> bool: 
	return _selection_db.is_virtual_object_selected() and nano_structure is NanoShape


func is_motor_selected() -> bool:
	# Internally store selected information as shape
	return _selection_db.is_virtual_object_selected() and nano_structure is NanoVirtualMotor


func is_particle_emitter_selected() -> bool:
	return _selection_db.is_virtual_object_selected() and nano_structure is NanoParticleEmitter


func is_anchor_selected() -> bool:
	return _selection_db.is_virtual_object_selected() and nano_structure is NanoVirtualAnchor


func is_fully_selected() -> bool:
	if is_empty_but_has_subgroups():
		for child_structure: NanoStructure in workspace_context.workspace.get_child_structures(nano_structure):
			var structure_context: StructureContext = workspace_context.get_nano_structure_context(child_structure)
			if not structure_context.is_fully_selected():
				return false
		return true
	if nano_structure is NanoShape:
		return is_shape_selected()
	if nano_structure is NanoVirtualMotor:
		return is_motor_selected()
	if nano_structure is NanoParticleEmitter:
		return is_particle_emitter_selected()
	if nano_structure is NanoVirtualAnchor: 
		if not is_anchor_selected():
			# Anchor is not selected, make an early return
			return false
		return true
	if nano_structure is DnaStructure:
		return is_dna_structure_fully_selected()
	assert(nano_structure is AtomicStructure, "NanoStructure seems to be an untracked kind of virtual object (%s)" % nano_structure.get_type())
	return _selection_db.get_selected_atoms().size() == nano_structure.get_valid_atoms_count() \
			and _selection_db.get_selected_bonds().size() == nano_structure.get_valid_bonds_count() \
			and _selection_db.get_selected_springs().size() == nano_structure.springs_count()


func has_atom_selection(include_children: bool = true) -> bool:
	if not get_selected_atoms().is_empty():
		return true
	if include_children:
		for child_structure: NanoStructure in workspace_context.workspace.get_child_structures(nano_structure):
			var structure_context: StructureContext = workspace_context.get_nano_structure_context(child_structure)
			if structure_context.has_atom_selection(true):
				return true
	return false


func is_empty() -> bool:
	if nano_structure is AtomicVirtualStructure:
		return false
	if nano_structure is AtomicStructure:
		return nano_structure.get_valid_atoms_count() == 0
	return false


func is_empty_but_has_subgroups() -> bool:
	return nano_structure is AtomicStructure and \
			nano_structure.get_valid_atoms_count() == 0 and \
			workspace_context.workspace.get_child_structures(nano_structure).size()


func get_selected_atoms() -> PackedInt32Array:
	return _selection_db.get_selected_atoms()


func get_newest_selected_atom_id() -> int:
	return _selection_db.get_newest_selected_atom_id()


func get_selected_bonds() -> PackedInt32Array:
	return _selection_db.get_selected_bonds()


func get_bonds_partially_influenced_by_selection() -> PackedInt32Array:
	return _selection_db.get_bonds_partially_influenced_by_selection()


func get_selected_springs() -> PackedInt32Array:
	return _selection_db.get_selected_springs()


func select_atoms(in_atoms_to_select: PackedInt32Array) -> void:
	return _selection_db.select_atoms(in_atoms_to_select)


func deselect_atoms(in_atoms_to_deselect: PackedInt32Array) -> void:
	return _selection_db.deselect_atoms(in_atoms_to_deselect)


func deselect_bonds(in_bonds_to_deselect: PackedInt32Array) -> void:
	return _selection_db.deselect_bonds(in_bonds_to_deselect)


func select_bonds(in_bonds_to_select: PackedInt32Array) -> void:
	return _selection_db.select_bonds(in_bonds_to_select)


func select_springs(in_springs_to_select: PackedInt32Array) -> void:
	return _selection_db.select_springs(in_springs_to_select)


func deselect_springs(in_springs_to_deselect: PackedInt32Array) -> void:
	return _selection_db.deselect_springs(in_springs_to_deselect)


func select_atoms_and_get_auto_selected_bonds(in_atoms_to_select: PackedInt32Array) -> PackedInt32Array: 
	return _selection_db.select_atoms_and_get_auto_selected_bonds(in_atoms_to_select)


func count_visible_atoms_by_type(types_to_count: PackedInt32Array) -> int:
	if not nano_structure is AtomicStructure:
		return 0
	return nano_structure.atoms_count_visible_by_type(types_to_count)


func select_by_type(types_to_select: PackedInt32Array) -> void:
	return _selection_db.select_by_type(types_to_select)


func select_connected(in_show_hidden_objects: bool = false, in_linked_by_springs: bool = false) -> AtomSelection.AtomSelectionResult: 
	return _selection_db.select_connected(in_show_hidden_objects, in_linked_by_springs)


func find_atoms_and_bonds_connected_to(in_atom_id: int) -> Dictionary[StringName, PackedInt32Array]:
	if not nano_structure is AtomicStructure:
		return {}
	return nano_structure.find_atoms_and_bonds_connected_to(in_atom_id)


func can_grow_selection() -> bool:
	if _selection_db.has_cached_selection_set():
		return true
	return _selection_db.can_grow_selection()


func grow_selection() -> void:
	return _selection_db.grow_selection()


func shrink_selection() -> void:
	return _selection_db.shrink_selection()


func clear_bond_selection() -> void:
	return _selection_db.clear_bond_selection()


func set_bond_selection(in_bonds_to_select: PackedInt32Array) -> void:
	return _selection_db.set_bond_selection(in_bonds_to_select)


func invert_selection() -> void:
	return _selection_db.invert_selection()


func select_all(in_recursive: bool = false) -> void:
	_selection_db.select_all()
	if in_recursive:
		var child_structures: Array[NanoStructure] = workspace_context.workspace.get_child_structures(nano_structure)
		for child: NanoStructure in child_structures:
			if !child.get_visible():
				continue
			var child_context: StructureContext = workspace_context.get_nano_structure_context(child)
			child_context.select_all(true)


func set_atom_selection(in_atoms_to_select: PackedInt32Array) -> void:
	return _selection_db.set_atom_selection(in_atoms_to_select)


func set_spring_selection(in_springs_to_select: PackedInt32Array) -> void:
	return _selection_db.set_spring_selection(in_springs_to_select)


func set_dna_control_point_selection(in_control_points_to_select: PackedInt32Array) -> void:
	return _selection_db.set_dna_control_point_selection(in_control_points_to_select)


func select_dna_control_points(in_control_points_to_select: PackedInt32Array) -> void:
	return _selection_db.select_dna_control_points(in_control_points_to_select)


func deselect_dna_control_points(in_control_points_to_deselect: PackedInt32Array) -> void:
	return _selection_db.deselect_dna_control_points(in_control_points_to_deselect)


func get_selected_dna_spline_control_points() -> PackedInt32Array:
	return _selection_db.get_selected_dna_spline_control_points()


func set_virtual_object_selected(in_selected: bool) -> void:
	assert(nano_structure.is_virtual_object())
	# This method does not care of the type of virtual object, use with care
	_selection_db.set_virtual_object_selected(in_selected)


func set_shape_selected(in_selected: bool) -> void:
	if nano_structure is NanoShape:
		_selection_db.set_virtual_object_selected(in_selected)


func set_motor_selected(in_selected: bool) -> void:
	if nano_structure is NanoVirtualMotor:
		_selection_db.set_virtual_object_selected(in_selected)


func set_particle_emitter_selected(in_selected: bool) -> void:
	if nano_structure is NanoParticleEmitter:
		_selection_db.set_virtual_object_selected(in_selected)


func set_anchor_selected(in_selected: bool) -> void:
	if nano_structure is NanoVirtualAnchor:
		_selection_db.set_virtual_object_selected(in_selected)


func clear_selection(in_recursive: bool = false) -> void:
	_selection_db.clear_selection()
	if in_recursive:
		var child_structures: Array[NanoStructure] = workspace_context.workspace.get_child_structures(nano_structure)
		for child: NanoStructure in child_structures:
			var child_context: StructureContext = workspace_context.get_nano_structure_context(child)
			child_context.clear_selection(true)


func get_selection_aabb() -> AABB:
	return _selection_db.get_selection_aabb()


func count_obb_with_selection_policy(in_policy: AlignSelectionGroupingPolicy) -> int:
	match in_policy:
		AlignSelectionGroupingPolicy.OneBoxPerGroup:
			if workspace_context.get_current_structure_context() == self:
				return 1 if has_atom_selection(false) else 0
			return 1 if has_selection(true) else 0
		AlignSelectionGroupingPolicy.OneBoxPerSubgroup:
			return 1 if has_selection() else 0
		AlignSelectionGroupingPolicy.OneBoxPerMolecule:
			if not nano_structure is AtomicStructure or nano_structure is AtomicVirtualStructure:
				return 1
			var molecules: Array[PackedInt32Array] = _subdivide_molecules(get_selected_atoms())
			return molecules.size()
	assert(false, "Unhandled grouping policy: %d" % in_policy)
	return 0


func get_selection_obb_with_selection_policy(in_policy: AlignSelectionGroupingPolicy) -> Array[OBB]:
	match in_policy:
		AlignSelectionGroupingPolicy.OneBoxPerGroup:
			if workspace_context.get_current_structure_context() == self:
				if has_atom_selection(false):
					return [get_selection_obb()]
				return []
			var workspace: Workspace = workspace_context.workspace
			var child_structures: Array[NanoStructure] = workspace.get_child_structures(nano_structure)
			var point_cloud_sources: Array[StructureContext] = [self]
			while not child_structures.is_empty():
				var next_loop: Array[NanoStructure] = []
				for child: NanoStructure in child_structures:
					next_loop.append_array(workspace.get_child_structures(child))
					point_cloud_sources.append(workspace_context.get_structure_context(child.int_guid))
				child_structures = next_loop
			var point_cloud: Array[Vector3]
			var obb_source: Dictionary[StructureContext, PackedInt32Array] = {}
			for ctx: StructureContext in point_cloud_sources:
				if ctx.nano_structure is NanoShape:
					var nano_shape := ctx.nano_structure as NanoShape
					obb_source[ctx] = PackedInt32Array()
					var transform: Transform3D = nano_shape.get_transform()
					for vertex: Vector3 in nano_shape.get_shape_vertexes():
						point_cloud.append(transform * vertex)
				elif nano_structure.has_transform():
					obb_source[ctx] = PackedInt32Array()
					point_cloud.append(nano_structure.get_transform().origin)
				elif ctx.nano_structure is DnaStructure:
					var dna_structure := ctx.nano_structure as DnaStructure
					obb_source[ctx] = PackedInt32Array()
					for p: int in dna_structure.get_control_point_count():
						point_cloud.append(dna_structure.get_control_point_position(p))
					point_cloud.append(nano_structure.get_transform().origin)
				elif ctx.nano_structure is AtomicStructure:
					obb_source[ctx] = ctx.get_selected_atoms()
					var atomic_structure: AtomicStructure = ctx.nano_structure as AtomicStructure
					for atom_id: int in ctx.get_selected_atoms():
						point_cloud.append(atomic_structure.atom_get_position(atom_id))
			return [_get_obb_from_point_cloud(point_cloud, obb_source)]
		AlignSelectionGroupingPolicy.OneBoxPerSubgroup:
			return [get_selection_obb()]
		AlignSelectionGroupingPolicy.OneBoxPerMolecule:
			if not nano_structure is AtomicStructure or nano_structure is AtomicVirtualStructure:
				return [get_selection_obb()]
			var atomic_structure := nano_structure as AtomicStructure
			var molecules: Array[PackedInt32Array] = _subdivide_molecules(get_selected_atoms())
			var obbs: Array[OBB] = []
			for molecule: PackedInt32Array in molecules:
				var positions: Array[Vector3] = []
				for atom_id: int in molecule:
					positions.append(atomic_structure.atom_get_position(atom_id))
				obbs.append(_get_obb_from_point_cloud(positions, {self : molecule}))
			return obbs
	assert(false, "Unhandled grouping policy: %d" % in_policy)
	return []


func get_selection_obb() -> OBB:
	if _last_obb != null:
		return _last_obb
	if nano_structure is NanoShape:
		_last_obb = nano_structure.get_shape_obb(self)
		return _last_obb
	elif nano_structure.has_transform():
		var aabb: AABB = get_selection_aabb()
		if nano_structure is NanoVirtualMotor:
			# Motors only needs the front plane, flatten the box
			aabb.size.x = 0
		_last_obb = OBB.new(aabb.size, nano_structure.get_transform(), {self : []})
		return _last_obb
	elif nano_structure is AtomicStructure and not nano_structure is AtomicVirtualStructure:
		var atomic_structure := nano_structure as AtomicStructure
		var selected_atoms: PackedInt32Array = get_selected_atoms()
		var positions: Array[Vector3] = []
		# 1. Collect centroid and atoms positions
		for atom_id: int in selected_atoms:
			positions.append(atomic_structure.atom_get_position(atom_id))
		_last_obb = _get_obb_from_point_cloud(positions, {self : selected_atoms})
		return _last_obb
	var aabb: AABB = get_selection_aabb()
	var obb := OBB.new(aabb.size, Transform3D(Basis(), aabb.get_center()), {self: []})
	return obb


func _get_obb_from_point_cloud(in_positions: Array[Vector3], in_source: Dictionary[StructureContext, PackedInt32Array]) -> OBB:
	var centroid := Vector3()
	for pos in in_positions:
		centroid += pos
	centroid /= in_positions.size()
	# 1. calculate covariance matrix
	var cov_matrix: Array[PackedFloat64Array] = _get_covariance_matrix(in_positions, centroid)
	
	# 2. Power Iteration to find Eigenvectors (Principal Axes)
	var eigen: Dictionary = _get_eigenvalues(cov_matrix)
	var axes: Array[Vector3] = eigen.eigenvectors
	var eigenvalues: Array[float] = eigen.eigenvalues
	
	# 4. Orthonormalize
	var basis := Basis(axes[0], axes[1], axes[2]).orthonormalized()
	axes = [basis[0], basis[1], basis[2]]
	
	# 5. Find Min/Max by projecting points onto axes
	var min_extents := Vector3.INF
	var max_extents := -Vector3.INF
	for p: Vector3 in in_positions:
		for i in 3:
			var projection := p.dot(axes[i])
			min_extents[i] = min(min_extents[i], projection)
			max_extents[i] = max(max_extents[i], projection)

	# 6. Sort axes by extent size (largest to smallest)
	var size: Vector3 = max_extents - min_extents
	var axes_order: Array[int] = [0, 1, 2]
	axes_order.sort_custom(
		func(a: int, b:int) -> bool:
			if is_equal_approx(size[a], size[b]):
				return a < b
			return size[a] >= size[b]
	)
	
	axes = [axes[axes_order[0]], axes[axes_order[1]], axes[axes_order[2]]]
	size = Vector3(size[axes_order[0]], size[axes_order[1]], size[axes_order[2]])
	
	# 7. Warrantee right-handiness
	const DEGENERATE_AXIS_THRESHOLD := 1e-10
	var axis_x := axes[0].normalized() if axes[0].length() > DEGENERATE_AXIS_THRESHOLD else Vector3.RIGHT
	
	var axis_z: Vector3
	if axes[1].length() > DEGENERATE_AXIS_THRESHOLD:
		axis_z = axis_x.cross(axes[1])
		if axis_z.length() < DEGENERATE_AXIS_THRESHOLD:
			axis_z = Vector3.ZERO  # axes[1] was parallel to axis_x
	else:
		axis_z = Vector3.ZERO  # axes[1] was degenerate
	
	if axis_z.length() < DEGENERATE_AXIS_THRESHOLD:
		# Pick arbitrary perpendicular to axis_x
		if abs(axis_x.dot(Vector3.RIGHT)) < 0.9:
			axis_z = axis_x.cross(Vector3.RIGHT)
		elif abs(axis_x.dot(Vector3.UP)) < 0.9:
			axis_z = axis_x.cross(Vector3.UP)
		else:
			axis_z = axis_x.cross(Vector3.BACK)
	
	# If Y is also derivable, re-derive it too for full orthonormality
	var axis_y := axis_z.cross(axis_x).normalized()
	basis = Basis(axis_x, axis_y, axis_z).orthonormalized()
	axes = [basis[0], basis[1], basis[2]]
	
	# 8. Volume minimization
	const PLANAR_THRESHOLD: float = 0.01
	var sorted_eigen: Array[float] = eigenvalues.duplicate()
	sorted_eigen.sort()
	var is_planar: bool = sorted_eigen[0] < PLANAR_THRESHOLD
	var is_isotropic: bool = sorted_eigen[0] / max(sorted_eigen[2], 1e-10) > 0.95
	
	if is_isotropic:
		for axis: Vector3.Axis in [Vector3.AXIS_Z, Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z]:
			# Repeated Z axis is intentional, I'm not sure why but it fails otherwise
			axes = _minimize_obb_volume(in_positions, axes.duplicate(), axis, centroid)
		basis = Basis(axes[0], axes[1], axes[2]).orthonormalized()
		axes = [basis[0], basis[1], basis[2]]
	elif is_planar:
		var shorter_axis: int = eigenvalues.find(sorted_eigen[0])
		assert(shorter_axis in [0, 1, 2])
		axes = _minimize_obb_volume(in_positions, axes.duplicate(), shorter_axis, centroid)
		basis = Basis(axes[0], axes[1], axes[2]).orthonormalized()
		axes = [basis[0], basis[1], basis[2]]
	else:
		for axis: Vector3.Axis in [Vector3.AXIS_Z, Vector3.AXIS_X, Vector3.AXIS_Y]:
			if _is_symmetry_axis(axis, basis, in_positions):
				const AXIS_TO_ROTATE = {
					Vector3.AXIS_X : Vector3.AXIS_Z,
					Vector3.AXIS_Y : Vector3.AXIS_X,
					Vector3.AXIS_Z : Vector3.AXIS_Y,
				}
				var target_dir: Vector3 = Plane(basis[axis], 0).project(Basis()[AXIS_TO_ROTATE[axis]]).normalized()
				var angle: float = axis_y.signed_angle_to(target_dir, axis_z)
				basis = basis.rotated(axis_z, angle)
		axes = [basis[0], basis[1], basis[2]]

	# 9. With handiness corrected, this breaks extents, so need to recalculate them
	min_extents = Vector3.INF
	max_extents = -Vector3.INF
	for p: Vector3 in in_positions:
		for i in 3:
			var projection := p.dot(axes[i])
			min_extents[i] = min(min_extents[i], projection)
			max_extents[i] = max(max_extents[i], projection)
	size = max_extents - min_extents

	var center := Vector3.ZERO
	center += ((min_extents.x + max_extents.x) / 2.0) * axes[0]
	center += ((min_extents.y + max_extents.y) / 2.0) * axes[1]
	center += ((min_extents.z + max_extents.z) / 2.0) * axes[2]
	
	return OBB.new(size, Transform3D(basis, center), in_source)


func _get_eigenvalues(cov_matrix: Array[PackedFloat64Array]) -> Dictionary:
	var eigenvectors: Array[Vector3]
	var eigenvalues: Array[float]
	for _axis in 3:
		# Power iteration
		const MAX_ITERATIONS := 100
		const CONVERGENCE_THRESHOLD_SQRD := 1e-12 # 1e-6 * 1e-6
		var v := Vector3(1.0, 1.0, 1.0)
		for _iter in MAX_ITERATIONS:
			var va := [v.x, v.y, v.z]
			var new_v := Vector3(
				cov_matrix[0][0]*va[0] + cov_matrix[0][1]*va[1] + cov_matrix[0][2]*va[2],
				cov_matrix[1][0]*va[0] + cov_matrix[1][1]*va[1] + cov_matrix[1][2]*va[2],
				cov_matrix[2][0]*va[0] + cov_matrix[2][1]*va[1] + cov_matrix[2][2]*va[2]
			).normalized()
			if new_v.distance_squared_to(v) < CONVERGENCE_THRESHOLD_SQRD:
				break
			v = new_v
		eigenvectors.append(v)
		
		# Deflation: A_next = A - lambda * v * vT
		var va := [v.x, v.y, v.z]
		var Av := [
			cov_matrix[0][0]*va[0] + cov_matrix[0][1]*va[1] + cov_matrix[0][2]*va[2],
			cov_matrix[1][0]*va[0] + cov_matrix[1][1]*va[1] + cov_matrix[1][2]*va[2],
			cov_matrix[2][0]*va[0] + cov_matrix[2][1]*va[1] + cov_matrix[2][2]*va[2]
		]
		var lam: float = va[0]*Av[0] + va[1]*Av[1] + va[2]*Av[2]
		eigenvalues.append(lam)
		
		if v == Vector3.ZERO:
			continue
		
		if v == Vector3.ZERO:
			continue  # skip deflation for degenerate axis
		
		for i in 3:
			for j in 3:
				cov_matrix[i][j] -= lam * va[i] * va[j]
	return {
		&"eigenvectors" : eigenvectors,
		&"eigenvalues" : eigenvalues,
	}


func _get_covariance_matrix(in_atoms_positions: Array[Vector3], in_centroid: Vector3) -> Array[PackedFloat64Array]:
	var cov_matrix: Array[PackedFloat64Array] = [
		PackedFloat64Array([0.0, 0.0, 0.0]),
		PackedFloat64Array([0.0, 0.0, 0.0]),
		PackedFloat64Array([0.0, 0.0, 0.0])
	]
	for p: Vector3 in in_atoms_positions:
		var local_pos := p - in_centroid
		for i in 3:
			for j in 3:
				cov_matrix[i][j] += local_pos[i] * local_pos[j]
	return cov_matrix


func _is_symmetry_axis(axis: Vector3.Axis, basis: Basis, in_positions: Array[Vector3]) -> bool:
	var plane_points: Array[Vector3] = []
	plane_points.assign(in_positions.map(
		func(point: Vector3) -> Vector3:
			point = basis.inverse() * point
			point[axis] = 0
			return point
	))
	
	# Centroid of projected points
	var centroid := Vector3.ZERO
	for point: Vector3 in plane_points:
		centroid += point
	centroid /= plane_points.size()
	
	var cov: Array[PackedFloat64Array] = _get_covariance_matrix(plane_points, centroid)
	var eigen_values: Array[float] = _get_eigenvalues(cov).eigenvalues
	var other_axes: Array[int] = [0, 1, 2]
	other_axes.erase(axis)
	const SYMMETRY_THRESHOLD: float = 0.1
	var max_plane_eigen: float = max(eigen_values[other_axes[0]], eigen_values[other_axes[1]])
	var is_isotropic: bool = abs(eigen_values[other_axes[0]] - eigen_values[other_axes[1]]) < SYMMETRY_THRESHOLD * max_plane_eigen
	return is_isotropic


func _minimize_obb_volume(positions: Array[Vector3], initial_axes: Array[Vector3], rotation_axis: int, centroid: Vector3) -> Array[Vector3]:
	const ANGLE_STEPS := 3
	var angle_range_min: float = 0.0
	var angle_range_max: float = PI / 2.0
	
	
	var other_axes: Array[int] = [0, 1, 2]
	other_axes = other_axes.filter(func(a: int) -> bool: return a != rotation_axis)
	
	var best_axes := initial_axes
	var best_volume := INF
	
	# Calculate original volume
	var axis_min: float = INF
	var axis_max: float = -INF
	var local_points: Array[Vector3]
	for p in positions:
		local_points.append(p - centroid)
		for i in 3:
			var proj := local_points[-1].dot(initial_axes[i])
			axis_min = min(axis_min, proj)
			axis_max = max(axis_max, proj)
	
	
	const BEST_ANGLE_THRESSHOLD = deg_to_rad(0.1)
	var iteration_count:int = 0
	var is_first_iteration: bool = true
	while angle_range_max - angle_range_min > BEST_ANGLE_THRESSHOLD:
		iteration_count += 1
		var sub_range: float = (angle_range_max - angle_range_min) / float(ANGLE_STEPS)
		var best_step: int = -1
		for step: float in ANGLE_STEPS: # find the best of 3 slices
			if not is_first_iteration and step == 1:
				#This angle was tested previous iteration
				if best_step == -1:
					best_step = 1
				continue
			var angle := angle_range_min + (step + 0.5) * sub_range
			var rotated_axes := initial_axes.duplicate()
			rotated_axes[other_axes[0]] = initial_axes[other_axes[0]].rotated(initial_axes[rotation_axis], angle)
			rotated_axes[other_axes[1]] = initial_axes[other_axes[1]].rotated(initial_axes[rotation_axis], angle)
			
			# Compute volume for this orientation
			var min_e := Vector3.INF
			var max_e := -Vector3.INF
			min_e[rotation_axis] = axis_min
			max_e[rotation_axis] = axis_max
			for local in local_points:
				for i in other_axes:
					var proj := local.dot(rotated_axes[i])
					min_e[i] = min(min_e[i], proj)
					max_e[i] = max(max_e[i], proj)
			var size := max_e - min_e
			var volume := size.x * size.y * size.z
			
			if volume < best_volume:
				best_volume = volume
				best_axes = rotated_axes
				best_step = int(step)
		is_first_iteration = false
		if best_step == -1:
			print("break after ", iteration_count, " and range ", rad_to_deg(angle_range_max - angle_range_min))
			break
		angle_range_min += best_step * sub_range
		angle_range_max = angle_range_min + sub_range
	var basis := Basis(best_axes[0], best_axes[1], best_axes[2]).orthonormalized()
	return [basis[0], basis[1], basis[2]]


func _subdivide_molecules(in_atoms: PackedInt32Array) -> Array[PackedInt32Array]:
	var molecules: Array[PackedInt32Array] = []
	var remaining_atoms: Array[int] = []
	remaining_atoms.assign(in_atoms)
	var visited: Dictionary[int, bool] = {}
	var atomic_structure := nano_structure as AtomicStructure
	while not remaining_atoms.is_empty():
		var molecule_first_atom_id: int = remaining_atoms.pop_back()
		var mol: PackedInt32Array = [molecule_first_atom_id]
		molecules.append(mol)
		visited[molecule_first_atom_id] = true
		var next_round: Array[int]
		for bond_id: int in atomic_structure.atom_get_bonds(molecule_first_atom_id):
			var other_atom: int = atomic_structure.atom_get_bond_target(molecule_first_atom_id, bond_id)
			if visited.get(other_atom, false) == true:
				continue
			next_round.append(other_atom)
		while not next_round.is_empty():
			var this_round: Array[int] = next_round
			next_round = []
			for atom_id: int in this_round:
				visited[atom_id] = true
				if not atom_id in in_atoms:
					continue
				var pos_in_queue: int = remaining_atoms.find(atom_id)
				if pos_in_queue != -1:
					remaining_atoms.remove_at(pos_in_queue)
					mol.append(atom_id)
					for bond_id: int in atomic_structure.atom_get_bonds(atom_id):
						var other_atom: int = atomic_structure.atom_get_bond_target(atom_id, bond_id)
						if visited.get(other_atom, false) == true:
							continue
						next_round.append(other_atom)
	return molecules

func get_selection_snapshot() -> Dictionary:
	return _selection_db.get_selection_snapshot()


func apply_selection_snapshot(in_snapshot: Dictionary) -> void:
	return _selection_db.apply_selection_snapshot(in_snapshot)


func set_atoms_visibility(in_atoms: PackedInt32Array, visible: bool) -> void:
	nano_structure.set_atoms_visibility(in_atoms, visible)


func set_bonds_visibility(in_bonds: PackedInt32Array, visible: bool) -> void:
	nano_structure.set_bonds_visibility(in_bonds, visible)


func set_springs_visibility(in_springs: PackedInt32Array, in_visible: bool) -> void:
	nano_structure.set_springs_visibility(in_springs, in_visible)


func get_hidden_atoms() -> PackedInt32Array:
	return nano_structure.get_hidden_atoms()


func get_hidden_bonds() -> PackedInt32Array:
	return nano_structure.get_hidden_bonds()


func get_hidden_springs() -> PackedInt32Array:
	return nano_structure.springs_get_hidden()


func get_visibility_snapshot() -> AtomicStructure.VisibilitySnapshot:
	assert(nano_structure is AtomicStructure)
	return nano_structure.get_visibility_snapshot()


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"int_guid" = int_guid,
		"_init_called" = _init_called,
		"_is_editable_dirty" = _is_editable_dirty,
		"_is_editable" = _is_editable,
		"_template_nano_struct_ref" = _template_nano_struct_ref,
		"_collision_engine" = _collision_engine.create_state_snapshot(),
		"selection_db" = _selection_db.get_selection_snapshot(),
		"signals" = History.create_signal_snapshot_for_object(self),
	}
	if is_instance_valid(_template_nano_struct_ref):
		snapshot["_template_nano_struct_ref.snapshot"] = _template_nano_struct_ref.create_state_snapshot()
	
	return snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	int_guid = in_state_snapshot["int_guid"]
	_init_called = in_state_snapshot["_init_called"]
	_is_editable_dirty = in_state_snapshot["_is_editable_dirty"]
	_is_editable = in_state_snapshot["_is_editable"]
	_template_nano_struct_ref = in_state_snapshot["_template_nano_struct_ref"]
	if is_instance_valid(_template_nano_struct_ref):
		_template_nano_struct_ref.apply_state_snapshot(in_state_snapshot["_template_nano_struct_ref.snapshot"])
	
	History.apply_signal_snapshot_to_object(self, in_state_snapshot["signals"])
	#_collision_engine.apply_state_snapshot(in_state_snapshot["_collision_engine"]) # TODO
	_collision_engine.rebuild(self)
	_selection_db.apply_selection_snapshot(in_state_snapshot["selection_db"])


func apply_visibility_snapshot(in_snapshot: AtomicStructure.VisibilitySnapshot) -> void:
	assert(nano_structure is AtomicStructure)
	nano_structure.apply_visibility_snapshot(in_snapshot)


func has_hidden_atoms_bonds_springs_or_motor_links() -> bool:
	if nano_structure is AtomicStructure:
		return nano_structure.has_hidden_atoms_bonds_springs_or_motor_links()
	return false


func _on_selection_db_selection_changed() -> void:
	selection_changed.emit()


func _on_selection_db_atom_selection_changed() -> void:
	atom_selection_changed.emit()


func _on_selection_db_atoms_deselected(in_deselected_atoms: PackedInt32Array) -> void:
	atoms_deselected.emit(in_deselected_atoms)


func _on_virtual_object_selection_changed(is_selected: bool) -> void:
	virtual_object_selection_changed.emit(is_selected)


func _on_dna_control_points_selection_changed() -> void:
	dna_control_points_selection_changed.emit()


func _on_dna_control_points_deselected(in_deselected_control_points: PackedInt32Array) -> void:
	dna_control_points_deselected.emit(in_deselected_control_points)
