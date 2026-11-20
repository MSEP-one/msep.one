class_name BrowseOnlineProjectsDialog extends NanoAcceptDialog

enum State {
	SEARCHING,
	ERROR,
	SHOW_RESULT,
}


@onready var _search_container: HBoxContainer = %SearchContainer
@onready var _tags_container: HBoxContainer = %TagsContainer
@onready var _search_line_edit: LineEdit = %SearchLineEdit
@onready var _sort_menu_button: MenuButton = %SortMenuButton
@onready var _tags_menu_button: MenuButton = %TagsMenuButton
@onready var _filter_tags_container: HFlowContainer = %FilterTagsContainer
@onready var _loading_indicator: Control = %LoadingIndicator
@onready var _error_info_label: InfoLabel = %ErrorInfoLabel
@onready var _project_list_container: VBoxContainer = %ProjectListContainer
@onready var _pagination_label: RichTextLabel = %PaginationLabel
@onready var _download_progress_bar: ProgressBar = %DownloadProgressBar
@onready var _share_button: Button = %ShareButton
@onready var _link_resolver: OnlineProjectLinkResolver = %OnlineProjectLinkResolver


var _search_promise: Promise
var _sort_type := MsepOnline.SortType.TRENDING
var _selected_tags: Dictionary[String, TagLabel]
var _download_promise: DownloadPromise
var _my_projects_requested: bool = false

var _last_search: Dictionary = {
	search_text = "",
	sort_type = MsepOnline.SortType.TRENDING,
	tags = PackedStringArray(),
	page = 1,
}


func _init() -> void:
	about_to_popup.connect(_on_about_to_popup)


func _ready() -> void:
	_search_line_edit.text_submitted.connect(_on_search_line_edit_text_submitted)
	_sort_menu_button.get_popup().id_pressed.connect(_on_sort_menu_button_id_pressed)
	_tags_menu_button.get_popup().index_pressed.connect(_on_tags_menu_button_index_pressed)
	_pagination_label.meta_clicked.connect(_on_pagination_label_meta_clicked)


func _process(_delta: float) -> void:
	if _download_promise == null:
		_download_progress_bar.hide()
	else:
		_download_progress_bar.show()
		var progress: Vector2i = _download_promise.get_progress()
		_download_progress_bar.indeterminate = progress.y == -1
		if progress.y != -1:
			_download_progress_bar.max_value = progress.y
			_download_progress_bar.value = progress.x


func open_my_projects() -> void:
	_my_projects_requested = true
	popup_centered_ratio(0.85)


func _on_about_to_popup() -> void:
	_share_button.visible = MolecularEditorContext.msep_online.is_authenticated()
	var is_my_projects_request: bool = _my_projects_requested
	_my_projects_requested = false
	_search_container.visible = not is_my_projects_request
	_tags_container.visible = not is_my_projects_request
	if is_my_projects_request:
		title = tr("My MSEP Online Projects")
		_load_my_projects()
		return
	title = tr("Browse MSEP Online Projects")
	_update_tags_menu()
	_search_line_edit.text = ""
	_search_line_edit.grab_focus.call_deferred()
	_search("", PackedStringArray(), _sort_type, 1)


func _on_share_button_pressed() -> void:
	hide()
	WorkspaceUtils.share_project(MolecularEditorContext.get_current_workspace_context())


func _load_my_projects() -> void:
	var promise: Promise = MolecularEditorContext.msep_online.get_me_editable()
	_search_promise = promise
	_link_resolver.cancel()
	_set_state(State.SEARCHING)
	await promise.wait_for_fulfill()
	var is_superseded: bool = _search_promise != promise
	if is_superseded:
		return
	var error: String = MsepOnline.get_response_error(promise)
	var load_failed: bool = not error.is_empty()
	if load_failed:
		_set_state(State.ERROR)
		_error_info_label.message = error
		return
	var projects: Array[Dictionary] = []
	projects.assign(promise.get_result().body.get("projects", []))
	if projects.is_empty():
		_set_state(State.ERROR)
		_error_info_label.message = tr("You have no projects yet.")
		return
	_set_state(State.SHOW_RESULT)
	_pagination_label.hide()
	_update_project_list(projects, true)


func _set_state(in_state: State) -> void:
	_loading_indicator.visible = in_state == State.SEARCHING
	_error_info_label.visible = in_state == State.ERROR
	_project_list_container.visible = in_state == State.SHOW_RESULT
	_pagination_label.visible = in_state == State.SHOW_RESULT


func _update_tags_menu() -> void:
	_tags_menu_button.show()
	_filter_tags_container.show()
	_tags_menu_button.get_popup().clear()
	for child: Node in _filter_tags_container.get_children():
		child.queue_free()
	_selected_tags.clear()
	var promise: Promise = MolecularEditorContext.msep_online.get_explore_tags()
	await promise.wait_for_fulfill()
	if promise.has_error():
		var err_label := Label.new()
		err_label.text = promise.get_error()
		_filter_tags_container.add_child(err_label)
		return
	var tags_data: Array = promise.get_result().body.get("tags", [])
	if tags_data.is_empty():
		_tags_menu_button.hide()
		_filter_tags_container.hide()
		return
	for tag_data: Dictionary in tags_data:
		_tags_menu_button.get_popup().add_check_item(tag_data.get("name", "<>"))
		_tags_menu_button.get_popup().set_item_tooltip(
			_tags_menu_button.get_popup().item_count - 1, "%s (%d)" %
				[tag_data.get("name", "<>"), tag_data.get("count", 0)])
		


func _on_search_line_edit_text_submitted(search_text: String) -> void:
	_search_or_open_link(search_text)


## An empty text lists all projects.
func _search_or_open_link(in_text: String) -> void:
	var link: MsepOnlineLink = MsepOnlineLink.parse(in_text)
	var is_link: bool = link.kind != MsepOnlineLink.Kind.NONE
	if is_link:
		_open_link(link)
		return
	var tags := PackedStringArray(_selected_tags.keys())
	_search(in_text, tags, _sort_type, 1)


func _open_link(in_link: MsepOnlineLink) -> void:
	_search_promise = null
	_set_state(State.SEARCHING)
	var resolution: OnlineProjectLinkResolver.Resolution = await _link_resolver.resolve(in_link)
	if resolution.is_superseded:
		return
	if resolution.has_failed():
		_show_search_error(resolution.error)
		return
	_set_state(State.SHOW_RESULT)
	_pagination_label.hide()
	_update_project_list([resolution.project_data], false, resolution.version_number)


func _show_search_error(in_message: String) -> void:
	_set_state(State.ERROR)
	_error_info_label.message = in_message


func _search(
		search_text: String,
		tags: PackedStringArray,
		sort_type: MsepOnline.SortType,
		in_page: int) -> void:
	var promise: Promise = MolecularEditorContext.msep_online.get_explore_projects(
		search_text,
		tags,
		sort_type,
		in_page
	)
	_last_search.search_text = search_text
	_last_search.sort_type = sort_type
	_last_search.tags = tags
	_last_search.page = in_page
	_search_promise = promise
	_link_resolver.cancel()
	_set_state(State.SEARCHING)
	await promise.wait_for_fulfill()
	if _search_promise != promise:
		# Another search started before this one finished
		return
	if promise.has_error():
		_set_state(State.ERROR)
		_error_info_label.message = promise.get_error()
		return
	var search_result: Dictionary = promise.get_result().body
	var projects: Array[Dictionary] = []
	projects.assign(search_result.get("projects", []))
	var found_nothing: bool = projects.is_empty()
	if found_nothing:
		_show_search_error(tr("No projects found."))
		return
	_set_state(State.SHOW_RESULT)
	_update_project_list(projects)
	_update_pagination_label(search_result.get("pagination", {}))


func _update_project_list(in_projects: Array, in_editable: bool = false, in_preferred_version: int = -1) -> void:
	for child: Node in _project_list_container.get_children():
		child.queue_free()
	var project_list_item_scene: PackedScene = load("uid://b0fq8rcdj6itm")
	for project_data: Dictionary in in_projects:
		if project_data.is_empty():
			push_warning("Unexpected empty project data")
			continue
		var item: Control = project_list_item_scene.instantiate()
		item.set_preferred_version(in_preferred_version)
		item.set_project_data(project_data)
		item.import_button_pressed.connect(_on_import_button_pressed)
		item.edit_button_pressed.connect(_on_edit_button_pressed)
		item.set_edit_button_visible(in_editable)
		_project_list_container.add_child(item)


func _on_edit_button_pressed(in_project_data: Dictionary) -> void:
	hide()
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	var project_namespace: String = in_project_data.get("namespace", "")
	var project_name: String = in_project_data.get("name", "")
	var edit_dialog: EditProjectDialog = load("uid://610gl77d6ye").instantiate()
	get_parent().add_child(edit_dialog)
	edit_dialog.popup_centered.call_deferred(edit_dialog.size)
	edit_dialog.set_project_data(
		in_project_data,
		msep_online.get_namespace_project_tags(project_namespace, project_name),
		msep_online.get_namespace_project_collaborators(project_namespace, project_name)
	)
	await edit_dialog.finished
	edit_dialog.queue_free()
	open_my_projects()


func _on_import_button_pressed(project_data: Dictionary, version_uuid: String, version_number: int) -> void:
	if version_uuid.is_empty():
		DisplayServer.dialog_show("ERROR",
		"Failed to identify the download url for %s." % project_data.get("name", ""),
		["OK"], Callable())
		return
	gui_disable_input = true
	get_ok_button().disabled = true
	for child: Node in _project_list_container.get_children():
		child.notify_download_started()
	var promise: DownloadPromise = MolecularEditorContext.msep_online.download_project_version(version_uuid)
	_download_promise = promise
	await promise.wait_for_fulfill()
	await get_tree().process_frame # show the progress bar completed by one frame
	_download_promise = null
	gui_disable_input = false
	get_ok_button().disabled = false
	if promise.has_error():
		for child: Node in _project_list_container.get_children():
			child.notify_download_ended()
		DisplayServer.dialog_show("ERROR",
		promise.get_error(),
		["OK"], Callable())
		return
	var provenance_fetcher := ProvenanceRecordFetcher.new(MolecularEditorContext.msep_online)
	var provenance_record: ProvenanceRecord = await provenance_fetcher.fetch(version_uuid)
	if provenance_record == null:
		for child: Node in _project_list_container.get_children():
			child.notify_download_ended()
		DisplayServer.dialog_show("ERROR",
		"Failed to read the project details needed for provenance: %s" % provenance_fetcher.error,
		["OK"], Callable())
		return
	var file_data: PackedByteArray = promise.get_result().raw_body
	var structure_name: String = "%s [v%d]" % [project_data.get("name", ""), version_number]
	var md5: String = file_data.get_string_from_utf8().md5_text()
	var temp_file_path: String = OS.get_temp_dir().path_join(md5+".msep1")
	var temp_file := FileAccess.open(temp_file_path, FileAccess.WRITE)
	temp_file.store_buffer(file_data)
	temp_file.close()
	const SHOULD_GENERATE_BONDS = false
	const SHOULD_ADD_HYDROGENS = false
	const SHOULD_REMOVE_WATERS = false
	WorkspaceUtils.import_file(
		MolecularEditorContext.get_current_workspace_context(),
		temp_file_path, SHOULD_GENERATE_BONDS, SHOULD_ADD_HYDROGENS, SHOULD_REMOVE_WATERS,
		ImportFileDialog.Placement.IN_FRONT_OF_CAMERA, true, "Import File", structure_name,
		provenance_record
	)
	DirAccess.remove_absolute(temp_file_path)
	hide()


func _update_pagination_label(pagination_data: Dictionary) -> void:
	var current_page: int = _last_search.get("page", 1)
	var last_page: int = pagination_data.get("total_pages", 1)
	var mid_pages: Dictionary[int, bool] = {}
	
	var register_page: Callable = func(page: int) -> void:
		if page < 1 or page > last_page:
			return
		if abs(current_page - page) < 2:
			mid_pages[page] = true
	
	register_page.call(1)
	register_page.call(current_page - 2)
	register_page.call(current_page - 1)
	register_page.call(current_page)
	register_page.call(current_page + 1)
	register_page.call(current_page + 2)
	register_page.call(last_page)
	var show_start_ellipsis: bool = not 2 in mid_pages and last_page > 1
	var show_end_ellipsis: bool = not last_page - 1 in mid_pages and last_page > 2
	
	var added_pages: Dictionary[int, bool]
	var add_page: Callable = func(page: int) -> void:
		if added_pages.get(page, false) == true:
			return
		added_pages[page] = true
		if not _pagination_label.text.is_empty():
			_pagination_label.append_text(" ")
		if page == current_page:
			_pagination_label.append_text(str(page))
		else:
			_pagination_label.push_meta(page)
			_pagination_label.append_text(str(page))
			_pagination_label.pop()
	
	_pagination_label.clear()
	_pagination_label.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	add_page.call(1)
	if show_start_ellipsis:
		_pagination_label.append_text(" ...")
	for page: int in mid_pages.keys():
		add_page.call(page)
	if show_end_ellipsis:
		_pagination_label.append_text(" ...")
	add_page.call(last_page)
	_pagination_label.pop_all()


func _on_sort_menu_button_id_pressed(id: int) -> void:
	_sort_type = id as MsepOnline.SortType
	_sort_menu_button.text = MsepOnline.SORT_TYPE_STRING[_sort_type].capitalize()
	_search_or_open_link(_search_line_edit.text)


func _on_tags_menu_button_index_pressed(index: int) -> void:
	var tag: String = _tags_menu_button.get_popup().get_item_text(index)
	var label: TagLabel = _selected_tags.get(tag, null) as TagLabel
	if label == null:
		# Add tag:
		label = TagLabel.create_tag(tag)
		label.erase_requested.connect(_on_tags_menu_button_index_pressed.bind(index))
		_filter_tags_container.add_child(label)
		_selected_tags[tag] = label
		_tags_menu_button.get_popup().set_item_checked(index, true)
	else:
		# Remove tag:
		_selected_tags.erase(tag)
		label.queue_free()
		_tags_menu_button.get_popup().set_item_checked(index, false)


func _on_pagination_label_meta_clicked(page: int) -> void:
	_search(
		_last_search.search_text,
		_last_search.tags,
		_last_search.sort_type,
		page
	)
