extends DynamicContextControl


var _particle_emitter_parameters_editor: ParticleEmitterParametersEditor
var _info_label: InfoLabel
var _create_from_selection_button: Button
var _create_from_small_molecules: Button
var _small_molecules_picker: SmallMoleculesPicker:
	get = _get_small_molecules_picker


var _workspace_context: WorkspaceContext = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_particle_emitter_parameters_editor = %ParticleEmitterParametersEditor as ParticleEmitterParametersEditor
		_info_label = %InfoLabel as InfoLabel
		_create_from_selection_button = %CreateFromSelectionButton as Button
		_create_from_small_molecules = %CreateFromSmallMoleculesButton as Button
		_create_from_selection_button.pressed.connect(_on_create_from_selection_button_pressed)
		_create_from_small_molecules.pressed.connect(_on_create_from_small_molecules_pressed)


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	var structure_context: StructureContext = in_workspace_context.get_current_structure_context()
	if !is_instance_valid(structure_context) || !is_instance_valid(structure_context.nano_structure):
		return false
	_ensure_initialized(in_workspace_context)
	
	var check_object_being_created: Callable = func(in_struct: NanoStructure) -> bool:
		return in_struct is NanoParticleEmitter
	
	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_PARTICLE_EMITTERS:
		if in_workspace_context.is_creating_object() and \
				in_workspace_context.peek_object_being_created(check_object_being_created):
			in_workspace_context.abort_creating_object()
		return false
	
	if in_workspace_context.is_creating_object() and \
			not in_workspace_context.peek_object_being_created(check_object_being_created):
		# Another object is being created
		in_workspace_context.abort_creating_object()
	
	if not in_workspace_context.is_creating_object():
		in_workspace_context.start_creating_object(NanoParticleEmitter.new())
	
	return true


func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		var emitter_parameters: NanoParticleEmitterParameters = \
			in_workspace_context.create_object_parameters.get_new_particle_emitter_parameters()
		_particle_emitter_parameters_editor.track_parameters(emitter_parameters)
		in_workspace_context.history_changed.connect(_on_workspace_context_history_changed)
		_on_workspace_context_history_changed()


func _get_small_molecules_picker() -> SmallMoleculesPicker:
	if _small_molecules_picker == null:
		# lazy loading on demand
		var scene: PackedScene = load("uid://dp606sfgxdepk") as PackedScene
		_small_molecules_picker = scene.instantiate()
		_small_molecules_picker.set_meta(&"base_height", _small_molecules_picker.size.y)
		_small_molecules_picker.molecule_selected.connect(_on_small_molecules_picker_molecule_selected)
		add_child(_small_molecules_picker)
	return _small_molecules_picker


func _on_workspace_context_history_changed() -> void:
	if WorkspaceUtils.can_create_particle_emitter_from_selection(_workspace_context):
		_info_label.highlighted = false
		_create_from_selection_button.disabled = false
	else:
		_info_label.highlighted = true
		_create_from_selection_button.disabled = true


func _on_create_from_selection_button_pressed() -> void:
	assert(WorkspaceUtils.can_create_particle_emitter_from_selection(_workspace_context))
	var base_parameters := _workspace_context.create_object_parameters.get_new_particle_emitter_parameters()
	# 1. Create emitter parameters from settings
	var instance_parameters: NanoParticleEmitterParameters = base_parameters.duplicate(true)
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	var selected_contexts: Array[StructureContext] = workspace_context.get_atomic_structure_contexts_with_selection()
	# 2. Create molecule template from selection and remove selection
	var template := AtomicStructure.create()
	template.start_edit()
	var context: StructureContext = selected_contexts[0] as StructureContext
	var center_of_selection: Vector3 = context.get_selection_aabb().get_center()
	var structure: AtomicStructure = context.nano_structure as AtomicStructure
	var atoms: PackedInt32Array = context.get_selected_atoms()
	var bonds: PackedInt32Array = context.get_selected_bonds()
	# NOTE: start editing source structure to remove atoms and bonds
	structure.start_edit()
	var atom_map: Dictionary[int,int] # { original_id = new_id }
	for atom_id: int in atoms:
		var element: int = structure.atom_get_atomic_number(atom_id)
		var pos: Vector3 = structure.atom_get_position(atom_id)
		# Asiming template is NanoMolecualStructure
		atom_map[atom_id] = template.add_atom(NanoMolecularStructure.AddAtomParameters.new(element, pos))
	for bond_id: int in bonds:
		var bond_data: Vector3i = structure.get_bond(bond_id)
		var atom1: int = bond_data.x
		var atom2: int = bond_data.y
		if atom1 in atoms and atom2 in atoms:
			var order: int = bond_data.z
			template.add_bond(atom_map[atom1], atom_map[atom2], order)
		structure.remove_bond(bond_id)
	structure.remove_atoms(atoms)
	structure.end_edit()
	_center_template_on_origin(template)
	template.end_edit()
	template.set_structure_name("Template")
	template.set_representation_settings(workspace_context.workspace.representation_settings)
	instance_parameters.set_molecule_template(template)
	# 3. Create Particle Emitter with configured parameters
	var emitter := NanoParticleEmitter.new()
	emitter.set_structure_name("%s %d" % [str(emitter.get_type()), _workspace_context.workspace.get_nmb_of_structures()+1])
	_workspace_context.start_creating_object(emitter)
	emitter.set_parameters(instance_parameters)
	emitter.set_position(center_of_selection)
	var new_context: StructureContext = _workspace_context.finish_creating_object()
	new_context.set_particle_emitter_selected(true)
	_workspace_context.snapshot_moment("Create Particle Emitter")


func _on_create_from_small_molecules_pressed() -> void:
	_small_molecules_picker.size.y = _small_molecules_picker.get_meta(&"base_height", 450)
	_small_molecules_picker.position.x = int(_create_from_small_molecules.global_position.x)
	_small_molecules_picker.position.y = int(_create_from_small_molecules.get_global_rect().end.y)

	# Adjust x position
	var picker_rect_end: Vector2 = _small_molecules_picker.position + _small_molecules_picker.size
	var out_of_screen_x: bool = picker_rect_end.x > get_tree().root.size.x
	if out_of_screen_x:
		_small_molecules_picker.position.x = \
			int(_create_from_small_molecules.get_global_rect().end.x- _small_molecules_picker.size.x)

	# Adjust y position (and size?)
	var up_space := int(_create_from_small_molecules.global_position.y)
	var down_space := int(get_tree().root.size.y - _create_from_small_molecules.get_global_rect().end.y)
	if down_space >= _small_molecules_picker.size.y:
		_put_small_molecules_picker_bellow()
	elif up_space >= _small_molecules_picker.size.y:
		_put_small_molecules_picker_avobe()
	elif up_space > down_space:
		_small_molecules_picker.size.y = up_space
		_put_small_molecules_picker_avobe()
	else:
		_small_molecules_picker.size.y = down_space
		_put_small_molecules_picker_bellow()

	_small_molecules_picker.popup()


func _on_small_molecules_picker_molecule_selected(in_path: String) -> void:
	assert(is_instance_valid(_workspace_context))
	var unpacked_mol_path: String = WorkspaceUtils.unpack_mol_file_and_get_path(in_path)
	var absolute_path: String = ProjectSettings.globalize_path(unpacked_mol_path)
	var template: NanoStructure = await WorkspaceUtils.get_nano_structure_from_file(_workspace_context, absolute_path, false, false, false)
	assert(template)
	template.set_structure_name(in_path.get_file().get_basename())
	template.set_representation_settings(_workspace_context.workspace.representation_settings)
	template.start_edit()
	_center_template_on_origin(template)
	template.end_edit()
	var base_parameters := _workspace_context.create_object_parameters.get_new_particle_emitter_parameters()
	var instance_parameters: NanoParticleEmitterParameters = base_parameters.duplicate(true)
	var emitter := NanoParticleEmitter.new()
	emitter.set_structure_name("%s %d" % [str(emitter.get_type()), _workspace_context.workspace.get_nmb_of_structures()+1])
	_workspace_context.start_creating_object(emitter)
	emitter.set_parameters(instance_parameters)
	instance_parameters.set_molecule_template(template)
	var emitter_pos: Vector3 = InputHandlerCreateObjectBase.calculate_preview_position(_workspace_context)
	emitter.set_position(emitter_pos)
	var new_context: StructureContext = _workspace_context.finish_creating_object()
	new_context.set_particle_emitter_selected(true)
	_workspace_context.snapshot_moment("Create Particle Emitter")


func _center_template_on_origin(out_template: AtomicStructure) -> void:
	var center: Vector3 = out_template.get_aabb().get_center()
	if center.is_equal_approx(Vector3.ZERO):
		return
	var atoms: PackedInt32Array = out_template.get_valid_atoms()
	var positions: PackedVector3Array = []
	for atom_id: int in atoms:
		var new_pos: Vector3 = out_template.atom_get_position(atom_id) - center
		positions.push_back(new_pos)
	out_template.atoms_set_positions(atoms, positions)


func _put_small_molecules_picker_avobe() -> void:
	_small_molecules_picker.position.y = \
		int(_create_from_small_molecules.global_position.y - _small_molecules_picker.size.y)


func _put_small_molecules_picker_bellow() -> void:
	_small_molecules_picker.position.y = \
		int(_create_from_small_molecules.get_global_rect().end.y)

