extends Control

@export var button: Button
@export var invert_pressed: bool = false

func _ready() -> void:
	assert(button != null)
	assert(button.toggle_mode == true, "Button is not toggle_mode")
	button.toggled.connect(_on_button_toggled)
	_on_button_toggled(button.button_pressed)
	const EditDnaPanel: Script = preload("uid://cdcgvv0jwwf6c")
	if owner is EditDnaPanel:
		owner.tracked_object_changed.connect(_on_tracked_object_changed)


func _on_button_toggled(in_button_pressed: bool) -> void:
	if invert_pressed:
		in_button_pressed = not in_button_pressed
	visible = in_button_pressed

func _on_tracked_object_changed(in_object: DnaStructure) -> void:
	if in_object == null:
		return
	# Update visibility
	_on_button_toggled(button.button_pressed)
