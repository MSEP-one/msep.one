extends ConfirmationDialog

signal closed(is_accepted: bool)


func _on_confirmed() -> void:
	closed.emit(true)


func _on_canceled() -> void:
	closed.emit(false)
