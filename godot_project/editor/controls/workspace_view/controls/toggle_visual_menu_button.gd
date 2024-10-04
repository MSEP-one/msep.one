extends Button

var _force_visual_menu_enabled: bool = false


func _ready() -> void:
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	pressed.connect(_on_pressed)
	if DisplayServer.has_feature(DisplayServer.FEATURE_GLOBAL_MENU) and not _force_visual_menu_enabled:
		hide()
	else:
		show()


func _on_pressed() -> void:
	var offset: Vector2 = get_global_rect().position + Vector2(0, size.y)
	VisualMainMenu.position = offset
	VisualMainMenu.popup()


func _on_feature_flag_toggled(path: String, new_value: bool) -> void:
	if path != FeatureFlagManager.FEATURE_FLAG_ENABLE_VISUAL_MENU_ON_ALL_PLATFORMS or \
	   new_value == _force_visual_menu_enabled:
		return
	_force_visual_menu_enabled = new_value
	if _force_visual_menu_enabled:
		show()
	else:
		hide()
