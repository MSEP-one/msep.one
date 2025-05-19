class_name StructureContext extends Node

const DATABASE_DIRECTORY = "/workspace_databases/"

signal selection_changed()
signal atom_selection_changed()
signal atoms_deselected(in_deselected_atoms: PackedInt32Array)
signal virtual_object_selection_changed(is_selected: bool)

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
	return is_any_atom_selected() or _selection_db.is_virtual_object_selected()


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


func select_connected(in_show_hidden_objects: bool = false) -> void: 
	return _selection_db.select_connected(in_show_hidden_objects)


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
