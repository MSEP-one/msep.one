extends DynamicContextControl


@onready var max_undo_count_spinbox: SpinBox = %MaxUndoCountSpinbox


func _ready() -> void:
	max_undo_count_spinbox.value_changed.connect(_on_max_undo_count_spinbox_value_changed)


func should_show(_in_workspace_context: WorkspaceContext)-> bool:
	var max_undo_count: int = MolecularEditorContext.msep_editor_settings.editor_max_undo_count
	max_undo_count_spinbox.set_value_no_signal(max_undo_count)
	return true


func _on_max_undo_count_spinbox_value_changed(in_value: float) -> void:
	MolecularEditorContext.msep_editor_settings.editor_max_undo_count = int(in_value)
