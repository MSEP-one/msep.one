class_name PlaybackSpeedPicker
extends HBoxContainer


signal playback_speed_changed(speed: float)

enum Speed {
	X2 = 0,
	X1 = 1,
	X05 = 2,
	X025 = 3,
	X005 = 4,
	CUSTOM = 5,
}

const SPEED_VALUE := {
	Speed.X2: 2.0,
	Speed.X1: 1.0,
	Speed.X05: 0.5,
	Speed.X025: 0.25,
	Speed.X005: 0.05,
	Speed.CUSTOM: 1.0,
}

@export var speed: float = 1.0
@export var editable: bool = true: set = _set_editable

@onready var _option_button: OptionButton = %OptionButton
@onready var _spinbox_slider: SpinBoxSlider = %SpinboxSlider


func _ready() -> void:
	_spinbox_slider.value_changed.connect(_on_spinbox_slider_value_changed)
	_option_button.item_selected.connect(_on_option_button_item_selected)
	_spinbox_slider.visible = false
	_spinbox_slider.value = 1.0


func get_playback_speed() -> float:
	return _spinbox_slider.get_value()


func _set_editable(in_is_editable: bool) -> void:
	editable = in_is_editable
	if not _spinbox_slider or not _option_button:
		await ready
	
	_spinbox_slider.editable = editable
	_option_button.disabled = not editable


func _on_spinbox_slider_value_changed(value: float) -> void:
	playback_speed_changed.emit(value)


func _on_option_button_item_selected(index: int) -> void:
	if index == Speed.CUSTOM:
		_spinbox_slider.visible = true
	else:
		_spinbox_slider.visible = false
		_spinbox_slider.set_value(SPEED_VALUE[index])
