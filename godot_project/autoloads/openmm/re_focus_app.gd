extends Node

# On some Windows systems for some reason the main app window hides behind
# other windows upon app starting. This attempts to mitigate the issue.

const MAX_FOCUS_ATTEMPT_TIME: float = .5

@onready var _app_window: Window = get_tree().get_root()
@onready var _start_ticks: int = Time.get_ticks_msec()

func _process(_in_delta: float) -> void:
	if ! _app_window.has_focus():
		_app_window.grab_focus()
		queue_free()
		print("Unfocused app window was detected, re focusing.")
	else:
		if Time.get_ticks_msec() - _start_ticks > MAX_FOCUS_ATTEMPT_TIME * 1000:
			queue_free()
