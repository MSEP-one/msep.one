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
	var service: MsepOnlineService = MolecularEditorContext.msep_online_service
	var authenticator: MsepOnlineAuthenticator = MolecularEditorContext.authenticator
	if not authenticator.is_authenticated():
		return
	fetch_started.emit()
	disabled = true
	var username: String = authenticator.get_username()
	var projects_promise: Promise = service.get_me_editable()
	await projects_promise.wait_for_fulfill()
	if projects_promise.has_error():
		text = tr("Failed to fetch projects")
		project_selected.emit({})
		return
	clear()
	var data: Dictionary = projects_promise.get_result().body
	_projects_data.clear()
	var did_select_something: bool = false
	for project: Dictionary in data.projects:
		var project_name: String = project.name
		if project.namespace != username:
			project_name += " (%s)" % username
		_projects_data[project_name] = project
		_tags_promises[project_name] = service.get_namespace_project_tags(project.namespace, project.name)
		_collaborators_promises[project_name] = service.get_namespace_project_collaborators(project.namespace, project.name)
		add_icon_item(null, project_name)
		if previous_selection == project_name or (previous_selection.is_empty() and not did_select_something):
			did_select_something = true
			var index: int = item_count - 1
			_on_item_selected(index)
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
