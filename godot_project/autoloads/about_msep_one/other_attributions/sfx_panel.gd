extends PanelContainer


@export var allow_to_play_sfx: bool = true

var _play_button: Button
var _playback_slider: HSlider
var _original_name: Label
var _author: LinkButton
var _license: LinkButton
var _source_url: LinkButton
var _audio_player: AudioStreamPlayer

var _resource_attribution: ResourceAttribution

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_play_button = %PlayButton as Button
		_playback_slider = %PlaybackSlider as HSlider
		_original_name = %OriginalName as Label
		_author = %Author as LinkButton
		_license = %License as LinkButton
		_source_url = %SourceUrl as LinkButton
		_audio_player = %AudioPlayer as AudioStreamPlayer

		_play_button.pressed.connect(_on_play_button_pressed)
		_audio_player.finished.connect(_on_audio_player_finished)
		_author.pressed.connect(_on_author_pressed)
		_license.pressed.connect(_on_license_pressed)
		_source_url.pressed.connect(_on_source_url_pressed)
		_play_button.disabled = true
		if not allow_to_play_sfx:
			_play_button.hide()
			_playback_slider.hide()


func load_sfx_attribution(in_resource_attribution: ResourceAttribution) -> void:
	assert(in_resource_attribution != null)
	var audio_stream: AudioStream = in_resource_attribution.resource as AudioStream
	assert(audio_stream != null)
	_resource_attribution = in_resource_attribution
	_audio_player.stream = audio_stream
	_playback_slider.max_value = audio_stream.get_length()
	_original_name.text = in_resource_attribution.original_name
	_author.text = ", ".join(in_resource_attribution.authors.keys())
	_license.text = in_resource_attribution.license_name
	_source_url.text = in_resource_attribution.original_source_link
	_on_audio_player_finished()
	
	


func _process(delta: float) -> void:
	# Assumed only executed while sound is playing
	_playback_slider.value += delta


func _on_play_button_pressed() -> void:
	# Start playback
	set_process(true)
	_play_button.disabled = true
	_audio_player.play()


func _on_audio_player_finished() -> void:
	# Reset playback
	set_process(false)
	_playback_slider.value = 0
	_play_button.disabled = false


func _on_author_pressed() -> void:
	if _resource_attribution != null and !_resource_attribution.authors.is_empty() and !_resource_attribution.authors.values()[0].is_empty():
		var url: String = _resource_attribution.authors.values()[0]
		OS.shell_open(url)


func _on_license_pressed() -> void:
	if _resource_attribution != null and !_resource_attribution.license_link.is_empty():
		var url: String = _resource_attribution.license_link
		OS.shell_open(url)


func _on_source_url_pressed() -> void:
	if _resource_attribution != null and !_resource_attribution.original_source_link.is_empty():
		var url: String = _resource_attribution.original_source_link
		OS.shell_open(url)
