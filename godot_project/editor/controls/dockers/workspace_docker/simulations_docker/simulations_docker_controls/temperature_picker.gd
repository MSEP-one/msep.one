@tool
class_name TemperaturePicker extends HBoxContainer

signal temperature_changed(magnitude: float, unit: Unit)

enum Unit {
	KELVIN = 0,
	FAHRENHEIT = 1,
	CELSIUS = 2
}

const MIN_PER_UNIT: Dictionary = {
	Unit.KELVIN: 0.0,
	Unit.FAHRENHEIT: -459.67,
	Unit.CELSIUS: -273.15
}

const SLIDER_MAX_PER_UNIT: Dictionary = {
	Unit.KELVIN: 473.15,
	Unit.FAHRENHEIT: 392.0,
	Unit.CELSIUS: 200.0
}

const UNIT_SYMBOL: Dictionary = {
	Unit.KELVIN: "K",
	Unit.FAHRENHEIT: "ºF",
	Unit.CELSIUS: "ºC"
}

@export var temperature_kelvins: float: set = _set_temperature_in_kelvins, get = _get_temperature_in_kelvins
@export var current_unit: Unit = Unit.KELVIN: set = _set_current_unit
@export var editable: bool = true: set = _set_editable


var _spin_box_slider: SpinBoxSlider = null
var _option_button_temperature_unit: OptionButton = null


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		# Hack: temperature_kelvins is assigned on _init, but cannot be assigned to
		#+the spinbox until the _spin_box_slider variable is set
		var temp: float = temperature_kelvins
		_spin_box_slider = $SpinBoxSlider as SpinBoxSlider
		temperature_kelvins = temp
		#/Hack
		
		_option_button_temperature_unit = $OptionButtonTemperatureUnit
		if not Engine.is_editor_hint():
			FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
			_build_units_list()
		_set_editable(editable)
		
		_option_button_temperature_unit.item_selected.connect(_on_option_button_temperature_unit_item_selected)
		_spin_box_slider.value_confirmed.connect(_on_spin_box_slider_value_confirmed)


func _on_feature_flag_toggled(path: String, _new_value: bool) -> void:
	if path == FeatureFlagManager.TEMPERATURE_IN_FAHRENHEIT and is_instance_valid(_option_button_temperature_unit):
		_build_units_list()

func _build_units_list() -> void:
	var selected_idx: int = _option_button_temperature_unit.selected
	var selected_id: int = _option_button_temperature_unit.get_item_id(selected_idx)
	var show_fahrenheit: bool = FeatureFlagManager.get_flag_value(FeatureFlagManager.TEMPERATURE_IN_FAHRENHEIT)
	_option_button_temperature_unit.clear()
	_option_button_temperature_unit.add_item("Kelvin (K)", Unit.KELVIN)
	if show_fahrenheit:
		_option_button_temperature_unit.add_item("Fahrenheit (ºF)", Unit.FAHRENHEIT)
	else:
		if selected_id == Unit.FAHRENHEIT:
			selected_id = Unit.KELVIN
	_option_button_temperature_unit.add_item("Celsius (ºC)", Unit.CELSIUS)
	_option_button_temperature_unit.select(_option_button_temperature_unit.get_item_index(selected_id))
	current_unit = selected_id as Unit

func _on_option_button_temperature_unit_item_selected(in_index: int) -> void:
	var id: int = _option_button_temperature_unit.get_item_id(in_index)
	_set_current_unit(id as Unit)


func _set_temperature_in_kelvins(in_temp: float) -> void:
	temperature_kelvins = in_temp
	if _spin_box_slider == null:
		return
	_spin_box_slider.set_value_no_signal(kelvin_to_unit(in_temp, current_unit))


func _get_temperature_in_kelvins() -> float:
	if _spin_box_slider == null:
		return temperature_kelvins
	return unit_to_kelvin(_spin_box_slider.value, current_unit)


func _on_spin_box_slider_value_confirmed(in_new_value: float) -> void:
	temperature_changed.emit(in_new_value, current_unit)


func _set_current_unit(in_new_unit: Unit) -> void:
	if in_new_unit == current_unit:
		return
	var old_in_kelvins: float = temperature_kelvins
	var new_magnitude: float = kelvin_to_unit(old_in_kelvins, in_new_unit)
	current_unit = in_new_unit
	_spin_box_slider.suffix = UNIT_SYMBOL[in_new_unit]
	_spin_box_slider.min_value = MIN_PER_UNIT[in_new_unit]
	_spin_box_slider.set_value_no_signal(new_magnitude)
	var index: int = _option_button_temperature_unit.get_item_index(in_new_unit)
	if _option_button_temperature_unit.selected != index:
		_option_button_temperature_unit.select(index)
	temperature_changed.emit(new_magnitude, in_new_unit)


func _set_editable(in_new_is_editable: bool) -> void:
	editable = in_new_is_editable
	if _spin_box_slider == null:
		return
	_spin_box_slider.editable = in_new_is_editable
	_spin_box_slider.slider.editable = in_new_is_editable
	_option_button_temperature_unit.disabled = not in_new_is_editable


static func unit_to_kelvin(in_magnitude: float, in_from_unit: Unit) -> float:
	match in_from_unit:
		Unit.KELVIN:
			return in_magnitude
		Unit.FAHRENHEIT:
			return (in_magnitude - 32) * (5.0 / 9.0)  + 273.15
		Unit.CELSIUS:
			return (in_magnitude + 273.15)
	assert(false, "Unexpected Temperature Unit")
	return 0


static func kelvin_to_unit(kelvins: float, to_unit: Unit) -> float:
	match to_unit:
		Unit.KELVIN:
			return kelvins
		Unit.FAHRENHEIT:
			return (kelvins - 273.15) * (9.0 / 5.0)  + 32
		Unit.CELSIUS:
			return (kelvins - 273.15)
	assert(false, "Unexpected Temperature Unit")
	return 0

