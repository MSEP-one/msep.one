class_name RingMenuState extends RefCounted


var _levels: Array[RingMenuLevel] = []


func push(new_level: RingMenuLevel) -> void:
	_levels.push_back(new_level)


func pop() -> RingMenuLevel:
	if _levels.size() <= 1:
		return null
	return _levels.pop_back()


func get_current_level() -> RingMenuLevel:
	return _levels.back()


func is_top_level() -> bool:
	return _levels.size() == 1


## returns deep of current level, top level is at deepness 0
func get_deepness() -> int:
	return _levels.size() - 1


func is_empty() -> bool:
	return _levels.is_empty()


func clear() -> void:
	for lvl in _levels:
		lvl.clear()
	_levels.clear()
