@tool
class_name InfoLabel extends RichTextLabel


# Info label constants
const _DIMMED_ALPHA: float = 0.2
const _HIGHLIGHTED_TEMPLATE: String = \
	"[center][{effect} start=4 length=14 freq=0.5 sat=0.8 val=0.8 connected=1]ℹ[/{effect}] {message}[/center]"
const _HIGHLIGHTED_WITH_TEXT_TEMPLATE: String = \
	"[center][{effect} start=4 length=14 freq=0.5 sat=0.8 val=0.8 connected=1]ℹ {message}[/{effect}][/center]"
const _LOWLIGHTED_TEMPLATE: String = \
	"[center]ℹ {message}[/center]"

@export var highlighted: bool = true:
	set = _set_highlighted
@export var message: StringName = &"":
	set = _set_message
@export_enum("pulse","wave","tornado","shake","fade","rainbow") var effect: String = "shake":
	set = _set_effect
@export var effect_affects_message: bool = false:
	set = _set_effect_affects_message


var _update_queued: bool = false


func _ready() -> void:
	_update_message()


func _set_highlighted(in_highlighted: bool) -> void:
	if not is_inside_tree():
		return
	highlighted = in_highlighted
	var tween: Tween = create_tween()
	var target_alpha: float = 1.0 if highlighted else _DIMMED_ALPHA
	tween.tween_property(self, "self_modulate:a", target_alpha, 0.1)
	_queue_update_message()


func _set_message(in_message: StringName) -> void:
	message = in_message
	_queue_update_message()


func _set_effect(in_effect: String) -> void:
	effect = in_effect
	_queue_update_message()


func _set_effect_affects_message(in_effect_affects_message: bool) -> void:
	effect_affects_message = in_effect_affects_message
	_queue_update_message()


func _queue_update_message() -> void:
	if Engine.is_editor_hint():
		_update_message()
		return
	if _update_queued:
		return
	_update_queued = true
	_update_message.call_deferred()


func _update_message() -> void:
	_update_queued = false
	var template: String = ""
	match [highlighted, effect_affects_message]:
		[true, true]:
			template = _HIGHLIGHTED_WITH_TEXT_TEMPLATE
		[true, false]:
			template = _HIGHLIGHTED_TEMPLATE
		[false, _]:
			template = _LOWLIGHTED_TEMPLATE
	var arguments: Dictionary = {
		effect  = self.effect,
		message = tr(self.message)
	}
	text = template.format(arguments)
