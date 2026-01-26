extends OptionButton

signal version_changed(number_or_minus_one: int)

var _project_data: Dictionary
var _versions_data: Dictionary


func _ready() -> void:
	item_selected.connect(_on_item_selected)


func _on_item_selected(index: int) -> void:
	if index == -1:
		version_changed.emit(-1)
	else:
		version_changed.emit(get_item_id(index))


func set_project_data(in_data: Dictionary) -> void:
	assert(not in_data.is_empty())
	_project_data = in_data
	update_versions_list()


func retract_selected_version(reason: String) -> void:
	var version_number: int = get_selected_id()
	assert(version_number >= 0)
	if get_version_data(version_number).get("is_retracted", false) == true:
		assert(false, "Requested to retract an already retracted version, UX shouldn't allow this")
		return
	var promise: Promise = MolecularEditorContext.msep_online_service.delete_namespace_project_version(
		_project_data.namespace, _project_data.name, version_number, reason
	)
	await promise.wait_for_fulfill()
	if promise.has_error():
		DisplayServer.dialog_show("Failed", promise.get_error(), ["OK"], Callable())
		return
	# Update and wait until
	if is_visible_in_tree():
		await update_versions_list()


func update_versions_list() -> void:
		var prev_version: int = -1 if selected == -1 else get_selected_id()
		clear()
		version_changed.emit(-1)
		var proj_namespace: String = _project_data.namespace
		var proj_name: String = _project_data.name
		var promise: Promise = MolecularEditorContext.msep_online_service.get_namespace_project_versions(
			proj_namespace, proj_name
		)
		await promise.wait_for_fulfill()
		if promise.has_error():
			text = promise.get_error()
			return
		_versions_data = promise.get_result().body
		var versions: Array[Dictionary] = []
		versions.assign(_versions_data.versions)
		var selected_something: bool = false
		var biggest_version: int = 0
		for version: Dictionary in versions:
			var number: int = version.version_number
			if version.get("is_retracted", false) == false:
				biggest_version = max(biggest_version, number)
				add_item("Version #%d" % number, number)
			else:
				add_item("Version #%d (retracted)" % number, number)
			if prev_version != -1 and number == prev_version:
				var index: int = item_count -1
				select(index)
				selected_something = true
		if selected_something == false and biggest_version > 0:
			select(get_item_index(biggest_version))
			version_changed.emit(biggest_version)
		elif selected_something == false and item_count > 0:
			# All versions are retracted, let's select last one
			select(item_count-1)
			version_changed.emit(get_item_id(item_count-1))


func get_version_data(version_number: int) -> Dictionary:
	var versions: Array[Dictionary] = []
	versions.assign(_versions_data.versions)
	for version: Dictionary in versions:
		if version.version_number == version_number:
			return version
	return {}
