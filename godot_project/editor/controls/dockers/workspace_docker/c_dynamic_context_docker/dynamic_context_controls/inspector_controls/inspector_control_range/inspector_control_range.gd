class_name InspectorControlRange extends InspectorControl


var range_control: Range
var _property_changed_signal := Signal()
var _getter := Callable()
var _setter := Callable()


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		range_control = $Range
		range_control.value_changed.connect(_on_range_control_value_changed)


func _on_range_control_value_changed(in_value: float) -> void:
	if _setter.is_valid():
		_setter.call(in_value)


func setup(in_getter: Callable, in_setter: Callable = Callable(), in_changed_signal: Signal = Signal()) -> void:
	assert(in_getter.is_valid())
	_property_changed_signal = in_changed_signal
	_getter = in_getter
	_setter = in_setter
	if !in_changed_signal.is_null():
		in_changed_signal.connect(_on_changed_signal_emitted)
	_on_changed_signal_emitted()


func _on_changed_signal_emitted(_ignored_1: Variant = null, _ignored_2: Variant = null, _ignored_3: Variant = null) -> void:
	var value: float = _getter.call()
	range_control.set_value_no_signal(value)


func is_editable() -> bool:
	return _setter.is_valid()

