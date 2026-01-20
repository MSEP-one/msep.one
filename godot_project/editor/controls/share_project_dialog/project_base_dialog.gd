extends NanoAcceptDialog


var _owner_option_button: OptionButton
var _name_line_edit: LineEdit
var _formated_name_label: Label
var _description_text_edit: TextEdit
var _tags_list_container: HFlowContainer
var _new_tag_line_edit: LineEdit
var _add_tag_button: Button
var _collaborators_list_container: HFlowContainer
var _collaborator_name_line_edit: LineEdit
var _collaborator_email_line_edit: LineEdit
var _add_collaborator_button: Button
var _project_versions_option_button: OptionButton
var _thumbnail_texture_rect: TextureRect

var _tag_labels: Dictionary[String, TagLabel]
var _collaborator_labels: Dictionary[String, CollaboratorLabel]


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_owner_option_button = %OwnerOptionButton as OptionButton
		_name_line_edit = %NameLineEdit as LineEdit
		_formated_name_label = %FormatedNameLabel as Label
		_description_text_edit = %DescriptionTextEdit as TextEdit
		_tags_list_container = %TagsListContainer as HFlowContainer
		_new_tag_line_edit = %NewTagLineEdit as LineEdit
		_add_tag_button = %AddTagButton as Button
		_collaborators_list_container = %CollaboratorsListContainer as HFlowContainer
		_collaborator_name_line_edit = %CollaboratorNameLineEdit as LineEdit
		_collaborator_email_line_edit = %CollaboratorEmailLineEdit as LineEdit
		_add_collaborator_button = %AddCollaboratorButton as Button
		_project_versions_option_button = %ProjectVersionsOptionButton as OptionButton
		_thumbnail_texture_rect = %ThumbnailTextureRect as TextureRect


func _ready() -> void:
	super._ready()
	about_to_popup.connect(_on_about_to_popup)
	
	_name_line_edit.text_changed.connect(_on_name_changed)
	_new_tag_line_edit.text_submitted.connect(_on_add_tag_button_pressed.unbind(1))
	_add_tag_button.pressed.connect(_on_add_tag_button_pressed)
	_collaborator_name_line_edit.text_submitted.connect(_collaborator_email_line_edit.grab_focus.unbind(1))
	_collaborator_email_line_edit.text_submitted.connect(_on_add_collaborator_button_pressed.unbind(1))
	_add_collaborator_button.pressed.connect(_on_add_collaborator_button_pressed)


func _on_about_to_popup() -> void:
	_update_owners_list()


func _update_owners_list() -> void:
	_owner_option_button.clear()
	_owner_option_button.text = MolecularEditorContext.authenticator.get_username()
	# TODO fill with list of namespaces with edit permisions


func _on_name_changed(new_name: String) -> void:
	var formated_name: String = "-".join(new_name.to_lower().split(" ", false))
	formated_name = formated_name.replace("_", "-")
	_formated_name_label.text = formated_name


func _on_add_tag_button_pressed() -> void:
	var tag_name: String = _new_tag_line_edit.text
	_new_tag_line_edit.text = String()
	if tag_name.is_empty() or _tag_labels.has(tag_name):
		return
	_tag_labels[tag_name] = TagLabel.create_tag(tag_name)
	_tag_labels[tag_name].erase_requested.connect(_on_erase_tag.bind(tag_name))
	_tags_list_container.add_child(_tag_labels[tag_name])


func _on_erase_tag(in_tag_name: String) -> void:
	_tag_labels[in_tag_name].queue_free()
	_tag_labels.erase(in_tag_name)


func _on_add_collaborator_button_pressed() -> void:
	var collaborator_name: String = _collaborator_name_line_edit.text
	var collaborator_email: String = _collaborator_email_line_edit.text
	var email_regex := RegEx.new()
	email_regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	if collaborator_name.is_empty():
		return
	var result: RegExMatch = email_regex.search(collaborator_email)
	var is_perfect_match: bool =  result.strings.size() == 1 and result.strings[0] == collaborator_email
	if not collaborator_email.is_empty() and not is_perfect_match:
		_collaborator_email_line_edit.grab_focus()
		DisplayServer.dialog_show("Invalid", "Not a valid email address", ["OK"], Callable())
		return
	_collaborator_name_line_edit.text = String()
	_collaborator_email_line_edit.text = String()
	var formatted: String = collaborator_name
	if not collaborator_email.is_empty():
		formatted += " <%s>" % collaborator_email
	
	_collaborator_labels[formatted] = CollaboratorLabel.create_collaborator(collaborator_name, collaborator_email)
	_collaborator_labels[formatted].erase_requested.connect(_on_erase_collaborator.bind(formatted))
	_collaborators_list_container.add_child(_collaborator_labels[formatted])


func _on_erase_collaborator(in_collab_name: String) -> void:
	_collaborator_labels[in_collab_name].queue_free()
	_collaborator_labels.erase(in_collab_name)

