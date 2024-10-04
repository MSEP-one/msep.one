class_name ElementPickerBase
extends Node

## Base class for atomic element picker. Handles the basic logic when selecting
## an element.

signal atom_type_change_requested(in_element: int)


@onready var buttons_container: GridContainer = %ButtonsContainer


func _ready() -> void:
	for b in buttons_container.get_children():
		if b is ElementPickerButton:
			b.pressed.connect(_on_button_pressed.bind(b.element))


func disable_element(in_atomic_nmb: int) -> void:
	for btn in buttons_container.get_children():
		if not btn is ElementPickerButton:
			continue
		if btn.element == in_atomic_nmb:
			btn.disable()


func enable_element(in_atomic_nmb: int) -> void:
	for btn in buttons_container.get_children():
		if not btn is ElementPickerButton:
			continue
		if btn.element == in_atomic_nmb:
			btn.enable()


func _on_button_pressed(in_element: int) -> void:
	atom_type_change_requested.emit(in_element)
