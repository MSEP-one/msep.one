class_name ModeSelector
extends Control


@onready var _create_mode_button: Button = %CreateModeButton
@onready var _select_mode_button: Button = %SelectModeButton


func _ready() -> void:
	_create_mode_button.toggled.connect(_on_create_mode_button_toggled)
	_select_mode_button.toggled.connect(_on_select_mode_button_toggled)


func initialize(in_workspace_context: WorkspaceContext) -> void:
	if in_workspace_context == null:
		return
	var create_object_parameters: CreateObjectParameters = in_workspace_context.create_object_parameters as CreateObjectParameters
	assert(create_object_parameters != null, "Workspace Context should always have CreateObjectParameters component")
	_set_create_mode_enabled(create_object_parameters.get_create_mode_enabled())
	if !create_object_parameters.create_mode_enabled_changed.is_connected(_set_create_mode_enabled):
		create_object_parameters.create_mode_enabled_changed.connect(_set_create_mode_enabled)


func _set_create_mode_enabled(in_enabled: bool) -> void:
	if not is_instance_valid(_create_mode_button) or not is_instance_valid(_select_mode_button):
		await ready
	_create_mode_button.set_pressed_no_signal(in_enabled)
	_select_mode_button.set_pressed_no_signal(not in_enabled)


func _on_create_mode_button_toggled(enabled: bool) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	workspace_context.create_object_parameters.set_create_mode_enabled(enabled)


func _on_select_mode_button_toggled(enabled: bool) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	workspace_context.create_object_parameters.set_create_mode_enabled(not enabled)
