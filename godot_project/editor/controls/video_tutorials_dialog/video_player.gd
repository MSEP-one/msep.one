class_name VideoPlayer
extends Window


## A floating video player
##
## Shows a Play / Pause button and a seek bar.
## If the video stream does not support seeking, the bar is replaced with
## a Replay button instead. This happens when using the built in theora codec.


@onready var _video_stream_player: VideoStreamPlayer = %VideoStreamPlayer
@onready var _play_button: Button = %PlayButton
@onready var _pause_button: Button = %PauseButton
@onready var _seek_bar: HSlider = %SeekBar
@onready var _replay_button: Button = %ReplayButton
@onready var _full_screen_button: Button = %FullScreenButton
@onready var _window_size_and_pos: Dictionary = {
	"position" = position,
	"size" = size
}


func _ready() -> void:
	_play_button.pressed.connect(play)
	_pause_button.pressed.connect(pause)
	_replay_button.pressed.connect(_on_replay_pressed)
	_full_screen_button.toggled.connect(_on_full_screen_button_toggled)
	get_tree().root.size_changed.connect(_on_main_window_size_changed)
	close_requested.connect(_on_close_requested)
	pause()


func _process(_delta: float) -> void:
	if _video_stream_player.is_playing():
		_seek_bar.set_value_no_signal(_video_stream_player.get_stream_position())


func set_video(video_path: String, autoplay: bool = true) -> void:
	var stream: VideoStream = load(video_path)
	if not stream:
		return
	_video_stream_player.set_stream(stream)
	_video_stream_player.play() # Needs to be called at least once
	
	var seek_supported: bool = not (stream is VideoStreamTheora)
	set_process(seek_supported)
	_replay_button.visible = not seek_supported
	_seek_bar.visible = seek_supported
	_seek_bar.max_value = _video_stream_player.get_stream_length()
	_seek_bar.value = 0.0
	
	if autoplay:
		play()
	else:
		pause()


func play() -> void:
	_play_button.hide()
	_pause_button.show()
	_video_stream_player.set_paused(false)


func pause() -> void:
	_play_button.show()
	_pause_button.hide()
	_video_stream_player.set_paused(true)


func _on_replay_pressed() -> void:
	_video_stream_player.play()
	play()


func _on_full_screen_button_toggled(in_button_pressed: bool) -> void:
	if in_button_pressed:
		_full_screen_button.text = tr(&"Window View")
		_full_screen_button.icon = preload("res://editor/controls/video_tutorials_dialog/icons/window_view.svg")
		# Store window values before changing them
		_window_size_and_pos = {
			"position" = position,
			"size" = size
		}
		borderless = true
		_update_full_screen_size()
	else:
		_full_screen_button.text = tr(&"Full Screen")
		_full_screen_button.icon = preload("res://editor/controls/video_tutorials_dialog/icons/full_screen.svg")
		borderless = false
		position = _window_size_and_pos.position
		size = _window_size_and_pos.size


func _on_main_window_size_changed() -> void:
	if _full_screen_button.button_pressed:
		_update_full_screen_size()


func _update_full_screen_size() -> void:
	position = Vector2.ZERO
	size = get_tree().root.size

func _on_close_requested() -> void:
	pause()
	hide()
