class_name CreateProjectDialog
extends "project_base_dialog.gd"


signal finished(project_namespace: String, project_name: String)


func _ready() -> void:
	super._ready()
	
	get_ok_button().pressed.connect(_on_ok_pressed)


func _on_closed(in_pressed_ok: bool) -> void:
	if not in_pressed_ok:
		finished.emit("", "")


func _on_about_to_popup() -> void:
	super._on_about_to_popup()
	
	var workspace: Workspace = MolecularEditorContext.get_current_workspace()
	_name_line_edit.text = workspace.get_user_friendly_name().get_file().get_basename()
	_on_name_changed(_name_line_edit.text)
	_description_text_edit.text = workspace.description


func _on_ok_pressed() -> void:
	var dialog: Variant = self
	var ok_button: Button = get_ok_button()
	var cancel_button: Button = dialog.get_cancel_button() as Button
	ok_button.disabled = true
	cancel_button.disabled = true
	
	gui_disable_input = true
	var collaborators: Array[Dictionary] = []
	for collaborator_label: CollaboratorLabel in _collaborator_labels.values():
		collaborators.append({
			"name" : collaborator_label.collaborator_name,
			"email" : collaborator_label.email,
		})
	var tags: PackedStringArray = []
	for tag_label: TagLabel in _tag_labels.values():
		tags.append(tag_label.text)
	var project_namespace: String = _owner_option_button.text
	var project_name: String = _formated_name_label.text
	var promise: Promise = MolecularEditorContext.msep_online.post_namespace_projects(
		project_namespace,
		project_name,
		_description_text_edit.text,
		collaborators,
		tags
	)
	await promise.wait_for_fulfill()
	ok_button.disabled = false
	cancel_button.disabled = false
	gui_disable_input = false
	var error: String = MsepOnline.get_response_error(promise)
	var create_failed: bool = not error.is_empty()
	if create_failed:
		MolecularEditorContext.get_current_workspace_context().show_warning_dialog(
			error, tr(&"OK")
		)
	else:
		hide()
		finished.emit(project_namespace, project_name)
