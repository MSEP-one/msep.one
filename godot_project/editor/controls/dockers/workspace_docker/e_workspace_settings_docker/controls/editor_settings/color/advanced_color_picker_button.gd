class_name AdvancedColorPickerButton
extends Button


signal color_changed(new_color: Color)
signal color_reset

@onready var _color_rect: ColorRect = %ColorRect
@onready var _confirmation_color_popup: ConfirmationColorPopup = %ConfirmationColorPopup

func _ready() -> void:
	pressed.connect(_on_pressed)
	_confirmation_color_popup.color_selected.connect(_on_color_changed)
	_confirmation_color_popup.default_pressed.connect(_on_color_reset)


func set_color(color: Color) -> void:
	_color_rect.color = color


func _on_pressed() -> void:
	var popup_position: Vector2 = global_position
	popup_position.y -= _confirmation_color_popup.size.y + 8
	var popup_rect: Rect2 = Rect2(popup_position, Vector2.ZERO)
	_confirmation_color_popup.popup(popup_rect)


func _on_color_reset() -> void:
	_color_rect.color.a = 0.0
	color_reset.emit()


func _on_color_changed(color: Color) -> void:
	_color_rect.color = color
	color_changed.emit(color)
