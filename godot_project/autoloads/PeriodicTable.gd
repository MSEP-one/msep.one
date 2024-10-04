@tool
extends Node

const ATOMIC_NUMBER_HYDROGEN = 1
const ATOMIC_NUMBER_CARBON = 6
const MAX_ATOMIC_NUMBER = 118

const INVALID_ATOMIC_NUMBER = -1
const NON_METALS = [1, 6, 7, 8, 9, 14, 15, 16, 17]
#				   [H, C, N, O, F, Si,  P,  S, Cl]

# Read only
@export
var _elements : Dictionary
var _elements_by_name : Dictionary
var _elements_by_symbol : Dictionary
var _unknown_element := ElementData.new("-1,0,0,,Unknown,,,,,,,,,,,,#FFFFFF,#FFFFFF,#FFFFFF,#000000,0.0")


func _init() -> void:
	var f := FileAccess.open("res://autoloads/data/periodic_table_data.csv", FileAccess.READ)
	if f == null:
		push_error("Could not load Periodic Table Data file")
		return
	f.get_line() # Discard header
	while !f.eof_reached():
		var element_data: String = f.get_line()
		if element_data.is_empty():
			continue
		var element := ElementData.new(element_data)
		_elements[element.number] = element
		_elements_by_name[element.name] = element
		_elements_by_symbol[element.symbol] = element

func get_by_atomic_number(number : int) -> ElementData:
	if !_elements.has(number):
		assert(false, "Unknown element with atomic number %d" % number)
		return _unknown_element
	return _elements[number]
	

func get_by_name(in_name : String) -> ElementData:
	if !_elements_by_name.has(in_name):
		push_warning("Unknown element with name %s" % in_name)
		return _unknown_element
	return _elements_by_name[in_name]

func get_by_symbol(symbol : String) -> ElementData:
	if !_elements_by_symbol.has(symbol):
		push_warning("Unknown element with symbol %s" % symbol)
		return _unknown_element
	return _elements_by_symbol[symbol]

