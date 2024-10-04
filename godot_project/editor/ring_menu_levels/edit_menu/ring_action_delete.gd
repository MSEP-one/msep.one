class_name RingActionDelete extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null
var _did_create_undo_action: bool = false

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Delete"),
		_execute_action,
		tr("Delete all selected objects")
	)
	with_validation(can_delete)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_edit/icons/icon_delete_x96.svg"))


func can_delete() -> bool:
	if !is_instance_valid(_workspace_context):
		return false
	var selected_structures_contexts: Array[StructureContext] = \
			_workspace_context.get_structure_contexts_with_selection()
	return not selected_structures_contexts.is_empty()


func _execute_action() -> void:
	var was_ring_menu_active: bool = _ring_menu.is_active()
	_ring_menu.close()
	var selected_structures_contexts: Array[StructureContext] = \
			_workspace_context.get_structure_contexts_with_selection()
	_did_create_undo_action = false
	var deleted_structures_contexts: Array[StructureContext] = []
	for context in selected_structures_contexts:
		_delete_selection_of_structure(context, deleted_structures_contexts)
	if _did_create_undo_action:
		if !was_ring_menu_active:
			# When ring menu was open we avoid playing a Sfx, because "close menu"
			#+is already being played
			EditorSfx.delete_object()
		_workspace_context.snapshot_moment("Delete Selection")


func _delete_selection_of_structure(out_context: StructureContext, out_already_deleted_contexts: Array[StructureContext]) -> void:
	if _can_delete_objects(out_context):
		_action_delete_objects(out_context, out_already_deleted_contexts)
		return
	if _can_delete_atoms_bonds_or_springs(out_context):
		_action_delete_atoms_bonds_springs(out_context)


func _action_delete_atoms_bonds_springs(context: StructureContext) -> void:
	if !_did_create_undo_action:
		_did_create_undo_action = true
	_delete_selection(context)


func _action_delete_objects(context: StructureContext, out_already_deleted_contexts: Array[StructureContext]) -> void:
	if out_already_deleted_contexts.has(context):
		return
	var workspace: Workspace = _workspace_context.workspace
	if !_did_create_undo_action:
		_did_create_undo_action = true
	# 1. Find fully selected objects
	var objects_to_delete: Array[StructureContext] = [context]
	# 2. Expand to also delete child objects
	var added_something: = true
	while added_something:
		added_something = false
		for parent: StructureContext in objects_to_delete.duplicate():
			for child in workspace.get_child_structures(parent.nano_structure):
				var child_context: StructureContext = _workspace_context.get_nano_structure_context(child)
				if objects_to_delete.has(child_context):
					continue
				objects_to_delete.push_back(child_context)
				added_something = true
			if parent.nano_structure is NanoVirtualAnchor:
				var anchor := parent.nano_structure as NanoVirtualAnchor
				var structures_ids: PackedInt32Array = anchor.get_related_structures()
				for structure_id: int in structures_ids:
					if not workspace.has_structure_with_int_guid(structure_id):
						# Structure was removed from Workspace
						# Reference is not removed from anchor in case it's deletion is undone
						continue
					var atomic_structure: AtomicStructure = workspace.get_structure_by_int_guid(structure_id) as AtomicStructure
					var related_springs: PackedInt32Array = anchor.get_related_springs(structure_id)
					var springs_hidden_snapshot: Dictionary = atomic_structure.get_visibility_snapshot().hidden_springs
					# Make all springs visible before deleting them
					atomic_structure.set_springs_visibility(springs_hidden_snapshot.keys(), true)
					_remove_springs(atomic_structure, related_springs)
	
	# 3. Find the new active structure
	var activate_structure: NanoStructure = _workspace_context.get_current_structure_context().nano_structure
	assert(activate_structure, "Invalid current StructureContext")
	while activate_structure != null and _workspace_context.get_nano_structure_context(activate_structure) in objects_to_delete:
		var parent_guid: int = activate_structure.int_parent_guid
		if parent_guid == Workspace.INVALID_STRUCTURE_ID:
			activate_structure = null
		else:
			activate_structure = workspace.get_structure_by_int_guid(parent_guid)
	# 4. If no active structure among parents, search in the root
	if activate_structure == null:
		# Find the first non deleted structure
		var structures: Array = workspace.get_structures()
		for structure: NanoStructure in structures:
			if !_workspace_context.get_nano_structure_context(structure) in objects_to_delete:
				activate_structure = structure
				break
	# 5. Still nothing found? All deleted? well, let's keep Main Structure
	if activate_structure == null:
		var structures: Array = workspace.get_structures()
		activate_structure = structures.front() as NanoStructure
		objects_to_delete.erase(_workspace_context.get_nano_structure_context(activate_structure))
		# Instead just remove it's atoms
		var activate_context: StructureContext = _workspace_context.get_nano_structure_context(activate_structure)
		activate_context.select_all()
		_delete_selection(activate_context)
	assert(activate_structure, "Could not find a structure to activate, this should not happen")
	_workspace_context.activate_nano_structure(activate_structure)
	
	# 7. Remove the objects
	objects_to_delete.reverse()
	for object: StructureContext in objects_to_delete:
		if out_already_deleted_contexts.has(object):
			continue
		out_already_deleted_contexts.push_back(object)
		workspace.remove_structure(object.nano_structure)


func _remove_springs(out_nano_structure: AtomicStructure, in_springs_to_remove: PackedInt32Array) -> void:
	out_nano_structure.start_edit()
	for spring_id: int in in_springs_to_remove:
		if not out_nano_structure.spring_has(spring_id):
			# spring already removed either by anchor, atom or directly
			continue
		out_nano_structure.spring_invalidate(spring_id)
	out_nano_structure.end_edit()


func _can_delete_atoms_bonds_or_springs(in_context: StructureContext) -> bool:
	# At least one atom is selected
	if in_context.is_any_atom_selected() or in_context.is_any_bond_selected() or in_context.is_any_spring_selected():
		return true
	return false


## Delete the selected atoms / bonds in a structure and the connected springs.
## The UndoRedo property backward_undo_ops must be enabled for this function to work properly.
func _delete_selection(out_context: StructureContext) -> void:
	if !is_instance_valid(out_context.nano_structure) || !out_context.has_selection():
		return
	assert(_did_create_undo_action, "This method must be used after a call to undo_redo.create_action(..., backward_undo_ops = true)")
	if not out_context.nano_structure is AtomicStructure:
		return
	var nano_struct: AtomicStructure = out_context.nano_structure as AtomicStructure
	var atoms: PackedInt32Array = out_context.get_selected_atoms()
	var bonds: PackedInt32Array = []
	var selected_bonds: PackedInt32Array = out_context.get_selected_bonds()
	var bonds_dic: Dictionary = {}
	var springs: PackedInt32Array = out_context.get_selected_springs()
	var spring_dict: Dictionary = {}
	for bond_id in selected_bonds:
		bonds_dic[bond_id] = true
	for spring_id in springs:
		spring_dict[spring_id] = true
	for atom_id in atoms:
		for bond_id in nano_struct.atom_get_bonds(atom_id):
			bonds_dic[bond_id] = true
		var related_springs: PackedInt32Array = nano_struct.atom_get_springs(atom_id)
		for spring_id: int in related_springs:
			spring_dict[spring_id] = true
	bonds = PackedInt32Array(bonds_dic.keys())
	springs = PackedInt32Array(spring_dict.keys())

	# Make all springs visible before deleting them, TODO: might not be necessary
	var springs_hidden_snapshot: Dictionary = nano_struct.get_visibility_snapshot().hidden_springs
	nano_struct.set_springs_visibility(springs_hidden_snapshot.keys(), true)
	_do_remove_atoms_bonds_springs(out_context, atoms, bonds, springs)


func _do_remove_atoms_bonds_springs(out_context: StructureContext, in_atoms: PackedInt32Array,
			in_bonds: PackedInt32Array, in_springs: PackedInt32Array) -> void:
	out_context.clear_selection()
	out_context.nano_structure.start_edit()
	for bond_id in in_bonds:
		out_context.nano_structure.remove_bond(bond_id)
	for atom_id in in_atoms:
		out_context.nano_structure.remove_atom(atom_id)
	for spring_id in in_springs:
		var is_already_removed_by_anchor: bool = not out_context.nano_structure.spring_has(spring_id)
		if not is_already_removed_by_anchor:
			out_context.nano_structure.spring_invalidate(spring_id)
	out_context.nano_structure.end_edit()


func _can_delete_objects(in_context: StructureContext) -> bool:
	if in_context.is_queued_for_deletion():
		return false
	
	# All child structures are fully selected
	if not in_context.workspace_context.workspace.has_structure(in_context.nano_structure):
		return false
	
	var all_atoms_selected: bool = (not in_context.nano_structure is AtomicStructure) or \
			in_context.get_selected_atoms().size() == in_context.nano_structure.get_valid_atoms_count()
	var shape_selected: bool = true \
			if not in_context.nano_structure is NanoShape else in_context.is_shape_selected()
	var motor_selected: bool = true \
			if not in_context.nano_structure is NanoVirtualMotor else in_context.is_motor_selected()
	var anchor_selected: bool = true \
			if not in_context.nano_structure is NanoVirtualAnchor else in_context.is_anchor_selected()
	
	var child_structures: Array[NanoStructure] = \
			in_context.workspace_context.workspace.get_child_structures(in_context.nano_structure)
	for child: NanoStructure in child_structures:
		var child_context: StructureContext = in_context.workspace_context.get_nano_structure_context(child)
		if not _can_delete_objects(child_context):
			return false
	
	if all_atoms_selected and shape_selected and motor_selected and anchor_selected:
		return true
	return false
