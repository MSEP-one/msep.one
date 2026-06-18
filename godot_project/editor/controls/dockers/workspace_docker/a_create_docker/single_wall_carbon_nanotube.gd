extends DynamicContextControl


var _n_spin_box_slider: SpinBoxSlider
var _m_spin_box_slider: SpinBoxSlider
var _graphene_latice_preview: GrapheneLatticePreview
var _diameter_label: Label
var _circunference_label: Label


var _workspace_context: WorkspaceContext


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_initialized(in_workspace_context)
	return in_workspace_context.create_object_parameters.get_create_mode_type() == \
		CreateObjectParameters.CreateModeType.CREATE_CARBON_NANOTUBE


func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		_graphene_latice_preview.n = _workspace_context.create_object_parameters.get_nanotube_n_index()
		_graphene_latice_preview.m = _workspace_context.create_object_parameters.get_nanotube_m_index()
		_n_spin_box_slider.value = _graphene_latice_preview.n
		_m_spin_box_slider.value = _graphene_latice_preview.m
		_update_estimates()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_n_spin_box_slider = %NSpinBoxSlider as SpinBoxSlider
		_m_spin_box_slider = %MSpinBoxSlider as SpinBoxSlider
		_graphene_latice_preview = %GrapheneLaticePreview as GrapheneLatticePreview
		_diameter_label = %DiameterLabel as Label
		_circunference_label = %CircunferenceLabel as Label
		
		_n_spin_box_slider.value_changed.connect(_on_n_spin_box_slider_value_changed)
		_m_spin_box_slider.value_changed.connect(_on_m_spin_box_slider_value_changed)


func _on_n_spin_box_slider_value_changed(in_value: int) -> void:
	_graphene_latice_preview.n = in_value
	_workspace_context.create_object_parameters.set_nanotube_n_index(in_value)
	_update_estimates()


func _on_m_spin_box_slider_value_changed(in_value: int) -> void:
	_graphene_latice_preview.m = in_value
	_workspace_context.create_object_parameters.set_nanotube_m_index(in_value)
	_update_estimates()


func _update_estimates() -> void:
	_circunference_label.text = tr(&"%.3f nm") % _graphene_latice_preview.get_estimated_circunference()
	_diameter_label.text = tr(&"%.3f nm") % _graphene_latice_preview.get_estimated_diameter()
