class_name TagLabel
extends PanelContainer

signal erase_requested()

var text: String:
	set = _set_text
var erase_button_visible: bool:
	set = _set_erase_button_visible


var _label: Label
var _erase_button: Button
var _erase_animation_player: AnimationPlayer


static func create_tag(tag: String, show_erase_button: bool = true) -> TagLabel:
	var label: TagLabel = load("uid://rp5yqpl1d0rh").instantiate()
	label.text = tag
	label.erase_button_visible = show_erase_button
	return label


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_label = %Label as Label
		_erase_button = %EraseButton as Button
		_erase_animation_player = %EraseAnimationPlayer as AnimationPlayer
	if what == NOTIFICATION_READY:
		_erase_button.pressed.connect(_on_erase_button_pressed)


func _on_erase_button_pressed() -> void:
	_erase_animation_player.play(&"loading")
	erase_requested.emit()


func reset_erase_button() -> void:
	_erase_animation_player.play(&"RESET")


func _set_text(in_text: String) -> void:
	text = in_text
	_label.text = text


func _set_erase_button_visible(in_visible: bool) -> void:
	erase_button_visible = in_visible
	_erase_button.visible = in_visible
