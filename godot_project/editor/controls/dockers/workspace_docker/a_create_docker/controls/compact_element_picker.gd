class_name CompactElementPicker
extends ElementPickerBase

## Compact view of the atomic element picker.
## Displays a "More types" button that opens the extended element picker popup.
## The extended element picker is instantiated on demand the first time "More Types" is clicked

@onready var _extended_element_picker_placeholder: InstancePlaceholder = %ExtendedElementPicker
@onready var _more_types_button: Button = $MoreTypesButton
var _extended_element_picker: PopupPanel = null
var _disable_queue: Dictionary = {
#	element<int> = disabled<true>
}


func _ready() -> void:
	super._ready()
	_more_types_button.pressed.connect(_on_more_types_button_pressed)

func _on_more_types_button_pressed() -> void:
	if not is_instance_valid(_extended_element_picker):
		_extended_element_picker = _extended_element_picker_placeholder.create_instance(true)
		_extended_element_picker.atom_type_change_requested.connect(_on_extended_element_picker_atom_type_change_requested)
		for atomic_number: int in _disable_queue.keys():
			if _disable_queue[atomic_number]:
				_extended_element_picker.disable_element(atomic_number)
			else:
				_extended_element_picker.enable_element(atomic_number)
	_extended_element_picker.popup_centered()
	EditorSfx.mouse_down()


func disable_element(in_atomic_nmb: int) -> void:
	super.disable_element(in_atomic_nmb)
	if is_instance_valid(_extended_element_picker):
		_extended_element_picker.disable_element(in_atomic_nmb)
	else:
		_disable_queue[in_atomic_nmb] = true


func enable_element(in_atomic_nmb: int) -> void:
	super.enable_element(in_atomic_nmb)
	if is_instance_valid(_extended_element_picker):
		_extended_element_picker.enable_element(in_atomic_nmb)
	else:
		_disable_queue.erase(in_atomic_nmb)


func _on_extended_element_picker_atom_type_change_requested(in_element: int) -> void:
	atom_type_change_requested.emit(in_element)
	_extended_element_picker.hide()
