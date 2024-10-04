class_name SingleColorButton
extends Button


@export var color: Color:
	set = set_color

@onready var _color_rect: ColorRect = %ColorRect


func set_color(in_color: Color) -> void:
	color = in_color
	if not is_instance_valid(_color_rect):
		await ready
	_color_rect.color = in_color
