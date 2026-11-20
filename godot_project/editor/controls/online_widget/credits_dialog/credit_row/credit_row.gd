class_name CreditRow extends HBoxContainer


signal action_pressed(project_namespace: String, project_name: String)


@onready var _project_label: Label = %ProjectLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _action_button: Button = %ActionButton

var _project_namespace: String = ""
var _project_name: String = ""


func set_project_data(in_project_data: Dictionary, in_detail: String, in_button_text: String) -> void:
	_project_namespace = in_project_data.get("namespace", "")
	_project_name = in_project_data.get("name", "")
	_project_label.text = "%s/%s" % [_project_namespace, _project_name]
	_project_label.tooltip_text = in_project_data.get("description", "")
	_detail_label.text = in_detail
	_action_button.text = in_button_text


func _on_action_button_pressed() -> void:
	action_pressed.emit(_project_namespace, _project_name)
