extends Window

@export var color_pressed := Color.CORNFLOWER_BLUE
@export var color_released := Color.SEASHELL
@export var offset := Vector2i.ZERO

@onready var shift: Panel = %Shift
@onready var mouse_left_button: Panel = %MouseLeftButton
@onready var mouse_middle_button: Panel = %MouseMiddleButton
@onready var mouse_right_button: Panel = %MouseRightButton
@onready var ctrl: Panel = %Ctrl
@onready var alt: Panel = %Alt
@onready var w: Panel = %W
@onready var a: Panel = %A
@onready var s: Panel = %S
@onready var d: Panel = %D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if OS.get_name().to_lower() in ["macos", "ios"]:
		ctrl.get_child(0).text = "Cmd"
	visible = ProjectSettings.get_setting(FeatureFlagManager.SHOW_INPUT_OVERLAY, false)
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)

func _on_feature_flag_toggled(path: String, new_value: bool) -> void:
	if path == FeatureFlagManager.SHOW_INPUT_OVERLAY:
		visible = new_value


func _process(_delta: float) -> void:
	if !visible:
		return
	position = DisplayServer.mouse_get_position() + offset
	var state: int = DisplayServer.mouse_get_button_state()
	
	mouse_left_button.self_modulate = color_pressed if state & MOUSE_BUTTON_MASK_LEFT else color_released
	mouse_middle_button.self_modulate = color_pressed if state & MOUSE_BUTTON_MASK_MIDDLE else color_released
	mouse_right_button.self_modulate = color_pressed if state & MOUSE_BUTTON_MASK_RIGHT else color_released
	
	shift.self_modulate = color_pressed if Input.is_key_pressed(KEY_SHIFT) else color_released
	ctrl.self_modulate = color_pressed if Input.is_key_pressed(KEY_CTRL) else color_released
	alt.self_modulate = color_pressed if Input.is_key_pressed(KEY_ALT) else color_released
	w.self_modulate = color_pressed if Input.is_key_pressed(KEY_W) else color_released
	a.self_modulate = color_pressed if Input.is_key_pressed(KEY_A) else color_released
	s.self_modulate = color_pressed if Input.is_key_pressed(KEY_S) else color_released
	d.self_modulate = color_pressed if Input.is_key_pressed(KEY_D) else color_released
