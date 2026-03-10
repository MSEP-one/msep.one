class_name AdvancedColorPickerButton
extends Button


signal color_changed(new_color: Color)
signal color_reset


@export var show_reset_button: bool = true
@export var show_apply_button: bool = true
@export var color: Color = Color.WHITE:
	set = set_color,
	get = get_color


@onready var _color_rect: ColorRect = %ColorRect
@onready var _confirmation_color_popup: ConfirmationColorPopup = %ConfirmationColorPopup

func _ready() -> void:
	pressed.connect(_on_pressed)
	_confirmation_color_popup.color_selected.connect(_on_color_changed)
	_confirmation_color_popup.default_pressed.connect(_on_color_reset)
	_confirmation_color_popup.set_default_button_visible(show_reset_button)
	_confirmation_color_popup.set_apply_button_visible(show_apply_button)
	set_color(color)


func set_color(in_color: Color) -> void:
	color = in_color
	if not is_node_ready():
		return
	_color_rect.color = color


func get_color() -> Color:
	return color


func _on_pressed() -> void:
	var popup_position: Vector2 = global_position
	popup_position.y -= _confirmation_color_popup.size.y + 8
	var popup_rect: Rect2 = Rect2(popup_position, Vector2.ZERO)
	_confirmation_color_popup.set_current_color(color)
	_confirmation_color_popup.popup(popup_rect)


func _on_color_reset() -> void:
	_color_rect.color.a = 0.0
	color_reset.emit()


func _on_color_changed(in_color: Color) -> void:
	set_color(in_color)
	color_changed.emit(color)
