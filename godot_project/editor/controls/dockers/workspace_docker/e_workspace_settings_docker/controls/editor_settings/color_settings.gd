extends DynamicContextControl

const _SETTING_CUSTOM_BACKGROUND_COLOR =  "custom_background_color"
const _SETTING_CUSTOM_BACKGROUND_COLOR_ENABLED = "custom_background_color_enabled"
const _SETTING_CUSTOM_SELECTION_OUTLINE_COLOR_ENABLED = "custom_selection_outline_color_enabled"
const _SETTING_CUSTOM_SELECTION_OUTLINE_COLOR = "custom_selection_outline_color"

@onready var _background_color_button: AdvancedColorPickerButton = %BackgroundColorButton
@onready var _selection_color_button: AdvancedColorPickerButton = %SelectionColorButton

var _workspace_context: WorkspaceContext = null


func _ready() -> void:
	_background_color_button.color_changed.connect(_on_background_color_changed)
	_background_color_button.color_reset.connect(_on_background_color_reset)
	_selection_color_button.color_changed.connect(_on_selection_color_changed)
	_selection_color_button.color_reset.connect(_on_selection_color_reset)


func should_show(out_workspace_context: WorkspaceContext) -> bool:
	if _workspace_context != out_workspace_context:
		_setup(out_workspace_context)
	return true


func _on_background_color_changed(in_color: Color) -> void:
	if not is_instance_valid(_workspace_context):
		print("Workspace is not valid")
		return
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	representation_settings.set_custom_background_color(in_color)
	representation_settings.set_custom_background_color_enabled(true)
	_workspace_context.snapshot_moment(tr("Change Background Color"))


func _on_background_color_reset() -> void:
	if not is_instance_valid(_workspace_context):
		print("Workspace is not valid")
		return
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	representation_settings.set_custom_background_color_enabled(false)
	_workspace_context.snapshot_moment(tr("Reset background color"))


func _on_selection_color_changed(in_color: Color) -> void:
	if not is_instance_valid(_workspace_context):
		print("Workspace is not valid")
		return
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	representation_settings.set_custom_selection_outline_color(in_color)
	representation_settings.set_custom_selection_outline_color_enabled(true)
	_workspace_context.snapshot_moment(tr("Change Custom Selection Outline Color"))


func _on_selection_color_reset() -> void:
	if not is_instance_valid(_workspace_context):
		print("Workspace is not valid")
		return
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	representation_settings.set_custom_selection_outline_color_enabled(false)
	_workspace_context.snapshot_moment(tr("Change Custom Selection Outline Color"))


func _setup(out_workspace_context: WorkspaceContext) -> void:
	if is_instance_valid(_workspace_context) and is_instance_valid(_workspace_context.workspace) \
			and is_instance_valid(_workspace_context.workspace.representation_settings) \
			and _workspace_context.workspace.representation_settings.changed.is_connected(_on_representation_settings_changed):
		_workspace_context.workspace.representation_settings.changed.disconnect(_on_representation_settings_changed)
		_workspace_context.history_snapshot_applied.disconnect(_on_workspace_context_history_snapshot_applied)
	_workspace_context = out_workspace_context
	_workspace_context.workspace.representation_settings.changed.connect(_on_representation_settings_changed)
	_workspace_context.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)
	_on_representation_settings_changed()


func _on_representation_settings_changed() -> void:
	_background_color_button.set_color(_workspace_context.workspace.representation_settings.get_custom_background_color())
	_selection_color_button.set_color(_workspace_context.workspace.representation_settings.get_custom_selection_outline_color())


func _on_workspace_context_history_snapshot_applied() -> void:
	_on_representation_settings_changed()
