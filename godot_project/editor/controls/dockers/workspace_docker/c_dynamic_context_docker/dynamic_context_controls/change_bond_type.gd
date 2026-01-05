extends DynamicContextControl


var _immutable_atoms_info_label: InfoLabel
var _label_describe_change: Label = null
var _button_single: Button = null
var _button_double: Button = null
var _button_triple: Button = null


var _workspace_context: WorkspaceContext


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_immutable_atoms_info_label = %ImmutableAtomsInfoLabel as InfoLabel
		_label_describe_change = %LabelDescribeChange
		_button_single = %ButtonSingle as Button
		_button_double = %ButtonDouble as Button
		_button_triple = %ButtonTriple as Button
		_button_single.pressed.connect(_on_bond_order_change_requested.bind(1))
		_button_double.pressed.connect(_on_bond_order_change_requested.bind(2))
		_button_triple.pressed.connect(_on_bond_order_change_requested.bind(3))
		

func _on_bond_order_change_requested(in_order: int) -> void:
	_change_order_of_selected_atoms(in_order)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_workspace_context = in_workspace_context
	if !in_workspace_context.selection_in_structures_changed.is_connected(_on_workspace_context_selection_in_structures_changed):
		in_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		in_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
	
	var rendering: Rendering = in_workspace_context.get_rendering()
	if not rendering.representation_changed.is_connected(_on_rendering_representation_changed):
		rendering.representation_changed.connect(_on_rendering_representation_changed.unbind(1))
	_update_availability()
	
	var selected_contexts: Array[StructureContext] =  \
			in_workspace_context.get_structure_contexts_with_selection()
	for context in selected_contexts:
		if context.get_selected_bonds().size() > 0:
			_update_availability()
			return true
	return false


func _on_workspace_context_selection_in_structures_changed(_structure_context: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_update_availability)


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_update_availability)


func _on_rendering_representation_changed() -> void:
	ScriptUtils.call_deferred_once(_update_availability)


func _update_availability() -> void:
	var representation: Rendering.Representation = _workspace_context.workspace.representation_settings.get_rendering_representation()
	var representation_allows_editing: bool = representation != Rendering.Representation.STICKS
	var selected_count: int = 0
	var has_immutable_objects: bool = false
	if _workspace_context != null:
		var selected_contexts: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
		for context in selected_contexts:
			if context.nano_structure is AtomicStructure and context.nano_structure.can_create_and_delete_atoms() == false:
				if context.get_selected_bonds().size():
					has_immutable_objects = true
				continue
			selected_count += context.get_selected_bonds().size()
	var can_be_edited_by_user: bool = selected_count > 0 and representation_allows_editing
	_button_single.disabled = not can_be_edited_by_user
	_button_double.disabled = not can_be_edited_by_user
	_button_triple.disabled = not can_be_edited_by_user
	_immutable_atoms_info_label.visible = has_immutable_objects
	
	if not representation_allows_editing:
		_label_describe_change.text = tr(&"Cannot change bond order in Sticks representation")
	elif selected_count == 0:
		_label_describe_change.text = tr(&"No Bonds selected")
	else:
		_label_describe_change.text = tr(&"Change {0} selected Bonds to...").format([selected_count])


func _change_order_of_selected_atoms(in_selected_bond_order: int) -> void:
	EditorSfx.mouse_down()
	var selected_contexts: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
	for context in selected_contexts:
		if context.nano_structure is AtomicStructure and context.nano_structure.can_create_and_delete_atoms() == false:
			continue
		var selected_bonds: PackedInt32Array = context.get_selected_bonds()
		if selected_bonds.size() == 0:
			continue
		var new_bonds: Dictionary = {}
		var old_bonds: Dictionary = {}
		for bond_id in selected_bonds:
			new_bonds[bond_id] = in_selected_bond_order
			# x = atom_a_id, y = atom_b_id, z = bond order
			old_bonds[bond_id] = context.nano_structure.get_bond(bond_id).z
		
		_do_change_order_of_bonds(context, new_bonds)
		context.set_bond_selection(new_bonds.keys())
	_workspace_context.snapshot_moment("Change Bond(s) Type")


func _do_change_order_of_bonds(in_structure_context: StructureContext, in_bonds: Dictionary) -> void:
	var structure: NanoStructure = in_structure_context.nano_structure
	structure.start_edit()
	for bond_id: int in in_bonds.keys():
		var bond_order: int = in_bonds[bond_id]
		structure.bond_set_order(bond_id, bond_order)
	structure.end_edit()
