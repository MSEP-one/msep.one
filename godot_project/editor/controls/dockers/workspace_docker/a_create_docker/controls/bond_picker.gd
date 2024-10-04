extends Control


@onready var button_single: Button = %ButtonSingle
@onready var button_double: Button = %ButtonDouble
@onready var button_triple: Button = %ButtonTriple
@onready var button_group: ButtonGroup = button_single.button_group
@onready var _button_order_map: Dictionary = {
	#[Button, int]
	button_single: 1,
	button_double: 2,
	button_triple: 3
}

signal bond_order_change_requested(in_order: int)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		button_single = %ButtonSingle
		button_double = %ButtonDouble
		button_triple = %ButtonTriple
		button_group = button_single.button_group


func set_bond_order(in_order: int) -> void:
	assert(button_group != null)
	var button: Button = _button_order_map.find_key(in_order)
	assert(button)
	if !button.button_pressed:
		button.button_pressed = true


func _ready() -> void:
	button_group.pressed.connect(_on_button_group_pressed)
	for button in button_group.get_buttons():
		button.toggled.connect(_on_button_toggled_deferred.bind(button), CONNECT_DEFERRED)


func _on_button_group_pressed(in_button: BaseButton) -> void:
	assert(in_button != null and _button_order_map.has(in_button),
			"The pressed Button is not registered on the map, and desired bond order is Unknown!")
	bond_order_change_requested.emit(_button_order_map[in_button])


func _on_button_toggled_deferred(in_button_pressed: bool, in_button: Button) -> void:
	if in_button_pressed == false and button_group.get_pressed_button() == null:
		# Button was set to unpressed by shortcut when it was already pressed
		#+This hack prevents that behavior
		in_button.button_pressed = true
