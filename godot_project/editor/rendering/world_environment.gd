extends WorldEnvironment


const DarkBackgroundSky = preload("res://editor/rendering/resources/background_sky.tres")
const LightBackgroundSky = preload("res://editor/rendering/resources/sky.tres")


func _ready() -> void:
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	_on_feature_flag_toggled(
		FeatureFlagManager.USE_DARK_BACKGROUND_ENVIRONMENT_FLAG,
		ProjectSettings.get_setting(FeatureFlagManager.USE_DARK_BACKGROUND_ENVIRONMENT_FLAG, true)
	)

func _on_feature_flag_toggled(in_path: String, in_value: bool) -> void:
	if in_path == FeatureFlagManager.USE_DARK_BACKGROUND_ENVIRONMENT_FLAG:
		environment.sky = DarkBackgroundSky if in_value else LightBackgroundSky
