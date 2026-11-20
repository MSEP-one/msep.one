extends OptionButton

signal fetch_started()
signal list_updated()
signal project_selected(project_data_or_empty: Dictionary)


var _projects_data: Dictionary[String, Dictionary] = {
	# project_name = data,
}
var _tags_promises: Dictionary[String, Promise] = {
	# project_name = ongoing_or_completed_promise
}
var _collaborators_promises: Dictionary[String, Promise] = {
	# project_name = ongoing_or_completed_promise
}

var _preferred_namespace: String = ""
var _preferred_project_name: String = ""


func select_project_on_next_update(in_namespace: String, in_project_name: String) -> void:
	_preferred_namespace = in_namespace
	_preferred_project_name = in_project_name


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	item_selected.connect(_on_item_selected)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_update()


func _on_item_selected(in_index: int) -> void:
	if in_index == -1:
		project_selected.emit({})
		return
	assert(_projects_data.has(text), "Invalid project with name '%s' selected" % text)
	project_selected.emit(_projects_data[text])


func _update() -> void:
	clear()
	var previous_selection: String = "" if selected == -1 else text
	var msep_online: MsepOnline = MolecularEditorContext.msep_online
	if not msep_online.is_authenticated():
		return
	fetch_started.emit()
	disabled = true
	var username: String = msep_online.get_username()
	var projects_promise: Promise = msep_online.get_me_editable()
	await projects_promise.wait_for_fulfill()
	if projects_promise.has_error():
		text = tr("Failed to fetch projects")
		project_selected.emit({})
		return
	clear()
	var data: Dictionary = projects_promise.get_result().body
	_projects_data.clear()
	var preferred_index: int = -1
	var previous_index: int = -1
	for project: Dictionary in data.projects:
		var project_name: String = project.name
		if project.namespace != username:
			project_name += " (%s)" % project.namespace
		_projects_data[project_name] = project
		_tags_promises[project_name] = msep_online.get_namespace_project_tags(project.namespace, project.name)
		_collaborators_promises[project_name] = msep_online.get_namespace_project_collaborators(
				project.namespace,
				project.name)
		add_icon_item(null, project_name)
		var index: int = item_count - 1
		var is_preferred: bool = project.namespace == _preferred_namespace and project.name == _preferred_project_name
		if is_preferred:
			preferred_index = index
		if previous_selection == project_name:
			previous_index = index
	_preferred_namespace = ""
	_preferred_project_name = ""
	var has_projects: bool = item_count > 0
	if has_projects:
		var index_to_select: int = preferred_index if preferred_index != -1 else maxi(previous_index, 0)
		select(index_to_select)
		_on_item_selected(index_to_select)
	disabled = false
	list_updated.emit()


func get_selected_project_tags_async() -> Promise:
	if selected == -1:
		return _no_project_selected_promise()
	return _tags_promises[text]


func get_selected_project_collaborators_async() -> Promise:
	if selected == -1:
		return _no_project_selected_promise()
	return _collaborators_promises[text]


func _no_project_selected_promise() -> Promise:
	var p := Promise.new()
	p.fail("No project Selected")
	return p
