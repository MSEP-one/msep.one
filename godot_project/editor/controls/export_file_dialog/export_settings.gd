extends VBoxContainer

var _check_export_dna: CheckBox
var _check_export_nanotube: CheckBox


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_check_export_dna = %CheckExportDNA as CheckBox
		_check_export_nanotube = %CheckExportNanotube as CheckBox


func should_show() -> bool:
	_should_show_checkbox(_check_export_dna, &"", _does_current_workspace_has_dna)
	_should_show_checkbox(_check_export_nanotube, &"", _does_current_workspace_has_nanotube)
	return _check_export_dna.visible or _check_export_nanotube.visible


func set_export_dna_enabled(in_enabled: bool) -> void:
	_check_export_dna.button_pressed = in_enabled


func is_export_dna_enabled() -> bool:
	return _check_export_dna.visible and _check_export_dna.button_pressed


func set_export_nanotube_enabled(in_enabled: bool) -> void:
	_check_export_nanotube.button_pressed = in_enabled


func is_export_nanotube_enabled() -> bool:
	return _check_export_nanotube.visible and _check_export_nanotube.button_pressed


func _should_show_checkbox(checkbox: CheckBox, feature_flag := StringName(), extra_condition_callback := Callable()) -> bool:
	var extra_condition: bool = true if extra_condition_callback.is_null() else extra_condition_callback.call()
	var has_feature: bool = true if feature_flag.is_empty() else FeatureFlagManager.get_flag_value(feature_flag)
	checkbox.visible = has_feature and extra_condition
	return checkbox.visible


func _does_current_workspace_has_dna() -> bool:
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	if workspace == null: return false
	for structure: NanoStructure in workspace.get_structures():
		if structure is DnaStructure and structure.get_sequence_length() > 0:
			return true
	return false

func _does_current_workspace_has_nanotube() -> bool:
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	if workspace == null: return false
	for structure: NanoStructure in workspace.get_structures():
		if structure is CarbonNanotubeStructure:
			return true
	return false
