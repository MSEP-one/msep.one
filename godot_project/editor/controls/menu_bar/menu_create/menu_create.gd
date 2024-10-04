extends NanoPopupMenu

@onready var atoms: PopupMenu = $Atoms
@onready var shapes: PopupMenu = $Shapes



func _ready() -> void:
	super()
	add_submenu_item("Atoms", atoms.name)
	add_submenu_item("Shapes", shapes.name)

func _update_menu() -> void:
	pass

func _on_id_pressed(_in_id: int) -> void:
	pass
