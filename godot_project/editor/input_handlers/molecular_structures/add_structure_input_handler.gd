extends InputHandlerCreateObjectBase


var _rendering: Rendering
var _preview_size: Vector3
var _press_down_position: Vector2 = Vector2(-100, -100)

func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	in_context.current_structure_context_changed.connect(_on_current_structure_context_changed)
	in_context.create_object_parameters.new_structure_changed.connect(_on_new_structure_changed)
	in_context.create_object_parameters.create_distance_method_changed.connect(_on_creation_distance_changed)
	in_context.create_object_parameters.creation_distance_from_camera_factor_changed.connect(_on_creation_distance_changed)
	_rendering = in_context.get_rendering()


# region virtual

## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return false


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(in_structure_context: StructureContext) -> bool:
	var parameters: CreateObjectParameters = in_structure_context.workspace_context.create_object_parameters
	if parameters.get_create_mode_type() != CreateObjectParameters.CreateModeType.CREATE_FRAGMENT \
			or not parameters.get_create_mode_enabled():
		return false
	
	var new_structure: NanoStructure = parameters.get_new_structure()
	return new_structure != null and new_structure is AtomicStructure


## VIRTUAL
## Adds the current fragment to the workspace on left click.
func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, in_structure_context: StructureContext) -> bool:
	if in_input_event is InputEventWithModifiers:
		update_preview_position()
		var fragment_transform: Transform3D = _rendering.structure_preview_get_transform()
		if fragment_transform == null:
			return false # Ray normal is parallel to the PLANE_XY
		if input_has_modifiers(in_input_event):
			_rendering.structure_preview_hide()
			return false
		_rendering.structure_preview_show()
	
	if not in_input_event is InputEventMouseButton:
		return false
		
	if in_input_event.button_index == MOUSE_BUTTON_LEFT and in_input_event.is_released():
		if _press_down_position.distance_squared_to(in_input_event.global_position) > MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED:
			return false
		var create_object_parameters: CreateObjectParameters = in_structure_context.workspace_context.create_object_parameters
		if create_object_parameters.get_create_small_molecule_in_subgroup():
			_create_new_structure(in_structure_context.workspace_context)
		else:
			_merge_structure(in_structure_context)
		return true
	elif in_input_event.button_index == MOUSE_BUTTON_LEFT and in_input_event.is_pressed():
			_press_down_position = in_input_event.global_position
	return false


func set_preview_position(in_position: Vector3) -> void:
	var basis: Basis = Basis()
	var center_offset: Vector3 = basis * (_preview_size / 2.0)
	_rendering.structure_preview_set_transform(Transform3D(basis, in_position - center_offset))


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.ADD_STRUCTURE_INPUT_HANDLER_PRIORITY


# region public api

func get_workspace_context() -> WorkspaceContext:
	return _workspace_context


## When returns true no other InputHandlerBase will receive any inputs until this function returns false again,
## which usually will not happen until user is done with current input sequence (eg. drawing drag and drop selection)
func is_exclusive_input_consumer() -> bool:
	return false


## Can be used to react to the fact other InputHandlerBase has started to exclusively consuming inputs
## Usually used to clean up internal state and prepare for fresh input sequence
func handle_inputs_end() -> void:
	_hide_preview()


## This method is used to inform an exclusive input consumer ended consuming inputs
## This gives a chance to react to this fact and do some special initialization
func handle_inputs_resume() -> void:
	var parameters: CreateObjectParameters = get_workspace_context().create_object_parameters
	if parameters.get_create_mode_type() != CreateObjectParameters.CreateModeType.CREATE_FRAGMENT \
			or not parameters.get_create_mode_enabled():
		return
	update_preview_position()
	_rendering.structure_preview_show()


## Can be overwritten to react to the fact that there was an input event which never has been
## delivered to this input handler.
## Similar to handle_inputs_end() but will happen even if handler serving the event is not an
## exclusive consumer.
func handle_input_omission() -> void:
	_hide_preview()


# region internal

# Duplicate and place the fragment structure in a new group under the current active group
func _create_new_structure(in_workspace_context: WorkspaceContext) -> void:
	var reference_structure: NanoStructure = in_workspace_context.create_object_parameters.get_new_structure()
	var new_structure: NanoStructure = AtomicStructure.create()
	var placement_xform: Transform3D = _rendering.structure_preview_get_transform()
	new_structure.set_structure_name(reference_structure.get_structure_name())
	
	# Copy atoms and bonds from the preview to the new group / structure
	new_structure.start_edit()
	for atom_id: int in reference_structure.get_valid_atoms_count():
		var atomic_number: int = reference_structure.atom_get_atomic_number(atom_id)
		var position: Vector3 = placement_xform * reference_structure.atom_get_position(atom_id)
		var add_parameters := NanoMolecularStructure.AddAtomParameters.new(atomic_number, position)
		new_structure.add_atom(add_parameters)
	for bond_id: int in reference_structure.get_valid_bonds_count():
		var bond: Vector3i = reference_structure.get_bond(bond_id)
		new_structure.add_bond(bond[0], bond[1], bond[2])
	new_structure.end_edit()

	# Deselect other contexts
	var other_contexts: Array[StructureContext] = in_workspace_context.get_structure_contexts_with_selection()
	for context: StructureContext in other_contexts:
		context.clear_selection()
	
	# Add new structure and selects it
	var current_structure: NanoStructure = in_workspace_context.get_current_structure_context().nano_structure
	in_workspace_context.workspace.add_structure(new_structure, current_structure)
	var new_structure_context: StructureContext = in_workspace_context.get_nano_structure_context(new_structure)
	new_structure_context.select_all()
	
	_workspace_context.snapshot_moment("Add Small Molecule")


# Merge the fragment structure with the existing workspace nanostructure
func _merge_structure(in_structure_context: StructureContext) -> void:
	var target_structure_context: StructureContext = in_structure_context.workspace_context.get_current_structure_context()
	var target_structure: AtomicStructure = target_structure_context.nano_structure
	var can_merge: bool = is_instance_valid(target_structure) and not target_structure.is_virtual_object()
	if not can_merge:
		_create_new_structure(in_structure_context.workspace_context)
		return
	
	var workspace: Workspace = in_structure_context.workspace_context.workspace
	var placement_xform: Transform3D = _rendering.structure_preview_get_transform()
	var new_structure: AtomicStructure = in_structure_context.workspace_context.create_object_parameters.get_new_structure()
	var merge_result: AtomicStructure.MergeStructureResult = target_structure.merge_structure(
			new_structure, placement_xform, workspace)
	var new_atoms: PackedInt32Array = merge_result.new_atoms
	var new_bonds: PackedInt32Array = merge_result.new_bonds
	
	# Select newly added atoms and bonds
	target_structure_context.set_atom_selection(new_atoms)
	target_structure_context.clear_bond_selection()
	target_structure_context.set_bond_selection(new_bonds)
	
	# Clear selection in the other contexts
	var workspace_context: WorkspaceContext = get_workspace_context()
	var other_contexts: Array[StructureContext] = workspace_context.get_visible_structure_contexts(true)
	for context in other_contexts:
		if context == target_structure_context:
			continue
		context.clear_selection()
	
	_workspace_context.snapshot_moment("Add Small Molecule")
	EditorSfx.create_object()


func _hide_preview() -> void:
	_rendering.structure_preview_hide()


func _on_current_structure_context_changed(in_context: StructureContext) -> void:
	if in_context == null or in_context.nano_structure == null:
		_hide_preview()


func _on_creation_distance_changed(_arg: Variant) -> void:
	update_preview_position()


func _on_new_structure_changed(in_structure: NanoStructure) -> void:
	get_workspace_context().start_creating_object(in_structure)
	_preview_size = in_structure.get_aabb().size
