extends DynamicContextControl

@onready var editor_sfx_check_button: CheckButton = $PanelContainer/HBoxContainer/EditorSfxCheckButton
@onready var editor_sfx_volume_slider: HSlider = $PanelContainer/HBoxContainer/EditorSfxVolumeSlider


func _ready() -> void:
	editor_sfx_check_button.button_pressed = \
		MolecularEditorContext.msep_editor_settings.editor_sfx_enabled
	editor_sfx_volume_slider.value = \
		MolecularEditorContext.msep_editor_settings.editor_sfx_volume
	
	editor_sfx_check_button.toggled.connect(_on_editor_sfx_toggled)
	editor_sfx_volume_slider.value_changed.connect(_on_editor_sfx_volume_changed)


func should_show(_in_workspace_context: WorkspaceContext)-> bool:
	editor_sfx_check_button.set_pressed_no_signal(
			MolecularEditorContext.msep_editor_settings.editor_sfx_enabled)
	editor_sfx_volume_slider.set_value_no_signal(
			MolecularEditorContext.msep_editor_settings.editor_sfx_volume)
	return true


func _on_editor_sfx_toggled(in_new_value: bool) -> void:
	MolecularEditorContext.msep_editor_settings.editor_sfx_enabled = in_new_value


func _on_editor_sfx_volume_changed(in_new_value: float) -> void:
	MolecularEditorContext.msep_editor_settings.editor_sfx_volume = in_new_value
	editor_sfx_check_button.button_pressed = in_new_value > MSEPSettings.MIN_SFX_VOLUME
