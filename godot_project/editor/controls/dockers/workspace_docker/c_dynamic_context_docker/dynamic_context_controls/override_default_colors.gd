extends DynamicContextControl


var _workspace_context: WorkspaceContext

@onready var _button_select_color: Button = %ButtonSelectColor
@onready var _button_restore_colors: Button = %ButtonRestoreColors
@onready var _confirmation_color_popup: ConfirmationColorPopup = %ConfirmationColorPopup


func _ready() -> void:
	_button_select_color.pressed.connect(_on_button_select_color_pressed)
	_button_restore_colors.pressed.connect(_on_button_restore_colors_pressed)
	_confirmation_color_popup.color_selected.connect(_on_color_selected)
	_confirmation_color_popup.default_pressed.connect(_on_default_color_selected)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_workspace_context = in_workspace_context
	return _workspace_context.is_any_atom_selected()


func _on_button_select_color_pressed() -> void:
	var popup_position: Vector2 = global_position
	popup_position.y -= _confirmation_color_popup.size.y + 8
	var popup_rect: Rect2 = Rect2(popup_position, Vector2.ZERO)
	_confirmation_color_popup.popup(popup_rect)


func _on_button_restore_colors_pressed() -> void:
	_on_default_color_selected()


func _on_color_selected(color: Color) -> void:
	_confirmation_color_popup.hide()
	if not _workspace_context.is_any_atom_selected():
		return
	for context: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		if not context.nano_structure is AtomicStructure:
			continue
		var nano_structure: AtomicStructure = context.nano_structure
		var selected_atoms: PackedInt32Array = context.get_selected_atoms()
		nano_structure.start_edit()
		nano_structure.set_color_override(selected_atoms, color)
		nano_structure.end_edit()
	_workspace_context.snapshot_moment("Set Color Override")


func _on_default_color_selected() -> void:
	_confirmation_color_popup.hide()
	if not _workspace_context.is_any_atom_selected():
		return
	for context: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		if not context.nano_structure is NanoMolecularStructure:
			continue
		var nano_structure: NanoMolecularStructure = context.nano_structure
		var selected_atoms: PackedInt32Array = context.get_selected_atoms()
		nano_structure.start_edit()
		nano_structure.remove_color_override(selected_atoms)
		nano_structure.end_edit()
	_workspace_context.snapshot_moment("Reset Color Override")
