extends DynamicContextControl

@onready var invert_camera_orbit_x_check_button : CheckButton = %InvertCameraOrbitXDirectionCheckButton
@onready var invert_camera_orbit_y_check_button : CheckButton = %InvertCameraOrbitYDirectionCheckButton
@onready var perspective_button: Button = %PerspectiveButton
@onready var orthographic_button: Button = %OrthographicButton


func _ready() -> void:
	invert_camera_orbit_x_check_button.button_pressed = \
		MolecularEditorContext.msep_editor_settings.editor_camera_camera_orbit_x_inverted
	invert_camera_orbit_y_check_button.button_pressed = \
		MolecularEditorContext.msep_editor_settings.editor_camera_camera_orbit_y_inverted
	orthographic_button.button_pressed = \
		MolecularEditorContext.msep_editor_settings.editor_camera_orthographic_projection_enabled
	perspective_button.button_pressed = not orthographic_button.button_pressed
	
	invert_camera_orbit_x_check_button.toggled.connect(_on_toggle_invert_orbit_x)
	invert_camera_orbit_y_check_button.toggled.connect(_on_toggle_invert_orbit_y)
	perspective_button.toggled.connect(_on_perspective_button_toggled)
	orthographic_button.toggled.connect(_on_orthographic_button_toggled)


func should_show(_in_workspace_context: WorkspaceContext)-> bool:
	invert_camera_orbit_x_check_button.set_pressed_no_signal( \
			MolecularEditorContext.msep_editor_settings.editor_camera_camera_orbit_x_inverted)
	invert_camera_orbit_y_check_button.set_pressed_no_signal( \
			MolecularEditorContext.msep_editor_settings.editor_camera_camera_orbit_y_inverted)
	return true


func _on_toggle_invert_orbit_x(in_new_value: bool) -> void:
	MolecularEditorContext.msep_editor_settings.editor_camera_camera_orbit_x_inverted = in_new_value


func _on_toggle_invert_orbit_y(in_new_value: bool) -> void:
	MolecularEditorContext.msep_editor_settings.editor_camera_camera_orbit_y_inverted = in_new_value


func _on_perspective_button_toggled(in_enabled: bool) -> void:
	if not in_enabled:
		return
	MolecularEditorContext.msep_editor_settings.editor_camera_orthographic_projection_enabled = false


func _on_orthographic_button_toggled(in_enabled: bool) -> void:
	if not in_enabled:
		return
	MolecularEditorContext.msep_editor_settings.editor_camera_orthographic_projection_enabled = true
