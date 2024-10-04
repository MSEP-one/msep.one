class_name VirtualAnchorPreview extends VirtualAnchorModel


func _init() -> void:
	hide()


func _notification(what: int) -> void:
	super._notification(what)


func set_preview_position(in_position: Vector3) -> void:
	global_position = in_position
