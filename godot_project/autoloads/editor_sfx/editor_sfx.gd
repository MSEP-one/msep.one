extends Node


@export var rollover_sounds: Array[AudioStream]
@export var open_menu_sounds: Array[AudioStream]
@export var close_menu_sounds: Array[AudioStream]
@export var window_open_sounds: Array[AudioStream]
@export var window_close_sounds: Array[AudioStream]
@export var mouse_down_sounds: Array[AudioStream]
@export var mouse_up_sounds: Array[AudioStream]
@export var materialize_object_sounds: Array[AudioStream]
@export var delete_object_sounds: Array[AudioStream]


func rollover() -> void:
	_play_random($rollover, rollover_sounds)


func open_menu() -> void:
	_play_random($open_menu, open_menu_sounds)


func close_menu() -> void:
	_play_random($close_menu, close_menu_sounds)


func open_window() -> void:
	_play_random($window_open, window_open_sounds)


func close_window() -> void:
	_play_random($window_close, window_close_sounds)


func mouse_down() -> void:
	_play_random($mouse, mouse_down_sounds)


func mouse_up() -> void:
	_play_random($mouse, mouse_up_sounds)


func create_object() -> void:
	_play_random($nano_object, materialize_object_sounds)


func delete_object() -> void:
	_play_random($nano_object, delete_object_sounds)

func register_window(in_window: Window, in_force: bool = false) -> void:
	if in_window == null:
		return
	if in_window.get_flag(Window.FLAG_BORDERLESS) and !in_force:
		# popup menus are not windows unless forced
		return
	if !in_window.visibility_changed.is_connected(_on_window_visibility_changed):
		in_window.visibility_changed.connect(_on_window_visibility_changed.bind(in_window))


func _play_random(player: AudioStreamPlayer, library: Array[AudioStream]) -> void:
	if player == null:
		push_error("Cannot play sound in null AudioStreamPlayer")
		return
	if library.size() == 0:
		push_error("No stream source specified for sfx of type %s" % player.name)
		return
	var s: AudioStream = library[randi() % library.size()]
	player.stream = s
	player.play()


func _on_window_visibility_changed(in_window: Window) -> void:
	if in_window == null:
		return
	if in_window.is_queued_for_deletion() or !in_window.visible:
		close_window()
	else:
		open_window()
