class_name CreateProjectDialog
extends "project_base_dialog.gd"


func _ready() -> void:
	super._ready()
	
	get_ok_button().pressed.connect(_on_ok_pressed)


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
	var promise: Promise = MolecularEditorContext.msep_online_service.post_namespace_projects(
		_owner_option_button.text,
		_formated_name_label.text,
		_description_text_edit.text,
		collaborators,
		tags
	)
	await promise.wait_for_fulfill()
	ok_button.disabled = false
	cancel_button.disabled = false
	gui_disable_input = false
	if promise.has_error():
		MolecularEditorContext.get_current_workspace_context().show_warning_dialog(
			promise.get_error(), tr(&"OK")
		)
	else:
		hide()
