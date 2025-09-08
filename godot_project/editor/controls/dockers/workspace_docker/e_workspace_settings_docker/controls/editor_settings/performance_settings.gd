extends DynamicContextControl


@onready var max_undo_count_spinbox: SpinBoxSlider = %MaxUndoCountSpinbox
@onready var max_atom_candidates_spinbox: SpinBoxSlider = %MaxAtomCandidatesSpinbox


func _ready() -> void:
	max_undo_count_spinbox.value_confirmed.connect(_on_max_undo_count_spinbox_value_confirmed)
	max_atom_candidates_spinbox.value_confirmed.connect(_on_max_atom_candidates_spinbox_value_confirmed)


func should_show(_in_workspace_context: WorkspaceContext)-> bool:
	var max_undo_count: int = MolecularEditorContext.msep_editor_settings.editor_max_undo_count
	max_undo_count_spinbox.set_value_no_signal(max_undo_count)
	var max_candidates_count: int = MolecularEditorContext.msep_editor_settings.editor_max_atom_candidates
	max_atom_candidates_spinbox.set_value_no_signal(max_candidates_count)
	return true


func _on_max_undo_count_spinbox_value_confirmed(in_value: float) -> void:
	MolecularEditorContext.msep_editor_settings.editor_max_undo_count = int(in_value)


func _on_max_atom_candidates_spinbox_value_confirmed(in_value: float) -> void:
	MolecularEditorContext.msep_editor_settings.editor_max_atom_candidates = int(in_value)
