class_name MessageBar extends PanelContainer


const Style: Dictionary = {
	WARNING_BEGIN = "[color=YELLOW][outline_color=241F21][outline_size=4]",
	WARNING_END = "[/outline_size][/outline_color][/color]",
	HINT_BEGIN = "ℹ ",
	HINT_END = "",
}
const Priority: Dictionary = {
	UNSET = -1,
	MESSAGE = 0,
	HINT = 1,
	WARNING = 2,
}

@onready var _label_messages: RichTextLabel = $HBoxContainerMessages/LabelMessages
@onready var _label_fps: Label = $HBoxContainerMessages/LabelFPS

var _meta_callbacks: Dictionary = {
#	meta_identifier<String> = callback<Callable>
}
var _fps_timer: Timer = null
var _last_message_priority: int = -1


func _ready() -> void:
	_label_messages.meta_clicked.connect(_on_label_messages_meta_clicked)
	_set_up_fps_timer()


func show_message(in_message: String, in_meta_callbacks: Dictionary = {}) -> void:
	if not _can_show(in_message, Priority.MESSAGE):
		return
	_meta_callbacks = in_meta_callbacks
	_label_messages.text = in_message


func show_hint(in_hint: String, in_meta_callbacks: Dictionary = {}) -> void:
	if not _can_show(in_hint, Priority.HINT):
		return
	_meta_callbacks = in_meta_callbacks
	_label_messages.text = Style.HINT_BEGIN + in_hint + Style.HINT_END


func show_warning(in_warning: String, in_meta_callbacks: Dictionary = {}) -> void:
	if not _can_show(in_warning, Priority.WARNING):
		return
	_meta_callbacks = in_meta_callbacks
	_label_messages.text = Style.WARNING_BEGIN + in_warning + Style.WARNING_END


func clear() -> void:
	_meta_callbacks.clear()
	_label_messages.text = ""


func _can_show(in_text: String, in_priority: int) -> bool:
	if in_text.is_empty() or in_priority < _last_message_priority:
		return false
	_last_message_priority = in_priority
	ScriptUtils.call_deferred_once(_reset_priority)
	return true


func _reset_priority() -> void:
	_last_message_priority = Priority.UNSET


func _on_label_messages_meta_clicked(in_meta_identifier: Variant) -> void:
	var callback: Callable = _meta_callbacks.get(in_meta_identifier, Callable()) as Callable
	if callback.is_valid():
		callback.call()
	else:
		push_error("Invalid meta identifier %s")


func _set_up_fps_timer() -> void:
	if OS.has_feature("debug"):
		_fps_timer = Timer.new()
		_fps_timer.one_shot = false
		_fps_timer.timeout.connect(_on_fps_timer_timeout)
		add_child(_fps_timer)
		_fps_timer.start(0.2)


func _on_fps_timer_timeout() -> void:
	_update_fps_label()


func _update_fps_label() -> void:
	if OS.has_feature("debug"):
		_label_fps.text = " (%.2f fps)" % Engine.get_frames_per_second()
