class_name ExtendedElementPicker
extends ElementPickerBase

## Complete periodic table picker.
## Features a search bar that activate / deactivate the relevant elements
## to make them easier to spot.


var _active_buttons: Array[ElementPickerButton] = []
var _buttons: Dictionary = {
	# Symbol<String> : Button<ElementPickerButton>
}

@onready var search_bar: LineEdit = %SearchBar
var _hydrogen_enabled: bool = true

func _ready() -> void:
	super()
	search_bar.text_changed.connect(_on_search_bar_text_changed)
	search_bar.text_submitted.connect(_on_search_bar_text_submitted)
	connect("about_to_popup", _on_about_to_popup) # Can't use the proper signal object because of the wrong inheritance
	
	# Discover every element buttons and store by symbol
	for btn: Control in buttons_container.get_children():
		if not btn is ElementPickerButton:
			continue
		var element_data: ElementData = PeriodicTable.get_by_atomic_number(btn.element)
		var symbol: String = element_data.symbol.to_lower()
		_buttons[symbol] = btn

func disable_element(in_atomic_nmb: int) -> void:
	super.disable_element(in_atomic_nmb)
	if in_atomic_nmb == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
		_hydrogen_enabled = false

func enable_element(in_atomic_nmb: int) -> void:
	super.enable_element(in_atomic_nmb)
	if in_atomic_nmb == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
		_hydrogen_enabled = true

func _reset() -> void:
	_active_buttons.clear()
	for btn: ElementPickerButton in _buttons.values():
		if btn.can_render():
			btn.enable()
		else:
			btn.disable()
		btn.lowlight()


# Highlight the relevant atoms based on the search text input.
func _on_search_bar_text_changed(text: String) -> void:
	_reset()
	if not _hydrogen_enabled:
		disable_element(PeriodicTable.ATOMIC_NUMBER_HYDROGEN)
	text = text.to_lower()
	
	if text.is_empty():
		return
	
	# If the search exactly matches an atomic symbol, highlight the matching button.
	if _buttons.has(text) and not _buttons.get(text).disabled:
		var button: ElementPickerButton = _buttons.get(text)
		button.highlight()
		
		# If the atom can be placed (< 118), ignore every other atoms.
		if button.can_render():
			for btn: ElementPickerButton in _buttons.values():
				btn.disable()
			button.enable()
			_active_buttons.push_back(button)
			return

	# Highlight atoms if their name partially matches the search text.
	for btn: ElementPickerButton in _buttons.values():
		if text.is_subsequence_ofn(btn.name) and btn.can_render() and not btn.disabled:
			btn.highlight()
			_active_buttons.push_back(btn)
		else:
			btn.disable()


## When pressing enter and only one element matches the search text, select this element.
func _on_search_bar_text_submitted(_text: String) -> void:
	if _active_buttons.size() == 1:
		_on_button_pressed(_active_buttons[0].element)


func _on_about_to_popup() -> void:
	search_bar.clear()
	search_bar.grab_focus()
