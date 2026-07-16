class_name MessageBar extends PanelContainer


const Style: Dictionary = {
	WARNING_BEGIN = "[color=YELLOW][outline_color=241F21][outline_size=4]",
	WARNING_END = "[/outline_size][/outline_color][/color]",
	HINT_BEGIN = "ℹ ",
	HINT_END = "",
}
const Priority: Dictionary = {
	UNSET  = -1,
	MESSAGE = 0,
	ACTION  = 1,
	HINT    = 2,
	WARNING = 3,
}

@onready var _label_messages: RichTextLabel = $HBoxContainerMessages/LabelMessages
@onready var _label_fps: Label = $HBoxContainerMessages/LabelFPS
@onready var _label_distance: Label = $HBoxContainerMessages/Distance

var _meta_callbacks: Dictionary = {}
var _fps_timer: Timer = null
var _action_expired_timer: Timer = null
var _scheduled_message: String
var _scheduled_message_meta_callbacks: Dictionary
var _current_message_priority: int = Priority.UNSET
var _last_message_priority: int = Priority.UNSET


func _ready() -> void:
	_label_messages.meta_clicked.connect(_on_label_messages_meta_clicked)
	_set_up_timers()


func show_message(in_message: String, in_meta_callbacks: Dictionary = {}) -> void:
	if not _can_show(in_message, Priority.MESSAGE):
		return
	_scheduled_message = in_message
	_scheduled_message_meta_callbacks = in_meta_callbacks
	_action_expired_timer.start(1.0)
	_meta_callbacks = in_meta_callbacks
	_label_messages.text = in_message


func show_action(in_action: String, in_meta_callbacks: Dictionary = {}) -> void:
	if not _can_show(in_action, Priority.ACTION):
		return
	_meta_callbacks = in_meta_callbacks
	_label_messages.text = in_action


func show_hint(in_hint: String, in_meta_callbacks: Dictionary = {}) -> void:
	if not _can_show(in_hint, Priority.HINT):
		return
	_action_expired_timer.stop()
	_meta_callbacks = in_meta_callbacks
	_label_messages.text = Style.HINT_BEGIN + in_hint + Style.HINT_END


func show_warning(in_warning: String, in_meta_callbacks: Dictionary = {}) -> void:
	if not _can_show(in_warning, Priority.WARNING):
		return
	_action_expired_timer.stop()
	_meta_callbacks = in_meta_callbacks
	_label_messages.text = Style.WARNING_BEGIN + in_warning + Style.WARNING_END


func clear() -> void:
	_meta_callbacks.clear()
	_label_messages.text = ""


func update_distance(in_message_text: String, in_distance: float) -> void:
	if in_message_text.is_empty():
		_label_distance.text = ""
	else:
		var distance: String = "%.2f" % in_distance
		_label_distance.text = in_message_text + " " + distance + " nm"


func update_angle(in_message_text: String, in_angle: float) -> void:
	if in_message_text.is_empty():
		_label_distance.text = ""
	else:
		var angle: String = "%.2f" % in_angle
		_label_distance.text = in_message_text + " " + angle + "º"


func _can_show(in_text: String, in_priority: int) -> bool:
	if in_text.is_empty() or in_priority < _last_message_priority:
		return false
	_last_message_priority = in_priority
	_current_message_priority = in_priority
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


func _set_up_timers() -> void:
	if OS.has_feature("debug"):
		_fps_timer = Timer.new()
		_fps_timer.one_shot = false
		_fps_timer.timeout.connect(_on_fps_timer_timeout)
		add_child(_fps_timer)
		_fps_timer.start(0.2)
	_action_expired_timer = Timer.new()
	_action_expired_timer.one_shot = true
	_action_expired_timer.timeout.connect(_on_action_expired_timer_timeout)
	add_child(_action_expired_timer)
	_action_expired_timer.start(1.0)


func _on_fps_timer_timeout() -> void:
	_update_fps_label()


func _on_action_expired_timer_timeout() -> void:
	if _current_message_priority == Priority.ACTION and not _scheduled_message in ["", _label_messages.text]:
		show_message(_scheduled_message, _scheduled_message_meta_callbacks)


func _update_fps_label() -> void:
	if OS.has_feature("debug"):
		_label_fps.text = " (%.2f fps)" % Engine.get_frames_per_second()
