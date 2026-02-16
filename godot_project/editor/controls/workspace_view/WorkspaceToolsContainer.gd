extends Control


var _workspace_context: WorkspaceContext


func _ready() -> void:
	_ready_deferred.call_deferred()


func _ready_deferred() -> void:
	var main_view: WorkspaceMainView = owner
	assert(main_view)
	_workspace_context = main_view.get_workspace_context()
	_workspace_context.hovered_structure_context_changed.connect(_on_hovered_structure_context_changed)


func _on_hovered_structure_context_changed(
			in_toplevel_hovered_structure_context: StructureContext,
			in_hovered_structure_context: StructureContext,
			in_atom_id: int,
			in_bond_id: int,
			in_spring_id: int,
			in_dna_control_point_idx: int) -> void:
	if in_hovered_structure_context != null and in_hovered_structure_context.nano_structure.is_virtual_object():
		_show_virtual_object_tooltip(in_hovered_structure_context)
	elif in_toplevel_hovered_structure_context == null:
		if in_atom_id != AtomicStructure.INVALID_ATOM_ID:
			_show_hovered_atom_tooltip(in_hovered_structure_context, in_atom_id)
		elif in_bond_id != AtomicStructure.INVALID_BOND_ID:
			_show_hovered_bond_tooltip(in_hovered_structure_context, in_bond_id)
		elif in_spring_id != AtomicStructure.INVALID_SPRING_ID:
			_show_hovered_spring_tooltip(in_hovered_structure_context, in_spring_id)
		else:
			tooltip_text = ""
	elif in_hovered_structure_context.nano_structure is DnaStructure and in_hovered_structure_context.nano_structure.get_edit_mode() == DnaStructure.EditMode.SequenceAndPath:
		if in_dna_control_point_idx == DnaStructure.INVALID_CONTROL_POINT_IDX:
			tooltip_text = _get_path_to_context(in_hovered_structure_context).rstrip("\n")
			tooltip_text += " (%s)" % in_hovered_structure_context.nano_structure.get_tooltip_text()
		else:
			_show_hovered_dna_control_point_tooltip(in_hovered_structure_context, in_dna_control_point_idx)
	elif in_spring_id != AtomicStructure.INVALID_SPRING_ID:
		_show_hovered_spring_tooltip(in_hovered_structure_context, in_spring_id)
		var group_path: String = _get_path_to_context(in_hovered_structure_context)
		if not group_path.is_empty():
			tooltip_text = group_path + tooltip_text
	else:
		tooltip_text = _get_path_to_context(in_hovered_structure_context)


func _show_hovered_atom_tooltip(in_hovered_structure_context: StructureContext, in_atom_id: int) -> void:
	var structure: AtomicStructure = in_hovered_structure_context.nano_structure as AtomicStructure
	assert(structure)
	var atomic_number: int = structure.atom_get_atomic_number(in_atom_id)
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
	var pos: Vector3 = structure.atom_get_position(in_atom_id)
	var attached_count: int = structure.atom_get_bonds(in_atom_id).size()
	var lone_pairs: int = structure.atom_get_remaining_valence(in_atom_id)
	var tooltip: String = ""
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_TOOLTIP_SHOW_IDS):
		tooltip += "%s (%s) #%d\n" % [tr(element_data.name), element_data.symbol, in_atom_id]
	else:
		tooltip += "%s (%s)\n" % [tr(element_data.name), element_data.symbol]
	tooltip += tr("Position: ") + str(pos) + "\n"
	if structure.atom_is_locked(in_atom_id):
		tooltip += tr("🔒 Locked in position")
	if attached_count:
		tooltip += tr("%d attached atoms\n") % attached_count
	if lone_pairs:
		tooltip += tr("%d lone pairs\n") % lone_pairs
	tooltip_text = tooltip


func _show_hovered_bond_tooltip(in_hovered_structure_context: StructureContext, in_bond_id: int) -> void:
	var structure: AtomicStructure = in_hovered_structure_context.nano_structure as AtomicStructure
	assert(structure)
	var bond: Vector3i = structure.get_bond(in_bond_id)
	var atom_a_element: int = structure.atom_get_atomic_number(bond.x)
	var atom_b_element: int = structure.atom_get_atomic_number(bond.y)
	var bond_order: int = bond.z
	var element_data_a: ElementData = PeriodicTable.get_by_atomic_number(atom_a_element)
	var element_data_b: ElementData = PeriodicTable.get_by_atomic_number(atom_b_element)
	var tooltip: String = ""
	var bond_symbol: String = ["ø", "-", "=", "≡"][bond_order]
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_TOOLTIP_SHOW_IDS):
		tooltip += "%s%s%s (Order %d) #%d\n" % [element_data_a.symbol, bond_symbol, element_data_b.symbol, bond_order, in_bond_id]
	else:
		tooltip += "%s%s%s (Order %d)\n" % [element_data_a.symbol, bond_symbol, element_data_b.symbol, bond_order]
	tooltip_text = tooltip


func _show_hovered_spring_tooltip(in_hovered_structure_context: StructureContext, in_spring_id: int) -> void:
	var structure: AtomicStructure = in_hovered_structure_context.nano_structure as AtomicStructure
	assert(structure)
	var target_position: Vector3 = structure.spring_get_target_position(in_spring_id, in_hovered_structure_context)
	var atom_position: Vector3 = structure.spring_get_atom_position(in_spring_id)
	var is_length_auto: bool = structure.spring_get_equilibrium_length_is_auto(in_spring_id)
	var length: float = structure.spring_get_current_equilibrium_length(in_spring_id, in_hovered_structure_context)
	var atom_id: int = structure.spring_get_atom_id(in_spring_id)
	var atomic_number: int = structure.atom_get_atomic_number(atom_id)
	var element_data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
	var tooltip: String = tr("Spring (%s)\n") % [element_data.name]
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_TOOLTIP_SHOW_IDS):
		tooltip = tr("Spring (%s) #%d\n") % [element_data.name, in_spring_id]
	if not structure.spring_is_atom_to_atom(in_spring_id):
		tooltip += tr("⚓ Anchored to %s\n") % str(target_position)
	tooltip += tr("Target length: %.3f nm%s\n") % [length, tr(" (auto)") if is_length_auto else ""]
	if not is_equal_approx(target_position.distance_squared_to(atom_position), length * length):
		tooltip += tr("Current legth: %.3f nm\n") % target_position.distance_to(atom_position)
	tooltip += tr("Force: %.2f nN/nm\n") % structure.spring_get_constant_force(in_spring_id)
	tooltip_text = tooltip


func _show_hovered_dna_control_point_tooltip(in_hovered_structure_context: StructureContext, in_dna_control_point_idx: int) -> void:
	var dna_structure: DnaStructure = in_hovered_structure_context.nano_structure as DnaStructure
	var tooltip: String = _get_path_to_context(in_hovered_structure_context).rstrip("\n")
	if FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_TOOLTIP_SHOW_IDS):
		tooltip += " (%s) #%d\n" % [dna_structure.get_tooltip_text(), in_dna_control_point_idx]
	else:
		tooltip += " (%s)\n" % dna_structure.get_tooltip_text()
	var pos: Vector3 = dna_structure.get_control_point_position(in_dna_control_point_idx)
	tooltip += tr("Control Point #%d: %s\n") % [in_dna_control_point_idx, str(pos)]
	tooltip_text = tooltip


func _show_virtual_object_tooltip(in_hovered_structure_context: StructureContext) -> void:
	var tooltip: String = ""
	var path: String = _get_path_to_context(in_hovered_structure_context)
	if path.get_slice_count("\n") > 2:
		tooltip += path
	tooltip += in_hovered_structure_context.nano_structure.get_tooltip_text()
	tooltip_text = tooltip


func _get_path_to_context(in_structure_context: StructureContext) -> String:
	var structure: NanoStructure = in_structure_context.nano_structure
	var active_context: StructureContext = _workspace_context.get_current_structure_context()
	var stack: Array[String] = []
	while _workspace_context.get_structure_context(structure.int_guid) != active_context:
		if not structure.is_virtual_object():
			stack.push_front(structure.get_structure_name())
		structure = _workspace_context.workspace.get_parent_structure(structure)
	var path := String()
	for i in stack.size():
		if i > 0:
			path += "     ".repeat(i-1) + " ⤷ " + stack[i] + "\n"
		else:
			path = stack[i] + "\n"
	return path
