extends PopupMenu

signal action_copy
signal action_cut
signal action_paste
signal action_delete

func _ready() -> void:
	id_pressed.connect(_on_id_pressed)
	pass # Replace with function body.

func _on_id_pressed(id: int) -> void:
	match id:
		ACTIONS.COPY:
			action_copy.emit()
		ACTIONS.CUT:
			action_cut.emit()
		ACTIONS.PASTE:
			action_paste.emit()
		ACTIONS.DELETE:
			action_delete.emit()
		_:
			printerr("[PopupObjectTreeView:_on_id_pressed] Action with id %d is not valid" % [id])

# keep this enum synced with the item IDs in the popup menu
enum ACTIONS {
	COPY,
	CUT,
	PASTE,
	SEPARATOR,
	DELETE
}
