extends Line2D

var _spin_factor: float = 0
var _acum: float = 0

func _process(delta: float) -> void:
	_acum += delta * _spin_factor
	material.set(&"shader_parameter/time", _acum)


func set_spin_factor(in_factor: float) -> void:
	_spin_factor = in_factor
	material.set(&"shader_parameter/spin_factor", in_factor)

