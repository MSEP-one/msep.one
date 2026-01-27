extends NanoAcceptDialog

enum State {
	CLEAR,
	SEARCHING,
	ERROR,
	SHOW_RESULT,
}


@onready var _search_line_edit: LineEdit = %SearchLineEdit
@onready var _sort_menu_button: MenuButton = %SortMenuButton
@onready var _tags_menu_button: MenuButton = %TagsMenuButton
@onready var _filter_tags_container: HFlowContainer = %FilterTagsContainer
@onready var _clear_search_label: Label = %ClearSearchLabel
@onready var _loading_indicator: Control = %LoadingIndicator
@onready var _error_info_label: InfoLabel = %ErrorInfoLabel
@onready var _project_list_container: VBoxContainer = %ProjectListContainer
@onready var _pagination_label: RichTextLabel = %PaginationLabel


var _search_promise: Promise
var _sort_type := MsepOnlineService.SortType.UPDATED
var _selected_tags: Dictionary[String, TagLabel]


var _last_search: Dictionary = {
	search_text = "",
	sort_type = MsepOnlineService.SortType.UPDATED,
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


func _on_about_to_popup() -> void:
	_set_state(State.CLEAR)
	_update_tags_menu()
	_search_line_edit.text = ""
	_search_line_edit.grab_focus.call_deferred()


func _set_state(in_state: State) -> void:
	_clear_search_label.visible = in_state == State.CLEAR
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
	var promise: Promise = MolecularEditorContext.msep_online_service.get_explore_tags()
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
	if search_text.is_empty():
		_set_state(State.CLEAR)
		_search_promise = null
		return
	
	var tags := PackedStringArray(_selected_tags.keys())
	_search(search_text, tags, _sort_type, 1)


func _search(
		search_text: String,
		tags: PackedStringArray,
		sort_type: MsepOnlineService.SortType,
		in_page: int) -> void:
	var promise: Promise = MolecularEditorContext.msep_online_service.get_explore_projects(
		search_text,
		tags,
		sort_type,
		in_page
	)
	_last_search.search_text = search_text
	_last_search.sort_type = _sort_type
	_last_search.tags = tags
	_last_search.page = 1
	_search_promise = promise
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
	_set_state(State.SHOW_RESULT)
	_update_project_list(search_result.get("projects", []))
	_update_pagination_label(search_result.get("pagination", {}))


func _update_project_list(in_projects: Array) -> void:
	for child: Node in _project_list_container.get_children():
		child.queue_free()
	var project_list_item_scene: PackedScene = load("uid://b0fq8rcdj6itm")
	for project_data: Dictionary in in_projects:
		if project_data.is_empty():
			push_warning("Unexpected empty project data")
			continue
		var item: Control = project_list_item_scene.instantiate()
		item.set_project_data(project_data)
		item.import_button_pressed.connect(_on_import_button_pressed)
		_project_list_container.add_child(item)


func _on_import_button_pressed(project_data: Dictionary, version_number: int) -> void:
	DisplayServer.dialog_show("TODO",
		"Needs to implement import\n\n" +
		JSON.stringify(project_data, "\t") + "\n\n" +
		"Selected Version Number: " + str(version_number),
		["OK"], Callable())


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
	_sort_type = id as MsepOnlineService.SortType
	_sort_menu_button.text = MsepOnlineService.SORT_TYPE_STRING[_sort_type].capitalize()


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
		_last_search.sort_type,
		_last_search.tags,
		page
	)
