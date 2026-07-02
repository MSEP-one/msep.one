extends DynamicContextControl


var _n_spin_box_slider: SpinBoxSlider
var _m_spin_box_slider: SpinBoxSlider
var _graphene_latice_preview: GrapheneLatticePreview
var _diameter_label: Label
var _circunference_label: Label


var _workspace_context: WorkspaceContext
var _edited_nanotube: CarbonNanotubeStructure


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	_ensure_initialized(in_workspace_context)
	var count: int = 0
	var select_ctx: StructureContext = null
	for ctx: StructureContext in in_workspace_context.get_structure_contexts_with_selection():
		if ctx.nano_structure is CarbonNanotubeStructure:
			count += 1
			select_ctx = ctx
	_set_selected_context(select_ctx.nano_structure if count == 1 else null)
	return count > 0


func _ensure_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_context == null:
		_workspace_context = in_workspace_context


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_n_spin_box_slider = %NSpinBoxSlider as SpinBoxSlider
		_m_spin_box_slider = %MSpinBoxSlider as SpinBoxSlider
		_graphene_latice_preview = %GrapheneLaticePreview as GrapheneLatticePreview
		_diameter_label = %DiameterLabel as Label
		_circunference_label = %CircunferenceLabel as Label
		
		_n_spin_box_slider.value_changed.connect(_on_n_spin_box_slider_value_changed)
		_m_spin_box_slider.value_changed.connect(_on_m_spin_box_slider_value_changed)
		_n_spin_box_slider.value_confirmed.connect(_on_n_spin_box_slider_value_confirmed)
		_m_spin_box_slider.value_confirmed.connect(_on_m_spin_box_slider_value_confirmed)


func _set_selected_context(out_nanotube_or_null: CarbonNanotubeStructure) -> void:
	%SelectOneInfoLabel.visible = out_nanotube_or_null == null
	%EditorContainer.visible = not out_nanotube_or_null == null
	_edited_nanotube = out_nanotube_or_null
	if _edited_nanotube != null:
		_graphene_latice_preview.n = _edited_nanotube.get_chiral_index_n()
		_graphene_latice_preview.m = _edited_nanotube.get_chiral_index_m()
		_n_spin_box_slider.set_value_no_signal(_graphene_latice_preview.n)
		_m_spin_box_slider.set_value_no_signal(_graphene_latice_preview.m)
		_update_estimates()


func _on_n_spin_box_slider_value_changed(in_value: int) -> void:
	_graphene_latice_preview.n = in_value
	_update_estimates()


func _on_m_spin_box_slider_value_changed(in_value: int) -> void:
	_graphene_latice_preview.m = in_value
	_update_estimates()
	

func _on_n_spin_box_slider_value_confirmed(in_value: int) -> void:
	if _edited_nanotube:
		_edited_nanotube.start_edit()
		_edited_nanotube.set_chiral_index_n(in_value)
		_edited_nanotube.end_edit()
		_workspace_context.snapshot_moment("Set: Nanotube Chiral Index")


func _on_m_spin_box_slider_value_confirmed(in_value: int) -> void:
	if _edited_nanotube:
		_edited_nanotube.start_edit()
		_edited_nanotube.set_chiral_index_m(in_value)
		_edited_nanotube.end_edit()
		_workspace_context.snapshot_moment("Set: Nanotube Chiral Index")


func _update_estimates() -> void:
	_circunference_label.text = tr(&"%.3f nm") % _graphene_latice_preview.get_estimated_circunference()
	_diameter_label.text = tr(&"%.3f nm") % _graphene_latice_preview.get_estimated_diameter()
