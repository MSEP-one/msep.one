extends DynamicContextControl


const GENERATED_BOND_ORDER: int = 1

var _workspace_context: WorkspaceContext = null
var _did_create_undo_action: bool = false
var _new_bonds_created: int = 0

@onready var _max_bond_distance_slider: SpinBoxSlider = %MaxBondDistanceSlider
@onready var _option_selected_atoms: CheckBox = %OptionSelectedAtoms
@onready var _auto_create_bonds_button: Button = %AutoCreateBondsButton
@onready var _no_selection_label: Label = %NoSelectionLabel


func _ready() -> void:
	var max_distance: float = ProjectSettings.get_setting(&"msep/heuristic_bond_assignment/max_length_factor", 3.0)
	_max_bond_distance_slider.set_value_no_signal(max_distance)
	
	_option_selected_atoms.toggled.connect(_on_option_toggled)
	_auto_create_bonds_button.pressed.connect(_on_auto_create_bonds_button_pressed)
	_max_bond_distance_slider.value_changed.connect(_on_max_bond_distance_slider_value_changed)


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	_ensure_initialized(in_workspace_context)
	return in_workspace_context.create_object_parameters.get_create_mode_type() \
			== CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS


# region: internal

func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		in_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		in_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
		_update_panel_state()


func _update_panel_state() -> void:
	_no_selection_label.self_modulate.a = 0.0
	_auto_create_bonds_button.disabled = false
	var has_selected_atoms: bool = false
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	for structure: StructureContext in workspace_context.get_visible_structure_contexts():
		if structure.get_selected_atoms().size() > 0:
			has_selected_atoms = true
			break
	
	if _option_selected_atoms.button_pressed and not has_selected_atoms:
		_no_selection_label.self_modulate.a = 1.0
		_auto_create_bonds_button.disabled = true


func _auto_create_bonds_async(out_context: StructureContext, in_selected_atoms_only: bool) -> void:
	var atoms: PackedInt32Array
	var selected_atoms: PackedInt32Array = out_context.get_selected_atoms()
	if in_selected_atoms_only:
		atoms = selected_atoms
	else:
		atoms = out_context.nano_structure.get_visible_atoms()
	var nano_structure: NanoStructure = out_context.nano_structure
	var autobonder_atoms: Dictionary = {
		#atom:HeuristicBondAssignmentUtility.Atom = nano_structure_atom_id:int
	}
	var autobonder_bonds: Dictionary = {
		#bond:HeuristicBondAssignmentUtility.Bond = nano_structure_bond_id: int
	}
	var in_atoms: Array[HeuristicBondAssignmentUtility.Atom] = []
	var in_bonds: Array[HeuristicBondAssignmentUtility.Bond] = []
	var atom_id_to_heuristic_atom: Dictionary = {
		# atom_id<int>, atom_data<HeuristicBondAssignmentUtility.Atom>,
	}
	# 1. Define Atoms
	for atom_id in atoms:
		var atom_type: String = PeriodicTable.get_by_atomic_number(
			nano_structure.atom_get_atomic_number(atom_id)
		).symbol
		var atom := HeuristicBondAssignmentUtility.Atom.new(
			nano_structure.atom_get_position(atom_id),
			atom_type
		)
		autobonder_atoms[atom] = atom_id
		in_atoms.push_back(atom)
		atom_id_to_heuristic_atom[atom_id] = atom
	# 2. Define existing Bonds
	for atom_id in atoms:
		var known_bonds_ids: PackedInt32Array = nano_structure.atom_get_bonds(atom_id)
		for bond_id in known_bonds_ids:
			if autobonder_bonds.find_key(bond_id) != null:
				# Was already added by the other atom_id
				continue
			var other_atom_id: int = nano_structure.atom_get_bond_target(atom_id, bond_id)
			if !atoms.has(other_atom_id):
				atom_id_to_heuristic_atom[atom_id].unspecified_bond_count += 1
				# Target atom is not selected, skip
				continue
			var atom1: HeuristicBondAssignmentUtility.Atom = autobonder_atoms.find_key(atom_id)
			var atom2: HeuristicBondAssignmentUtility.Atom = autobonder_atoms.find_key(other_atom_id)
			var bond := HeuristicBondAssignmentUtility.Bond.new(
				atom1, atom2
			)
			autobonder_bonds[bond] = bond_id
			in_bonds.push_back(bond)
	var promise: Promise = Promise.new()
	var thread := Thread.new()
	thread.start(_create_bonds_in_thread.bind(in_atoms, in_bonds, promise))
	await promise.wait_for_fulfill()
	thread.wait_to_finish()
	thread = null
	assert(not promise.has_error(), "HeuristicBondAssignmentUtility cannot fail!")
	var bond_candidates: Array[HeuristicBondAssignmentUtility.Bond] = promise.get_result()
	var new_bonds_in_this_structure: bool = false
	var new_partially_influenced_bonds: PackedInt32Array = PackedInt32Array()
	var new_highlighted_bonds: PackedInt32Array = PackedInt32Array()
	for bond in bond_candidates:
		var is_new: bool = not autobonder_bonds.has(bond)
		if is_new:
			if !_did_create_undo_action:
				_did_create_undo_action = true
			if !new_bonds_in_this_structure:
				new_bonds_in_this_structure = true
				nano_structure.start_edit()
			var atom_id1: int = autobonder_atoms[bond.atoms[0]]
			var atom_id2: int = autobonder_atoms[bond.atoms[1]]
			
			var new_bond_id: int = nano_structure.add_bond(atom_id1, atom_id2, GENERATED_BOND_ORDER)
			if new_bond_id == AtomicStructure.INVALID_BOND_ID:
				# Bond between atom_id1 and atom_id2 already exists
				continue
			if atom_id1 in selected_atoms and atom_id2 in selected_atoms:
				new_highlighted_bonds.append(new_bond_id)
			else:
				new_partially_influenced_bonds.append(new_bond_id)
			_new_bonds_created += 1
	
	if new_bonds_in_this_structure:
		nano_structure.end_edit()
		# Workaround for bonds not moving together with selected atoms: this highlight_atoms()
		# call notifies renderer that new bonds are connected to selected atoms (and movement
		# of those atoms should should influence them).
		# If we will have more cases where bonds could be created without being selected then 
		# we should introduce new logic/api at the junction of NanoStructure / Renderer to deal
		# with such situation instead of using this workaround
		var rendering: Rendering = out_context.get_rendering()
		rendering.highlight_atoms(selected_atoms, nano_structure, new_partially_influenced_bonds, [])
		out_context.select_bonds(new_highlighted_bonds)
		

func _create_bonds_in_thread(
		in_atoms: Array[HeuristicBondAssignmentUtility.Atom],
		in_bonds: Array[HeuristicBondAssignmentUtility.Bond],
		out_promise: Promise) -> void:
	var bond_candidates: Array[HeuristicBondAssignmentUtility.Bond] = \
			HeuristicBondAssignmentUtility.heuristic_bond_assignment(in_atoms, in_bonds)
	out_promise.fulfill.call_deferred(bond_candidates)


func _on_auto_create_bonds_button_pressed() -> void:
	var visible_structure_contexts: Array[StructureContext] = \
		_workspace_context.get_visible_structure_contexts()
	
	_new_bonds_created = 0
	_workspace_context.start_async_work(tr("Creating Bonds"))
	for context: StructureContext in visible_structure_contexts:
		if context.nano_structure is AtomicStructure:
			await _auto_create_bonds_async(context, _option_selected_atoms.button_pressed)
	_workspace_context.end_async_work()
	_workspace_context.bonds_auto_created.emit(_new_bonds_created)
	if _did_create_undo_action:
		_workspace_context.snapshot_moment("Automatically Create Bonds")


func _on_max_bond_distance_slider_value_changed(value: float) -> void:
	ProjectSettings.set_setting(&"msep/heuristic_bond_assignment/max_length_factor", value)


func _on_option_toggled(_enabled: bool) -> void:
	ScriptUtils.call_deferred_once(_update_panel_state)


func _on_workspace_context_selection_in_structures_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_update_panel_state)


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_update_panel_state)
