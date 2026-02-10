extends VBoxContainer

var _check_export_dna: CheckBox


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_check_export_dna = %CheckExportDNA as CheckBox


func should_show() -> bool:
	var any_visible: bool = false
	any_visible = any_visible or _should_show_checkbox(
		_check_export_dna,
		FeatureFlagManager.FEATURE_FLAGS_DNA_BUILDER,
		_does_current_workspace_has_dna
	)
	return any_visible


func set_export_dna_enabled(in_enabled: bool) -> void:
	_check_export_dna.button_pressed = in_enabled


func is_export_dna_enabled() -> bool:
	return _check_export_dna.visible and _check_export_dna.button_pressed


func _should_show_checkbox(checkbox: CheckBox, feature_flag: StringName, extra_condition_callback := Callable()) -> bool:
	var extra_condition: bool = true if extra_condition_callback.is_null() else extra_condition_callback.call()
	checkbox.visible = FeatureFlagManager.get_flag_value(feature_flag) and extra_condition
	return checkbox.visible


func _does_current_workspace_has_dna() -> bool:
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	if workspace == null: return false
	for structure: NanoStructure in workspace.get_structures():
		if structure is DnaStructure and structure.get_sequence_length() > 0:
			return true
	return false

