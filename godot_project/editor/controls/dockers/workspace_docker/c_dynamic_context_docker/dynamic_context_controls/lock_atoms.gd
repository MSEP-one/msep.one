extends DynamicContextControl


var _workspace_context: WorkspaceContext

@onready var _selected_label: Label = %SelectedLabel
@onready var _unlock_button: Button = %UnlockButton
@onready var _lock_button: Button = %LockButton
@onready var _multiple_states_info_label: RichTextLabel = %MultipleStatesInfoLabel


func _ready() -> void:
	_lock_button.toggled.connect(_on_lock_button_toggled)
	_unlock_button.toggled.connect(_on_unlock_button_toggled)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_workspace_context = in_workspace_context
	if not _workspace_context.selection_in_structures_changed.is_connected(_on_workspace_context_selection_in_structures_changed):
		_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
	
	if _workspace_context.is_any_atom_selected():
		ScriptUtils.call_deferred_once(_refresh_ui)
		return true
	return false


func _refresh_ui() -> void:
	var selected_atom_count: int = 0
	for context: StructureContext in _workspace_context.get_structure_contexts_with_selection():
		selected_atom_count += context.get_selected_atoms().size()
	
	var message: StringName = &"{0} Atom selected"
	var plural_message: StringName = &"{0} Atoms selected"
	_selected_label.text = tr_n(message, plural_message, selected_atom_count).format([selected_atom_count])
	
	var all_locked: bool = _are_all_selected_atoms_locked()
	var none_locked: bool = not _is_any_selected_atom_locked()
	_lock_button.set_pressed_no_signal(all_locked)
	_unlock_button.set_pressed_no_signal(none_locked)
	_multiple_states_info_label.visible = not all_locked and not none_locked


func _are_all_selected_atoms_locked() -> bool:
	var selected_contexts: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
	for context: StructureContext in selected_contexts:
		if not context.nano_structure is AtomicStructure:
			continue
		var selected_atoms: PackedInt32Array = context.get_selected_atoms()
		var locked_atoms: PackedInt32Array = context.nano_structure.get_locked_atoms()
		for selected_atom: int in selected_atoms:
			if not selected_atom in locked_atoms:
				return false
	return true


func _is_any_selected_atom_locked() -> bool:
	var selected_contexts: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
	for context: StructureContext in selected_contexts:
		for atom_id: int in context.get_selected_atoms():
			if context.nano_structure.atom_is_locked(atom_id):
				return true
	return false


func _on_workspace_context_selection_in_structures_changed(_structure_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_refresh_ui)


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_refresh_ui)


func _on_lock_button_toggled(in_pressed: bool) -> void:
	if not in_pressed:
		return
	WorkspaceUtils.set_selected_atoms_locked(_workspace_context, true)
	_multiple_states_info_label.visible = false


func _on_unlock_button_toggled(in_pressed: bool) -> void:
	if not in_pressed:
		return
	WorkspaceUtils.set_selected_atoms_locked(_workspace_context, false)
	_multiple_states_info_label.visible = false
