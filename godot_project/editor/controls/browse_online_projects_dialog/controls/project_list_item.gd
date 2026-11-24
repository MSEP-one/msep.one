extends VBoxContainer


signal import_button_pressed(project_data: Dictionary, version_uuid: String, version_number: int)
signal edit_button_pressed(project_data: Dictionary)


const _FALLBACK_THUMBNAIL: Texture2D = preload("uid://bpkx70rl1xv4t")
const _COPIED_FEEDBACK_SECONDS: float = 1.5


var _thumbnail_texture_rect: TextureRect
var _name_label: Label
var _owner_label: RichTextLabel
var _description_label: Label
var _tags_list_container: HFlowContainer
var _collaborators_list_container: HFlowContainer
var _project_versions_option_button: OptionButton
var _version_description_label: Label
var _see_more_button: RichTextLabel
var _import_button: Button
var _edit_button: Button
var _animation_player: AnimationPlayer
var _downloads_title_label: Label
var _downloads_label: Label
var _creator_title_label: Label
var _creator_label: Label
var _editors_title_label: Label
var _editors_label: Label
var _share_id_title_label: Label
var _copy_share_id_button: Button


var _project_data: Dictionary
var _showing_more: bool = false
var _tag_labels: Array[TagLabel]
var _collaborator_labels: Array[CollaboratorLabel]


func set_project_data(in_data: Dictionary) -> void:
	_project_data = in_data
	_project_data.make_read_only()
	
	# Name
	_name_label.text = _project_data.get("name", "")
	# Thumbnail
	var latest_version: Dictionary = _get_latest_version()
	var thumbnail_uuid: String = latest_version.get("uuid", "")
	if thumbnail_uuid.is_empty():
		_thumbnail_texture_rect.texture = _FALLBACK_THUMBNAIL
	else:
		_thumbnail_texture_rect.texture = DownloadableTexture.create_thumbnail(thumbnail_uuid, _FALLBACK_THUMBNAIL)
	# Owner
	var owner_data: Dictionary = _project_data.get("owner", {}) as Dictionary
	var proj_namespace: String = _project_data.get("namespace", "") as String
	_owner_label.clear()
	if owner_data.is_empty():
		_owner_label.append_text(proj_namespace)
	else:
		var profile_url: String = owner_data.get("profile_url", "")
		if profile_url.is_empty():
			_owner_label.append_text(owner_data.get("username", proj_namespace))
		else:
			_owner_label.push_meta(profile_url,RichTextLabel.META_UNDERLINE_ALWAYS, profile_url)
			_owner_label.append_text(owner_data.get("username", proj_namespace))
			_owner_label.pop_all()
	# Description
	_description_label.text = _project_data.get("description", "")
	# Downloads
	_update_download_count(_project_data.get("download_count"))
	# Tags
	_update_tags(_project_data.get("tags", []))
	# Collaborators
	_update_collaborators(_project_data.get("collaborators", []))
	# Creator and editors
	var editors: Array[Dictionary] = []
	editors.assign(_project_data.get("editors", []))
	_update_people(_project_data.get("creator", {}), editors)
	# Versions
	_update_versions()


## Returns the newest version of the project, which holds a uuid and a version_number,
## or an empty dictionary when the project has none.
func _get_latest_version() -> Dictionary:
	var version_info: Variant = _project_data.get("latest_version_info")
	var api_spec_version_info: Variant = _project_data.get("latest_version")
	if version_info is Dictionary:
		return version_info
	if api_spec_version_info is Dictionary:
		return api_spec_version_info
	return {}


func _update_download_count(in_download_count: Variant) -> void:
	var has_download_count: bool = in_download_count is int or in_download_count is float
	_downloads_title_label.visible = has_download_count
	_downloads_label.visible = has_download_count
	if has_download_count:
		_downloads_label.text = str(int(in_download_count))


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_thumbnail_texture_rect = %ThumbnailTextureRect as TextureRect
		_name_label = %NameLabel as Label
		_owner_label = %OwnerLabel as RichTextLabel
		_description_label = %DescriptionLabel as Label
		_tags_list_container = %TagsListContainer as HFlowContainer
		_collaborators_list_container = %CollaboratorsListContainer as HFlowContainer
		_project_versions_option_button = %ProjectVersionsOptionButton as OptionButton
		_version_description_label = %VersionDescriptionLabel as Label
		_see_more_button = %SeeMoreButton as RichTextLabel
		_import_button = %ImportButton as Button
		_edit_button = %EditButton as Button
		_animation_player = %AnimationPlayer as AnimationPlayer
		_downloads_title_label = %DownloadsTitleLabel as Label
		_downloads_label = %DownloadsLabel as Label
		_creator_title_label = %CreatorTitleLabel as Label
		_creator_label = %CreatorLabel as Label
		_editors_title_label = %EditorsTitleLabel as Label
		_editors_label = %EditorsLabel as Label
		_share_id_title_label = %ShareIdTitleLabel as Label
		_copy_share_id_button = %CopyShareIdButton as Button


func set_preferred_version(in_version_number: int) -> void:
	_project_versions_option_button.set_preferred_version(in_version_number)


func set_edit_button_visible(in_visible: bool) -> void:
	_edit_button.visible = in_visible


func notify_download_started() -> void:
	_import_button.disabled = true


func notify_download_ended() -> void:
	_on_project_versions_option_button_version_changed(_project_versions_option_button.get_selected_id())


func _ready() -> void:
	_owner_label.meta_clicked.connect(_on_url_button_pressed)
	_see_more_button.meta_clicked.connect(_on_see_more_button_pressed.unbind(1))
	_project_versions_option_button.versions_updated.connect(_update_versions_visibility)
	_project_versions_option_button.version_changed.connect(_on_project_versions_option_button_version_changed)
	_import_button.pressed.connect(_on_import_button_pressed)
	_update_separator.call_deferred()


func _update_tags(tags: Array) -> void:
	for label: TagLabel in _tag_labels:
		label.queue_free()
	_tag_labels = []
	for tag: String in tags:
		const SHOULD_SHOW_ERASE_BUTTON = false
		var label := TagLabel.create_tag(tag, SHOULD_SHOW_ERASE_BUTTON)
		_tags_list_container.add_child(label)
		_tag_labels.append(label)
	_update_tags_visibility()


func _update_tags_visibility() -> void:
	if _tag_labels.size() == 0:
		_tags_list_container.hide()
		%TagsTitleLabel.hide()
	else:
		_tags_list_container.show()
		%TagsTitleLabel.show()


func _update_collaborators(collaborators: Array) -> void:
	for label: CollaboratorLabel in _collaborator_labels:
		label.queue_free()
	_collaborator_labels = []
	for collaborator: Dictionary in collaborators:
		const SHOULD_SHOW_ERASE_BUTTON = false
		var label := CollaboratorLabel.create_collaborator(
			collaborator.get("name", ""),
			collaborator.get("email", ""),
			SHOULD_SHOW_ERASE_BUTTON)
		_collaborators_list_container.add_child(label)
		_collaborator_labels.append(label)
	_update_collaborators_visibility()


func _update_collaborators_visibility() -> void:
	if _collaborator_labels.size() == 0 or _showing_more == false:
		_collaborators_list_container.hide()
		%CollaboratorsTitleLabel.hide()
	else:
		_collaborators_list_container.show()
		%CollaboratorsTitleLabel.show()


func _update_people(in_creator: Dictionary, in_editors: Array[Dictionary]) -> void:
	var editor_names: PackedStringArray = []
	for editor_data: Dictionary in in_editors:
		editor_names.append(editor_data.get("username", ""))
	_creator_label.text = in_creator.get("username", "")
	_editors_label.text = ", ".join(editor_names)
	_update_people_visibility()


func _update_people_visibility() -> void:
	var show_creator: bool = _showing_more and not _creator_label.text.is_empty()
	var show_editors: bool = _showing_more and not _editors_label.text.is_empty()
	_creator_title_label.visible = show_creator
	_creator_label.visible = show_creator
	_editors_title_label.visible = show_editors
	_editors_label.visible = show_editors


func _update_version_link_visibility() -> void:
	var has_version_uuid: bool = not _get_selected_version_uuid().is_empty()
	var show_link: bool = _showing_more and has_version_uuid
	_share_id_title_label.visible = show_link
	_copy_share_id_button.visible = show_link


func _get_selected_version_uuid() -> String:
	var version_number: int = _project_versions_option_button.get_selected_id()
	var has_selected_version: bool = version_number != -1
	if not has_selected_version:
		return ""
	return _project_versions_option_button.get_version_data(version_number).get("uuid", "")


func _update_versions() -> void:
	_import_button.disabled = true
	_project_versions_option_button.set_project_data(_project_data)
	_update_versions_visibility()


func _update_versions_visibility() -> void:
	_update_version_link_visibility()
	var nothing_selected: bool = _project_versions_option_button.get_selected_id() == -1
	if _project_versions_option_button.item_count == 0 or _showing_more == false or nothing_selected:
		_project_versions_option_button.hide()
		%ProjectVersionsTitleLabel.hide()
		_version_description_label.hide()
		%VersionDescriptionTitleLabel.hide()
	else:
		_project_versions_option_button.show()
		%ProjectVersionsTitleLabel.show()
		_version_description_label.visible = not _version_description_label.text.is_empty()
		%VersionDescriptionTitleLabel.visible = _version_description_label.visible


func _on_project_versions_option_button_version_changed(in_version_number: int) -> void:
	if in_version_number != -1:
		var data: Dictionary = _project_versions_option_button.get_version_data(in_version_number)
		_import_button.disabled = data.get("is_retracted", false)
		_version_description_label.text = data.get("description", "")
	else:
		_import_button.disabled = true
	_update_versions_visibility()


func _on_import_button_pressed() -> void:
	var version_number: int = _project_versions_option_button.get_selected_id()
	var version_data: Dictionary = _project_versions_option_button.get_version_data(version_number)
	var version_uuid: String = version_data.get("uuid", "")
	import_button_pressed.emit(_project_data, version_uuid, version_number)


func _on_copy_share_id_button_pressed() -> void:
	var version_uuid: String = _get_selected_version_uuid()
	DisplayServer.clipboard_set(version_uuid)
	var original_text: String = _copy_share_id_button.text
	_copy_share_id_button.text = tr("Copied!")
	await get_tree().create_timer(_COPIED_FEEDBACK_SECONDS).timeout
	_copy_share_id_button.text = original_text


func _on_edit_button_pressed() -> void:
	edit_button_pressed.emit(_project_data)


func _update_separator() -> void:
	var index: int = get_index()
	var sibling_count: int = get_parent().get_child_count()
	# Last item hides the separator
	$HSeparator.visible = index < sibling_count - 1


func _on_url_button_pressed(meta: Variant) -> void:
	assert(typeof(meta) == TYPE_STRING)
	var url: String = meta as String
	assert(url.begins_with("https://") or (OS.has_feature("editor") and url.begins_with("http://")),
		"Invalid url: " + url)
	OS.shell_open(url)


func _on_see_more_button_pressed() -> void:
	_showing_more = !_showing_more
	if _showing_more:
		_animation_player.play(&"see_more")
		_animation_player.seek(0, true)
		_animation_player.stop()
		_update_collaborators_visibility()
		_update_versions_visibility()
	else:
		_animation_player.play(&"see_less")
		_animation_player.seek(0, true)
		_animation_player.stop()
	_update_people_visibility()
	_update_version_link_visibility()

