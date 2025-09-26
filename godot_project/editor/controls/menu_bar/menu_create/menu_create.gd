extends NanoPopupMenu

signal request_hide

@onready var atoms: NanoPopupMenu = $Atoms
@onready var virtual_objects: NanoPopupMenu = $VirtualObjects

const ID_CREATE_SMALL_MOLECULES = 1

func _ready() -> void:
	super()
	add_submenu_item(tr("Atoms"), atoms.name)
	var small_molecules_icon: Texture2D = preload("res://editor/controls/menu_bar/menu_create/menu_atoms/icons/icon_AutoBonder_16px.svg")
	add_icon_item(small_molecules_icon, tr("Small Molecules"), ID_CREATE_SMALL_MOLECULES)
	add_submenu_item("Virtual Objects", virtual_objects.name)


func _update_menu() -> void:
	atoms._update_menu()
	virtual_objects._update_menu()
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	_update_for_context(workspace_context)


func _update_for_context(in_context: WorkspaceContext) -> void:
	var has_context: bool = is_instance_valid(in_context)
	set_item_disabled(get_item_index(ID_CREATE_SMALL_MOLECULES), !has_context)


func _on_id_pressed(in_id: int) -> void:
	if in_id == ID_CREATE_SMALL_MOLECULES:
		request_hide.emit()
		var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
		workspace_context.create_object_parameters.set_create_mode_type(CreateObjectParameters.CreateModeType.CREATE_FRAGMENT)
		MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
