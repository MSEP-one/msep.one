extends RingMenuAction


const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")
const ExtendedElementPickerScn = preload("uid://cjqhv1ucctc0p")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null
var _extended_element_picker: ExtendedElementPicker = null:
	get = _get_extended_element_picker

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr(&"View Periodic Table"),
		_execute_action,
		tr(&"Show the full periodic table of elements to select.")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("uid://hguqdoyt23cu"))


func _get_extended_element_picker() -> ExtendedElementPicker:
	if not is_instance_valid(_extended_element_picker):
		_extended_element_picker = ExtendedElementPickerScn.instantiate()
		_workspace_context.add_child(_extended_element_picker)
		_extended_element_picker.atom_type_change_requested.connect(_on_extended_element_picker_atom_type_change_requested)
	return _extended_element_picker


func _execute_action() -> void:
	_extended_element_picker.popup_centered()
	_ring_menu.close()


func _on_extended_element_picker_atom_type_change_requested(in_element: int) -> void:
	_extended_element_picker.hide()
	_workspace_context.create_object_parameters.set_new_atom_element(in_element)
	_workspace_context.create_object_parameters.set_create_mode_type(
			CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS)
