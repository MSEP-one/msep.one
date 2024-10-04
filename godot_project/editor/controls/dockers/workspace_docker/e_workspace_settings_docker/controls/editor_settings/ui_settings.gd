extends DynamicContextControl


@onready var _widget_scale_spinbox: SpinBox = %WidgetScaleSpinbox


func _ready() -> void:
	_widget_scale_spinbox.value_changed.connect(_on_widget_scale_spinbox_value_changed)


func should_show(_in_workspace_context: WorkspaceContext)-> bool:
	_widget_scale_spinbox.set_value_no_signal( \
		MolecularEditorContext.msep_editor_settings.ui_widget_scale)
	var panel_enabled: bool = FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_ALLOW_SCALE_WIDGETS)
	return panel_enabled


func _on_widget_scale_spinbox_value_changed(in_new_value: float) -> void:
	MolecularEditorContext.msep_editor_settings.ui_widget_scale = in_new_value
