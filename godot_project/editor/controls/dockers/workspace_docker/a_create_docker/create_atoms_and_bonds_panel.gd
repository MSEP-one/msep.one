extends DynamicContextControl


@onready var element_preview: Control = %ElementPreview
@onready var bond_picker: Container = %BondPicker
@onready var element_picker: Control = %ElementPicker


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	var structure_context: StructureContext = in_workspace_context.get_current_structure_context()
	if !is_instance_valid(structure_context) || !is_instance_valid(structure_context.nano_structure):
		return false
	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS:
		return false
	if !in_workspace_context.create_object_parameters.new_atom_element_changed.is_connected(_on_new_atom_element_changed):
		in_workspace_context.create_object_parameters.new_atom_element_changed.connect(_on_new_atom_element_changed)
		in_workspace_context.create_object_parameters.new_bond_order_changed.connect(_on_new_bond_order_changed)
		_on_new_atom_element_changed(in_workspace_context.create_object_parameters.get_new_atom_element())
		_on_new_bond_order_changed(in_workspace_context.create_object_parameters.get_new_bond_order())
	if not in_workspace_context.workspace.representation_settings.hydrogen_visibility_changed.is_connected(_on_hydrogen_visibility_changed):
		in_workspace_context.workspace.representation_settings.hydrogen_visibility_changed.connect(_on_hydrogen_visibility_changed)
	return structure_context.nano_structure is AtomicStructure


# region: Internal

func _ready() -> void:
	bond_picker.bond_order_change_requested.connect(_on_bond_order_change_requested)
	element_picker.atom_type_change_requested.connect(_on_atom_type_change_requested)


func _on_bond_order_change_requested(in_order: int) -> void:
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	if workspace == null:
		return
	var context: WorkspaceContext = MolecularEditorContext.get_workspace_context(workspace)
	context.create_object_parameters.set_new_bond_order(in_order)
	EditorSfx.mouse_down()


func _on_atom_type_change_requested(in_element: int) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	if workspace_context == null:
		return
	workspace_context.create_object_parameters.set_new_atom_element(in_element)
	EditorSfx.mouse_down()


func _on_new_atom_element_changed(in_element: int) -> void:
	element_preview.set_element_number(in_element)


func _on_new_bond_order_changed(in_order: int) -> void:
	bond_picker.set_bond_order(in_order)


func _on_hydrogen_visibility_changed(in_are_visible: bool) -> void:
	if not in_are_visible:
		element_picker.disable_element(PeriodicTable.ATOMIC_NUMBER_HYDROGEN)
	else:
		element_picker.enable_element(PeriodicTable.ATOMIC_NUMBER_HYDROGEN)

