class_name DeviceCodeDialog extends AcceptDialog


@onready var _uri_label: Label = %UriLabel
@onready var _code_label: Label = %CodeLabel


func show_code(in_user_code: String, in_verification_uri: String) -> void:
	_uri_label.text = in_verification_uri
	_code_label.text = in_user_code
	reset_size()
	popup_centered()


func _on_copy_url_button_pressed() -> void:
	DisplayServer.clipboard_set(_uri_label.text)


func _on_copy_code_button_pressed() -> void:
	DisplayServer.clipboard_set(_code_label.text)
