extends ScrollContainer

const SfxPanelScript = preload("res://autoloads/about_msep_one/other_attributions/sfx_panel.gd")


var _sfx_panel_template: InstancePlaceholder

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_sfx_panel_template = %SfxPanelTemplate as InstancePlaceholder


func _ready() -> void:
	for audio_attribution: ResourceAttribution in Attributions.audio_streams:
		var instance: SfxPanelScript = _sfx_panel_template.create_instance()
		instance.load_sfx_attribution(audio_attribution)
