extends VBoxContainer


var nano_structure: WeakRef = weakref(null): # NanoStructure
	set(v):
		if nano_structure != v or nano_structure.get_ref() != v.get_ref():
			nano_structure = v
			_update()


@onready var _activate_structure_button: Button = %ActivateStructureButton
@onready var _structure_name: Label = %StructureName

signal structure_activated(in_nano_structure: NanoStructure)


func _ready() -> void:
	_activate_structure_button.pressed.connect(_on_activate_structure_button_pressed)


func _update() -> void:
	if !nano_structure.get_ref():
		_structure_name.text = ""
		_activate_structure_button.icon = null
	else:
		_structure_name.text = nano_structure.get_ref().get_structure_name()
		_activate_structure_button.icon = Editor_Utils.get_structure_thumbnail(nano_structure.get_ref())


func _on_activate_structure_button_pressed() -> void:
	if nano_structure.get_ref():
		structure_activated.emit(nano_structure.get_ref())
