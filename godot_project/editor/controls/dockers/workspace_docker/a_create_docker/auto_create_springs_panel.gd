extends DynamicContextControl

var _atom_to_anchor_button: Button
var _atom_to_atom_button: Button
var _max_spring_length_slider: SpinBoxSlider
var _no_selection_label: InfoLabel
var _auto_create_springs_button: Button



var _workspace_context: WorkspaceContext

var _has_atom_selection: bool
var _has_anchor_selection: bool


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_atom_to_anchor_button = %AtomToAnchorButton as Button
		_atom_to_atom_button = %AtomToAtomButton as Button
		_max_spring_length_slider = %MaxSpringLengthSlider as SpinBoxSlider
		_no_selection_label = %NoSelectionLabel as InfoLabel
		_auto_create_springs_button = %AutoCreateSpringsButton as Button


func _ready() -> void:
	_atom_to_anchor_button.button_group.pressed.connect(_on_spring_type_button_group_pressed.unbind(1))
	_auto_create_springs_button.pressed.connect(_on_auto_create_springs_button_pressed)


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_ensure_workspace_initialized(in_workspace_context)
	
	if not in_workspace_context.get_current_structure_context().nano_structure.can_contain_child_structure():
		return false
	
	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_ANCHORS_AND_SPRINGS:
		return false
	return true


func _ensure_workspace_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == in_workspace_context:
		return
	_workspace_context = in_workspace_context
	_workspace_context.selection_in_structures_changed.connect(_on_workspace_selection_changed.unbind(1))
	_update_selection_info_label()

func _on_workspace_selection_changed() -> void:
	_has_atom_selection = false
	_has_anchor_selection = false
	for ctx: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		if ctx.nano_structure is NanoVirtualAnchor:
			_has_anchor_selection = true
		elif ctx.get_selected_atoms().size() > 0:
			_has_atom_selection = true
	_update_selection_info_label()


func _on_spring_type_button_group_pressed() -> void:
	_update_selection_info_label()


func _update_selection_info_label() -> void:
	if _atom_to_anchor_button.button_pressed:
		match [_has_atom_selection, _has_anchor_selection]:
			[true, true]:
				_no_selection_label.hide()
			[true, false]:
				_no_selection_label.show()
				_no_selection_label.message = tr(&"No anchors selected.")
			[false, true]:
				_no_selection_label.show()
				_no_selection_label.message = tr(&"No atoms selected.")
			[false, false]:
				_no_selection_label.show()
				_no_selection_label.message = tr(&"No atoms or anchors selected.")
	else:
		if _has_atom_selection:
			_no_selection_label.hide()
		else:
			_no_selection_label.show()
			_no_selection_label.message = tr(&"No atoms selected.")
	
	_auto_create_springs_button.disabled = _no_selection_label.visible


func _on_auto_create_springs_button_pressed() -> void:
	if _atom_to_anchor_button.button_pressed:
		_create_atom_to_anchor_springs()
		return
	elif _atom_to_atom_button.button_pressed:
		_create_atom_to_atom_springs()
		return

func _create_atom_to_anchor_springs() -> void:
	var anchors: Array[StructureContext]
	var atoms: Dictionary[StructureContext, PackedInt32Array]
	
	for ctx: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		if ctx.nano_structure is NanoVirtualAnchor:
			anchors.append(ctx)
		var selected_atoms: PackedInt32Array = ctx.get_selected_atoms()
		if selected_atoms.size() > 0:
			atoms[ctx] = selected_atoms
	
	var max_distance_sqrd: float = _max_spring_length_slider.value * _max_spring_length_slider.value
	var constant_force: float = _workspace_context.create_object_parameters.get_spring_constant_force()
	var EQUILIBRIUM_LENGTH_IS_AUTO: bool = true
	var MANUAL_EQUILIBRIUM_LENGTH: float = 0.1
	var new_spring_count: int = 0
	for anchor: StructureContext in anchors:
		var anchor_id: int = anchor.get_int_guid()
		var anchor_pos: Vector3 = (anchor.nano_structure as NanoVirtualAnchor).get_position()
		for ctx: StructureContext in atoms.keys():
			var structure: AtomicStructure = ctx.nano_structure as AtomicStructure
			var springs_added: PackedInt32Array = []
			assert(structure)
			for atom_id: int in atoms[ctx]:
				var atom_pos: Vector3 = structure.atom_get_position(atom_id)
				if atom_pos.distance_squared_to(anchor_pos) > max_distance_sqrd:
					continue
				if structure.spring_to_anchor_exists(atom_id, anchor.get_int_guid()):
					continue
				if not structure.is_being_edited():
					structure.start_edit()
				var new_spring: int = structure.spring_create(
					anchor_id, atom_id, constant_force,
					EQUILIBRIUM_LENGTH_IS_AUTO, MANUAL_EQUILIBRIUM_LENGTH
				)
				springs_added.append(new_spring)
			if springs_added.size() > 0:
				structure.end_edit()
				ctx.select_springs(springs_added)
				new_spring_count += springs_added.size()
	if new_spring_count > 0:
		_workspace_context.snapshot_moment("Create %d Springs" % new_spring_count)

func _create_atom_to_atom_springs() -> void:
	var max_distance_sqrd: float = _max_spring_length_slider.value * _max_spring_length_slider.value
	var constant_force: float = _workspace_context.create_object_parameters.get_spring_constant_force()
	var EQUILIBRIUM_LENGTH_IS_AUTO: bool = true
	var MANUAL_EQUILIBRIUM_LENGTH: float = 0.1
	var new_spring_count: int = 0
	for ctx: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		var structure: AtomicStructure = ctx.nano_structure as AtomicStructure
		var springs_added: PackedInt32Array = []
		var atom_selection: PackedInt32Array = ctx.get_selected_atoms()
		if atom_selection.size() <= 1:
			continue
		var atom_pos: Dictionary[int, Vector3]
		for atom_id: int in atom_selection:
			atom_pos[atom_id] = structure.atom_get_position(atom_id)
		for i in atom_selection.size() - 1:
			for j in range(i + 1, atom_selection.size()):
				var atom1: int = atom_selection[i]
				var atom2: int = atom_selection[j]
				if atom_pos[atom1].distance_squared_to(atom_pos[atom2]) > max_distance_sqrd:
					continue
				if structure.spring_between_atoms_exists(atom1, atom2):
					continue
				var atom1_bonds: PackedInt32Array = structure.atom_get_bonds(atom1)
				for bond_id: int in atom1_bonds:
					if structure.atom_get_bond_target(atom1, bond_id) == atom2:
						# Bond exists
						continue
				if not structure.is_being_edited():
					structure.start_edit()
				var new_spring: int = structure.spring_create_between_atoms(
					atom1, atom2, constant_force,
					EQUILIBRIUM_LENGTH_IS_AUTO, MANUAL_EQUILIBRIUM_LENGTH
				)
				springs_added.append(new_spring)
			if springs_added.size() > 0:
				structure.end_edit()
				ctx.select_springs(springs_added)
				new_spring_count += springs_added.size()
	if new_spring_count > 0:
		_workspace_context.snapshot_moment("Create %d Springs" % new_spring_count)
