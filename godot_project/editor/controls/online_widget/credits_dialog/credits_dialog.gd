class_name CreditsDialog extends AcceptDialog
## Responsible for listing the projects crediting the signed in user and letting them opt out of, or
## back into, that credit.


const CREDIT_ROW_SCENE: PackedScene = preload(
		"res://editor/controls/online_widget/credits_dialog/credit_row/credit_row.tscn")
const ISO_DATE_LENGTH: int = 10


@onready var _credited_list: VBoxContainer = %CreditedList
@onready var _credited_empty_label: Label = %CreditedEmptyLabel
@onready var _opted_out_list: VBoxContainer = %OptedOutList
@onready var _opted_out_empty_label: Label = %OptedOutEmptyLabel
@onready var _error_label: Label = %ErrorLabel


func open() -> void:
	popup_centered()
	_reload()


func _reload() -> void:
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	var credited_promise: Promise = msep_online.get_me_credited()
	var opted_out_promise: Promise = msep_online.get_me_opted_out()
	gui_disable_input = true
	await credited_promise.wait_for_fulfill()
	await opted_out_promise.wait_for_fulfill()
	gui_disable_input = false
	var credited_error: String = MsepOnline.get_response_error(credited_promise)
	var opted_out_error: String = MsepOnline.get_response_error(opted_out_promise)
	var credited_failed: bool = not credited_error.is_empty()
	var opted_out_failed: bool = not opted_out_error.is_empty()
	_show_error(credited_error if credited_failed else opted_out_error)
	var credited_projects: Array[Dictionary] = []
	if not credited_failed:
		credited_projects.assign(credited_promise.get_result().body.get("projects", []))
	var opted_out_projects: Array[Dictionary] = []
	if not opted_out_failed:
		opted_out_projects.assign(opted_out_promise.get_result().body.get("opted_out_projects", []))
	_fill_list(
		_credited_list, _credited_empty_label, credited_projects, credited_failed,
		_get_credited_detail, tr("Opt out"), _on_credited_row_action_pressed
	)
	_fill_list(
		_opted_out_list, _opted_out_empty_label, opted_out_projects, opted_out_failed,
		_get_opted_out_detail, tr("Undo"), _on_opted_out_row_action_pressed
	)


func _show_error(in_error: String) -> void:
	_error_label.text = in_error
	_error_label.visible = not in_error.is_empty()


func _fill_list(
		out_list: VBoxContainer,
		out_empty_label: Label,
		in_projects: Array[Dictionary],
		in_load_failed: bool,
		in_detail_getter: Callable,
		in_button_text: String,
		in_action_handler: Callable) -> void:
	for child: Node in out_list.get_children():
		child.queue_free()
	out_empty_label.visible = in_projects.is_empty() and not in_load_failed
	for project_data: Dictionary in in_projects:
		var detail: String = in_detail_getter.call(project_data)
		var row: CreditRow = CREDIT_ROW_SCENE.instantiate()
		out_list.add_child(row)
		row.set_project_data(project_data, detail, in_button_text)
		row.action_pressed.connect(in_action_handler)


func _get_credited_detail(in_project_data: Dictionary) -> String:
	return str(in_project_data.get("role", ""))


func _get_opted_out_detail(in_project_data: Dictionary) -> String:
	return str(in_project_data.get("opted_out_at", "")).left(ISO_DATE_LENGTH)


func _on_credited_row_action_pressed(in_project_namespace: String, in_project_name: String) -> void:
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	await _apply_and_reload(msep_online.post_namespace_project_optout(in_project_namespace, in_project_name))


func _apply_and_reload(in_promise: Promise) -> void:
	gui_disable_input = true
	await in_promise.wait_for_fulfill()
	gui_disable_input = false
	var error: String = MsepOnline.get_response_error(in_promise)
	await _reload()
	if not error.is_empty():
		_show_error(error)


func _on_opted_out_row_action_pressed(in_project_namespace: String, in_project_name: String) -> void:
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	await _apply_and_reload(msep_online.delete_namespace_project_optout(in_project_namespace, in_project_name))
