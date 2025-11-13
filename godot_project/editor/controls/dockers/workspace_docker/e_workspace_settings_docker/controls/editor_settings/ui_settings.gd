extends DynamicContextControl

@onready var _widget_scale_label: Label = %WidgetScaleLabel
@onready var _widget_scale_spinbox: SpinBox = %WidgetScaleSpinbox
@onready var _selection_option_button: OptionButton = %SelectionOptionButton


func _ready() -> void:
	_widget_scale_spinbox.value_changed.connect(_on_widget_scale_spinbox_value_changed)
	_selection_option_button.item_selected.connect(_on_selection_option_button_item_selected)


func should_show(_in_workspace_context: WorkspaceContext)-> bool:
	_widget_scale_spinbox.set_value_no_signal(
		MolecularEditorContext.msep_editor_settings.ui_widget_scale)
	_selection_option_button.set_block_signals(true)
	_selection_option_button.select(
		MolecularEditorContext.msep_editor_settings.selection_tab_policy)
	_selection_option_button.set_block_signals(false)
	
	var scale_widget_enabled: bool = FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_ALLOW_SCALE_WIDGETS)
	_widget_scale_label.visible = scale_widget_enabled
	_widget_scale_spinbox.visible = scale_widget_enabled
	return true


func _on_widget_scale_spinbox_value_changed(in_new_value: float) -> void:
	MolecularEditorContext.msep_editor_settings.ui_widget_scale = in_new_value


func _on_selection_option_button_item_selected(in_new_policy: int) -> void:
	MolecularEditorContext.msep_editor_settings.selection_tab_policy = \
		in_new_policy as MSEPSettings.SelectionTabPolicy

