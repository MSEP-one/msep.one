@tool
class_name TimeSpanPicker extends HBoxContainer

signal time_span_changed(magnitude: float, unit: Unit)

enum Unit {
	FEMTOSECOND = 0,
	PICOSECOND = 1,
	NANOSECOND = 2
}



const UNIT_SYMBOL: Dictionary = {
	Unit.FEMTOSECOND: "fs",
	Unit.PICOSECOND: "ps",
	Unit.NANOSECOND: "ns"
}

@export var time_span_femtoseconds: float:
	set = _set_time_span_in_femtoseconds
@export var min_value_in_femtoseconds: float = 0.05
@export var current_unit: Unit = Unit.FEMTOSECOND: set = _set_current_unit
@export var editable: bool = true: set = _set_editable

var _spin_box_slider: SpinBoxSlider = null
var _option_button_time_span_unit: OptionButton = null


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		# Hack: time_span_femtoseconds is assigned on _init, but cannot be assigned to
		#+the spinbox until the _spin_box_slider variable is set
		var time: float = time_span_femtoseconds
		_spin_box_slider = $SpinBoxSlider
		time_span_femtoseconds = time
		#/Hack
		
		_option_button_time_span_unit = $OptionButtonTimeSpanUnit
		_set_editable(editable)
		
		_option_button_time_span_unit.item_selected.connect(_on_option_button_time_span_unit_item_selected)
		_spin_box_slider.value_confirmed.connect(_on_spin_box_slider_value_confirmed)


func _on_option_button_time_span_unit_item_selected(in_index: int) -> void:
	_set_current_unit(in_index as Unit)


func _set_time_span_in_femtoseconds(in_time: float) -> void:
	time_span_femtoseconds = in_time
	if _spin_box_slider == null:
		return
	_spin_box_slider.set_value_no_signal(femtoseconds_to_unit(in_time, current_unit))


func _on_spin_box_slider_value_confirmed(in_new_value: float) -> void:
	time_span_changed.emit(in_new_value, current_unit)


func _set_current_unit(in_new_unit: Unit) -> void:
	if in_new_unit == current_unit:
		return
	var old_in_femtoseconds: float = time_span_femtoseconds
	var new_min_value: float = femtoseconds_to_unit(min_value_in_femtoseconds, in_new_unit)
	_spin_box_slider.set_block_signals(true)
	_spin_box_slider.min_value = new_min_value
	_spin_box_slider.step = new_min_value
	var new_magnitude: float = femtoseconds_to_unit(old_in_femtoseconds, in_new_unit)
	current_unit = in_new_unit
	_spin_box_slider.suffix = UNIT_SYMBOL[in_new_unit]
	_spin_box_slider.value = new_magnitude
	_spin_box_slider.set_block_signals(false)
	if _option_button_time_span_unit.selected != in_new_unit:
		_option_button_time_span_unit.select(in_new_unit)
	time_span_changed.emit(new_magnitude, in_new_unit)


func _set_editable(in_new_is_editable: bool) -> void:
	editable = in_new_is_editable
	if _spin_box_slider == null:
		return
	_spin_box_slider.editable = in_new_is_editable
	_spin_box_slider.slider.editable = in_new_is_editable
	_option_button_time_span_unit.disabled = not in_new_is_editable


static func unit_to_femtoseconds(in_magnitude: float, in_from_unit: Unit) -> float:
	match in_from_unit:
		Unit.FEMTOSECOND:
			return in_magnitude
		Unit.PICOSECOND:
			return in_magnitude * 1e+3
		Unit.NANOSECOND:
			return in_magnitude * 1e+6
	assert(false, "Unexpected TimeSpan Unit")
	return 0


static func femtoseconds_to_unit(femtoseconds: float, to_unit: Unit) -> float:
	match to_unit:
		Unit.FEMTOSECOND:
			return femtoseconds
		Unit.PICOSECOND:
			return femtoseconds / 1e+3
		Unit.NANOSECOND:
			return femtoseconds / 1e+6
	assert(false, "Unexpected TimeSpan Unit")
	return 0

