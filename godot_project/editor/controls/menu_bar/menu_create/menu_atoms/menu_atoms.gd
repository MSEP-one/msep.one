extends NanoPopupMenu

signal request_hide

@export var shortcut_add_hydrogens: Shortcut
@export var shortcut_lock_atoms: Shortcut
@export var shortcut_unlock_atoms: Shortcut

const Icons: Dictionary = {
	atom = preload("res://editor/controls/menu_bar/menu_create/menu_atoms/icons/icon_Atom_16px.svg"),
	auto_bonder = preload("res://editor/controls/menu_bar/menu_create/menu_atoms/icons/icon_AutoBonder_16px.svg"),
	add_hydrogens = preload("res://editor/controls/menu_bar/menu_create/menu_atoms/icons/icon_AddHydrogens_16px.svg"),
	lock_selected_atoms = preload("res://editor/controls/menu_bar/menu_create/menu_atoms/icons/icon_LockAtoms_16px.svg"),
}
const ID_AUTO_BONDER = 200
const ID_ADD_HYDROGENS = 201
const ID_LOCK_UNLOCK_SELECTED_ATOMS = 202
const FEATURE_FLAG_AUTOBONDER_ACTION_ENABLED: StringName = &"feature_flags/autobonder_action_enabled"

var _autobonder_action_enabled: bool = true


func _ready() -> void:
	super()
	_autobonder_action_enabled = \
		ProjectSettings.get_setting(FEATURE_FLAG_AUTOBONDER_ACTION_ENABLED, true)
	
	for element: int in PeriodicTable.NON_METALS:
		var data: ElementData = PeriodicTable.get_by_atomic_number(element) as ElementData
		add_icon_item(Icons.atom,tr(data.name), data.number)
	add_separator("", 0)
	if _autobonder_action_enabled:
		add_icon_item(Icons.auto_bonder, tr("Auto-Create Bonds"), ID_AUTO_BONDER)
	add_icon_item(Icons.add_hydrogens, tr("Correct Hydrogens"), ID_ADD_HYDROGENS)
	set_item_shortcut(get_item_index(ID_ADD_HYDROGENS), shortcut_add_hydrogens, true)
	add_icon_item(Icons.lock_selected_atoms, tr("Lock/Unlock Selected Atoms"), ID_LOCK_UNLOCK_SELECTED_ATOMS)
	set_item_shortcut(get_item_index(ID_LOCK_UNLOCK_SELECTED_ATOMS), shortcut_lock_atoms, true)


func _update_menu() -> void:
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	if !is_instance_valid(workspace):
		_update_for_context(null)
		return
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(workspace)
	_update_for_context(workspace_context)


func _update_for_context(in_context: WorkspaceContext) -> void:
	var has_context: bool = is_instance_valid(in_context)
	for element: int in PeriodicTable.NON_METALS:
		set_item_disabled(get_item_index(element), !has_context)
	if has_context and not in_context.are_hydrogens_visualized():
		set_item_disabled(get_item_index(PeriodicTable.ATOMIC_NUMBER_HYDROGEN), true)
	if !has_context:
		if _autobonder_action_enabled:
			set_item_disabled(get_item_index(ID_AUTO_BONDER), true)
		set_item_disabled(get_item_index(ID_ADD_HYDROGENS), true)
		set_item_disabled(get_item_index(ID_LOCK_UNLOCK_SELECTED_ATOMS), true)
		return
	
	# Validate Auto Bonder
	var selected_structures_contexts: Array[StructureContext] = \
			in_context.get_structure_contexts_with_selection()
	for context in selected_structures_contexts:
		if context.get_selected_atoms().size() > 1:
			if _autobonder_action_enabled:
				set_item_disabled(get_item_index(ID_AUTO_BONDER), false)
			set_item_disabled(get_item_index(ID_ADD_HYDROGENS), false)
			return
	if _autobonder_action_enabled:
		set_item_disabled(get_item_index(ID_AUTO_BONDER), true)

	# Validate Add Hydrogens
	for context in in_context.get_visible_structure_contexts():
		if context.nano_structure is AtomicStructure and context.nano_structure.get_valid_atoms_count() > 0:
			set_item_disabled(get_item_index(ID_ADD_HYDROGENS), false)
			return
	set_item_disabled(get_item_index(ID_ADD_HYDROGENS), true)
	
	# Validate Lock/Unlock atoms
	var has_selection: bool = in_context.is_any_atom_selected()
	set_item_disabled(get_item_index(ID_LOCK_UNLOCK_SELECTED_ATOMS), not has_selection)


func _on_id_pressed(in_id: int) -> void:
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(workspace)
	if in_id in PeriodicTable.NON_METALS:
		request_hide.emit()
		_start_creating_atom(workspace_context, in_id)
	elif in_id == ID_AUTO_BONDER:
		request_hide.emit()
		_auto_create_bonds(workspace_context)
	elif in_id == ID_ADD_HYDROGENS:
		request_hide.emit()
		_add_hydrogens(workspace_context)
	elif in_id == ID_LOCK_UNLOCK_SELECTED_ATOMS:
		request_hide.emit()
		MolecularEditorContext.request_workspace_docker_focus(DynamicContextDocker.UNIQUE_DOCKER_NAME, &"Lock/Unlock Atoms")


func _start_creating_atom(in_workspace_context: WorkspaceContext, in_element_number: int) -> void:
	in_workspace_context.create_object_parameters.set_new_atom_element(in_element_number)
	in_workspace_context.create_object_parameters.set_create_mode_type(CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS)
	MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)


func _auto_create_bonds(in_workspace_context: WorkspaceContext) -> void:
	in_workspace_context.action_auto_bonder.execute()


func _add_hydrogens(in_workspace_context: WorkspaceContext) -> void:
	in_workspace_context.action_add_hydrogens.execute()
