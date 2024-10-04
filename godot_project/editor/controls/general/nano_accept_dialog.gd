class_name NanoAcceptDialog
extends AcceptDialog

## Like a regular AcceptDialog, but with an extra 'closed' signal emitted when
## the dialog is closed, be it from the OK button or because the user pressed Escape


signal closed(pressed_ok: bool)


func _init() -> void:
	EditorSfx.register_window(self, true)


func _ready() -> void:
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)


func _on_confirmed() -> void:
	closed.emit(true)


func _on_canceled() -> void:
	closed.emit(false)
