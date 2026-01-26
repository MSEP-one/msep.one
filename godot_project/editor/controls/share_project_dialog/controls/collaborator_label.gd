class_name CollaboratorLabel
extends TagLabel

var collaborator_name: String:
	set = _set_collaborator_name
var email: String:
	set = _set_email


static func create_collaborator(in_name: String, in_email: String, show_erase_button: bool = true) -> TagLabel:
	var label: CollaboratorLabel = load("uid://cci1smteq0sjk").instantiate()
	label.collaborator_name = in_name
	label.email = in_email
	label.erase_button_visible = show_erase_button
	return label


func _set_collaborator_name(in_name: String) -> void:
	collaborator_name = in_name
	_update_text()


func _set_email(in_email: String) -> void:
	email = in_email
	_update_text()


func _update_text() -> void:
	if email.is_empty():
		text = collaborator_name
	else:
		text = "%s <%s>" % [collaborator_name, email]
