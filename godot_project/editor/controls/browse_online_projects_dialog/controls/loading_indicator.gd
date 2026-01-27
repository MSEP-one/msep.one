@tool
extends Control

@onready var _control: Control = $Control

func _ready() -> void:
	_control.draw.connect(_on_control_drawn)


func _on_control_drawn() -> void:
	const DOTS_COUNT: int = 9
	const DOTS_RADIUS: float = 8
	const DOTS_MAX_OPACITY: float = 0.7
	const DOTS_MIN_OPACITY: float = 0.05
	const RADIUS: float = 30
	
	const ANGLE_STEP: float = 2 * PI / DOTS_COUNT
	for i in DOTS_COUNT:
		var pos: Vector2 = (Vector2.UP * RADIUS).rotated(ANGLE_STEP * i)
		var color := Color(1, 1, 1, lerp(DOTS_MAX_OPACITY, DOTS_MIN_OPACITY, i / float(DOTS_COUNT)))
		_control.draw_circle(pos, DOTS_RADIUS, color)
