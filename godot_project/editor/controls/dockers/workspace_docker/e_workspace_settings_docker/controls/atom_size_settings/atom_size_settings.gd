extends DynamicContextControl


@onready var user_factor_radius_source: OptionButton = %UserFactorRadiusSource
@onready var user_factor_spin_box_slider: SpinBoxSlider = %UserFactorSpinBoxSlider


var _workspace_context: WorkspaceContext = null
var _loading: bool = false


func _ready() -> void:
	user_factor_spin_box_slider.value_confirmed.connect(_on_user_factor_spin_box_slider_value_confirmed)
	user_factor_radius_source.item_selected.connect(_on_user_factor_radius_source_item_selected)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		_workspace_context.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)
	load_settings(in_workspace_context.workspace.representation_settings)
	return true


func _on_user_factor_spin_box_slider_value_confirmed(_value: float) -> void:
	if !_loading:
		_update_settings(_workspace_context.workspace.representation_settings)
		_workspace_context.snapshot_moment("Set Representation Radius Factor")


func _on_user_factor_radius_source_item_selected(_index: int) -> void:
	if !_loading:
		_update_settings(_workspace_context.workspace.representation_settings)
		_workspace_context.snapshot_moment("Set Representation Radius Source")


func _on_workspace_context_history_snapshot_applied() -> void:
	load_settings(_workspace_context.workspace.representation_settings)


func load_settings(in_settings: RepresentationSettings) -> void:
	_loading = true
	user_factor_radius_source.selected = in_settings.get_balls_and_sticks_size_source()
	user_factor_spin_box_slider.value = in_settings.get_balls_and_sticks_size_factor()
	_loading = false


func _update_settings(out_settings: RepresentationSettings) -> void:
	out_settings.set_balls_and_sticks_size_source(user_factor_radius_source.selected as RepresentationSettings.UserAtomSizeSource)
	out_settings.set_balls_and_sticks_size_factor(user_factor_spin_box_slider.value)
	out_settings.emit_changed()
