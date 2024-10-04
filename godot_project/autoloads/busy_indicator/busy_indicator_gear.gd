extends Sprite2D

var _spin_factor: float = 1
@export var speed: float = 1


func _process(delta: float) -> void:
	rotation += speed * delta * _spin_factor


func set_spin_factor(in_factor: float) -> void:
	_spin_factor = in_factor
