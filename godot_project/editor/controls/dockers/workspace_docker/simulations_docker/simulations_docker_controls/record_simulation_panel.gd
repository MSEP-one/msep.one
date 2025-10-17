extends DynamicContextControl


@onready var _info_label: InfoLabel
@onready var _save_video_button: Button


var _workspace_context: WorkspaceContext = null
var _is_simulation_processing: bool = false


func should_show(out_workspace_context: WorkspaceContext) -> bool:
	_ensure_workspace_initialized(out_workspace_context)
	var current_type: CreateObjectParameters.SimulationType = \
		out_workspace_context.create_object_parameters.get_simulation_type()
	if current_type == CreateObjectParameters.SimulationType.MOLECULAR_MECHANICS:
		_update_controls()
		return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_info_label = $InfoLabel as InfoLabel
		_save_video_button = $SaveVideoButton as Button
		_save_video_button.pressed.connect(_on_save_video_button_pressed)


func _ensure_workspace_initialized(out_workspace_context: WorkspaceContext) -> void:
	if _workspace_context != out_workspace_context:
		_workspace_context = out_workspace_context
		out_workspace_context.simulation_started.connect(_on_simulation_started)
		out_workspace_context.simulation_background_processing_completed.connect(_on_simulation_background_processing_completed)
		out_workspace_context.simulation_finished.connect(_on_simution_finished)


func _on_simulation_started() -> void:
	_is_simulation_processing = true
	_update_controls()


func _on_simulation_background_processing_completed() -> void:
	_is_simulation_processing = false
	_update_controls()


func _on_simution_finished() -> void:
	_update_controls()


func _update_controls() -> void:
	if not _workspace_context.is_simulating() or _is_simulation_processing:
		_save_video_button.disabled = true
		_info_label.highlighted = true
	else:
		_save_video_button.disabled = false
		_info_label.highlighted = false


func _on_save_video_button_pressed() -> void:
	WorkspaceUtils.open_record_simulation_video_dialog(_workspace_context)
