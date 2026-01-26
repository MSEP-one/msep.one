class_name EditProjectDialog
extends "project_base_dialog.gd"


const _FALLBACK_THUMBNAIL: Texture2D = preload("uid://bpkx70rl1xv4t")


var _confirm_retract_dialog: NanoAcceptDialog
var _retract_reason_text_edit: TextEdit


var _project_data: Dictionary
var loaded_version: int = -1


func _ready() -> void:
	super._ready()
	_project_versions_option_button.version_changed.connect(_on_project_versions_option_button_version_changed)
	_retract_version_button.pressed.connect(_on_retract_version_button_pressed)
	_confirm_retract_dialog.closed.connect(_on_confirm_retract_dialog_closed)
	_retract_reason_text_edit.text_changed.connect(_on_retract_reason_text_edit_text_changed)
	
	get_ok_button().pressed.connect(_on_ok_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_confirm_retract_dialog = %ConfirmRetractDialog as NanoAcceptDialog
		_retract_reason_text_edit = %RetractReasonTextEdit as TextEdit
		_confirm_retract_dialog.hide()



func set_project_data(in_data: Dictionary, tags_promise: Promise, collabs_promise: Promise) -> void:
	assert(not in_data.is_empty())
	_project_data = in_data
	_project_versions_option_button.set_project_data(in_data)
	if visible:
		# Update UI
		_on_about_to_popup()
	_description_text_edit.text = _project_data.get("description", "")
	_update_tags(tags_promise)
	_update_collaborators(collabs_promise)


func _update_tags(in_promise: Promise) -> void:
	await in_promise.wait_for_fulfill()
	if in_promise.has_error():
		# Failed to fetch tags. What should the system do in this case?
		return
	for child: Node in _tags_list_container.get_children():
		if child is TagLabel:
			child.queue_free()
	_tag_labels = {}
	var data: Dictionary = in_promise.get_result().body
	assert(data.has("tags"))
	if data.tags.is_empty():
		return
	for tag: String in data.tags:
		const SHOULD_SHOW_ERASE_BUTTON = true
		var tag_label := TagLabel.create_tag(tag, SHOULD_SHOW_ERASE_BUTTON)
		_tag_labels[tag] = tag_label
		_tags_list_container.add_child(tag_label)
		_tag_labels[tag].erase_requested.connect(_on_erase_tag.bind(tag))
	_tags_changed = false


func _update_collaborators(in_promise: Promise) -> void:
	await in_promise.wait_for_fulfill()
	if in_promise.has_error():
		# Failed to fetch collaborators. What should the system do in this case?
		return
	for child: Node in _collaborators_list_container.get_children():
		if child is CollaboratorLabel:
			child.queue_free()
	_collaborator_labels = {}
	var data: Dictionary = in_promise.get_result().body
	assert(data.has("collaborators"))
	if data.collaborators.is_empty():
		return
	for collaborator: Dictionary in data.collaborators:
		const SHOULD_SHOW_ERASE_BUTTON = true
		var collaborator_label := CollaboratorLabel.create_collaborator(
			collaborator.name, collaborator.email, SHOULD_SHOW_ERASE_BUTTON
		)
		var formatted: String = collaborator.name
		if not collaborator.email.is_empty():
			formatted += " <%s>" % collaborator.email
		_collaborator_labels[formatted] = collaborator_label
		_collaborators_list_container.add_child(collaborator_label)
		_collaborator_labels[formatted].erase_requested.connect(_on_erase_collaborator.bind(formatted))
	_collaborators_changed = false


# OVERRIDE
func _update_owners_list() -> void:
	# TODO delete when we have a way to fill with list of namespaces with edit permisions
	_owner_option_button.clear()
	var owners: Dictionary[String, bool] = {}
	owners[MolecularEditorContext.authenticator.get_username()] = true
	var project_namespace: String = _project_data.get("namespace", "")
	if not project_namespace.is_empty():
		owners[project_namespace] = true
	_owner_option_button.clear()
	for own: String in owners.keys():
		_owner_option_button.add_item(own)
		if own == project_namespace:
			_owner_option_button.select(_owner_option_button.item_count - 1)


func _on_project_versions_option_button_version_changed(version_number: int) -> void:
	if loaded_version != -1 and version_number != -1 and version_number != loaded_version:
		if _version_data_changed():
			var ctx: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
			var promise: Promise = ctx.show_warning_dialog(
				tr(&"Changes done to this version will be lost."),
				tr(&"Proceed"), tr(&"Cancel")
			)
			await promise.wait_for_fulfill()
			if promise.get_result() == false:
				# Cancelled
				_project_versions_option_button.select(
					_project_versions_option_button.get_item_index(loaded_version)
				)
				return
	loaded_version = version_number
	if version_number == -1:
		_clear_version_ui()
		return
	var data: Dictionary = _project_versions_option_button.get_version_data(version_number)
	var is_retracted: bool = data.get("is_retracted", false)
	_retracted_info_label.visible = is_retracted
	if is_retracted:
		_retracted_info_label.message = tr(&"This version has been retracted.")
		var reason: String = data.get("retraction_reason") as String
		if not reason.is_empty():
			_retracted_info_label.message += "\n" + tr(&"Reason: ") + '"%s"' % reason.strip_edges()
	_version_description_text_edit.editable = not is_retracted
	_retract_version_button.disabled = is_retracted
	_version_description_text_edit.text = str(data.get("description", ""))
	var thumbnail_url: String = str(data.get("thumbnail", ""))
	if thumbnail_url.is_empty():
		var thumbnail_size := Vector2i(_FALLBACK_THUMBNAIL.get_size())
		_thumbnail_texture_rect.texture = DownloadableTexture.get_loading_texture(thumbnail_size)
	_thumbnail_texture_rect.texture = DownloadableTexture.create(thumbnail_url, _FALLBACK_THUMBNAIL)


func _clear_version_ui() -> void:
	var thumbnail_size := Vector2i(_FALLBACK_THUMBNAIL.get_size())
	_thumbnail_texture_rect.texture = DownloadableTexture.get_loading_texture(thumbnail_size)
	_retracted_info_label.visible = false
	_version_description_text_edit.editable = false
	_retract_version_button.disabled = true
	_version_description_text_edit.text = String()


func _version_data_changed() -> bool:
	var data: Dictionary = _project_versions_option_button.get_version_data(loaded_version)
	var changed: bool = _version_description_text_edit.text != data.get("description", "")
	return changed


func _on_retract_version_button_pressed() -> void:
	_retract_reason_text_edit.text = ""
	_on_retract_reason_text_edit_text_changed()
	_confirm_retract_dialog.popup_centered()


func _on_retract_reason_text_edit_text_changed() -> void:
	const REASON_IS_OPTIONAL = true
	if REASON_IS_OPTIONAL:
		_confirm_retract_dialog.get_ok_button().disabled = false
	else:
		_confirm_retract_dialog.get_ok_button().disabled = _retract_reason_text_edit.text.is_empty()


func _on_confirm_retract_dialog_closed(in_confirmed: bool) -> void:
	if in_confirmed == false:
		return
	# GdScript messes up the inheritance chain, so we need this to call get_cancel_button
	var dialog: Variant = self
	var ok_button: Button = dialog.get_ok_button()
	var cancel_button: Button = dialog.get_cancel_button()
	gui_disable_input = true
	ok_button.disabled = true
	cancel_button.disabled = true
	var version_number: int = _project_versions_option_button.get_selected_id()
	_clear_version_ui()
	var reason: String = _retract_reason_text_edit.text
	await _project_versions_option_button.retract_selected_version(reason)
	_on_project_versions_option_button_version_changed(version_number)
	ok_button.disabled = false
	cancel_button.disabled = false
	gui_disable_input = false


func _on_ok_pressed() -> void:
	var dialog: Variant = self
	var ok_button: Button = get_ok_button()
	var cancel_button: Button = dialog.get_cancel_button() as Button
	ok_button.disabled = true
	cancel_button.disabled = true
	
	gui_disable_input = true
	var promises: Array[Promise]
	
	var project_changed: bool = false
	var new_owner := OptionalString.empty()
	var new_description := OptionalString.empty()
	var new_tags := OptionalPackedStringArray.empty()
	var new_collaborators := OptionalArrayOfDictionaries.empty()
	
	if not _owner_option_button.text.is_empty() and _owner_option_button.text != _project_data.namespace:
		project_changed = true
		new_owner = OptionalString.new(_owner_option_button.text)
	
	if _description_text_edit.text != _project_data.description:
		project_changed = true
		new_description = OptionalString.new(_description_text_edit.text)
	
	if _tags_changed:
		project_changed = true
		var tags: PackedStringArray = []
		for tag_label: TagLabel in _tag_labels.values():
			tags.append(tag_label.text)
		new_tags = OptionalPackedStringArray.new(tags)
	if _collaborators_changed:
		project_changed = true
		var collaborators: Array[Dictionary] = []
		for collaborator_label: CollaboratorLabel in _collaborator_labels.values():
			collaborators.append({
				"name" : collaborator_label.collaborator_name,
				"email" : collaborator_label.email,
			})
		new_collaborators = OptionalArrayOfDictionaries.new(collaborators)
	
	if _version_data_changed():
		promises.append(
			MolecularEditorContext.msep_online_service.put_namespace_project_version(
				_project_data.namespace, _project_data.name, loaded_version, _version_description_text_edit.text
			)
		)
	if project_changed:
		promises.append(
			MolecularEditorContext.msep_online_service.put_namespace_project(
				_project_data.namespace, _project_data.name,
				new_description,
				new_collaborators,
				new_tags,
				new_owner
			)
		)
	
	var has_error: bool = false
	var errors: PackedStringArray
	for p: Promise in promises:
		await p.wait_for_fulfill()
		if p.has_error():
			has_error = true
			errors.append(p.get_error())

	ok_button.disabled = false
	cancel_button.disabled = false
	gui_disable_input = false
	if has_error:
		MolecularEditorContext.get_current_workspace_context().show_warning_dialog(
			"\n\n".join(errors), tr(&"OK")
		)
	else:
		hide()
