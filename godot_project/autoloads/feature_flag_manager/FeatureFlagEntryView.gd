extends HBoxContainer

## View class for a feature flag entry
## It has two simple responsibilities:
## 1 - Be a view to represent the state of the respective feature flag on the FeatureFlagManager
## 2 - Report to the Feature Flag Manager when its button is toggled   
class_name FeatureFlagEntryView

signal value_toggled(new_value: bool)

@onready var check_button: CheckButton =  %CheckButton

func _ready() -> void:
	check_button.toggled.connect(_on_button_toggled)
	pass

## Should be called for initializing the view.
## in_name: Readable feature flag name
## value: starting value of the feature flag  
func setup(in_name: String, value: bool) -> void:
	if not check_button:
		await ready
	check_button.text = in_name
	check_button.button_pressed = value

func get_current_toggle() -> bool:
	if not check_button:
		return false
	return check_button.button_pressed

func _on_button_toggled(new_value: bool) -> void:
	value_toggled.emit(new_value)
