class_name InspectorControlVector3 extends InspectorControl


var _x: SpinBox
var _y: SpinBox
var _z: SpinBox


var _property_changed_signal := Signal()
var _getter := Callable()
var _setter := Callable()


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_x = $Components/X
		_y = $Components/Y
		_z = $Components/Z
		_x.value_changed.connect(_on_value_changed)
		_y.value_changed.connect(_on_value_changed)
		_z.value_changed.connect(_on_value_changed)
	elif in_what == NOTIFICATION_READY:
		assert(_getter != Callable(), "Needs to be initalized with setup() before adding to a tree")
		pass


func _on_value_changed(_ignored_arg: float) -> void:
	var new_value: Vector3 = Vector3(_x.value, _y.value, _z.value)
	if _setter.is_valid():
		_setter.call(new_value)


func setup(in_getter: Callable, in_setter: Callable = Callable(), in_property_changed_signal: Signal = Signal()) -> void:
	assert(in_getter.is_valid())
	if not _property_changed_signal.is_null():
		# disconnect previous signal
		in_property_changed_signal.disconnect(_on_changed_signal_emitted)
	_property_changed_signal = in_property_changed_signal
	_getter = in_getter
	_setter = in_setter
	if !in_property_changed_signal.is_null():
		in_property_changed_signal.connect(_on_changed_signal_emitted)
	_on_changed_signal_emitted()


func _on_changed_signal_emitted(_ignored_1: Variant = null, _ignored_2: Variant = null, _ignored_3: Variant = null) -> void:
	var value: Vector3 = _getter.call()
	_x.set_value_no_signal(value.x)
	_x.get_line_edit().text = str(value.x)
	_y.set_value_no_signal(value.y)
	_y.get_line_edit().text = str(value.y)
	_z.set_value_no_signal(value.z)
	_z.get_line_edit().text = str(value.z)


func set_editable(in_is_editable: bool) -> void:
	_x.editable = in_is_editable
	_y.editable = in_is_editable
	_z.editable = in_is_editable


func is_editable() -> bool:
	assert(_x != null)
	return _x.editable
