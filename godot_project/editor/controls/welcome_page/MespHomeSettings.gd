extends Resource

@export
var known_workspaces: Array[String]

@export
var open_workspaces: Array[String]

@export
var autoload_open_workspaces: bool = false


func _init() -> void:
	assert(is_instance_valid(MolecularEditorContext), "Home settings was loaded before MolecularEditorContext autoload")
	
	MolecularEditorContext.workspace_loaded.connect(_on_workspace_loaded)
	MolecularEditorContext.workspace_activated.connect(_on_workspace_activated)
	MolecularEditorContext.workspace_saved.connect(_on_workspace_saved)
	MolecularEditorContext.workspace_closed.connect(_on_workspace_closed)

func _on_workspace_loaded(in_workspace: Workspace) -> void:
	if in_workspace.resource_path.is_empty():
		# workspace is unsaved, skip
		return
	var dirty: bool = false
	var path: String = ProjectSettings.globalize_path(in_workspace.resource_path)
	var index: int = known_workspaces.find(path)
	if index == -1:
		# not in the list, push it
		known_workspaces.push_back(path)
		dirty = true
	# Workspace is now open
	if open_workspaces.find(path) == -1:
		open_workspaces.push_back(path)
		dirty = true
	if dirty:
		emit_changed()

func _on_workspace_activated(in_workspace: Workspace) -> void:
	if in_workspace.resource_path.is_empty():
		# workspace is unsaved, skip
		return
	var dirty: bool = false
	var path: String = ProjectSettings.globalize_path(in_workspace.resource_path)
	var index: int = known_workspaces.find(path)
	if index == -1:
		# not in the list, push it
		known_workspaces.push_front(path)
		dirty = true
	elif index != 0:
		# move it to the top
		known_workspaces.remove_at(index)
		known_workspaces.push_front(path)
		dirty = true
	# Workspace is now open
	if open_workspaces.find(path) == -1:
		open_workspaces.push_back(path)
		dirty = true
	if dirty:
		emit_changed()

func _on_workspace_saved(in_workspace: Workspace) -> void:
	# same behaviour as workspace activated
	_on_workspace_activated(in_workspace)

func _on_workspace_closed(in_workspace: Workspace) -> void:
	if in_workspace.resource_path.is_empty():
		# workspace is unsaved, skip
		return
	var path: String = ProjectSettings.globalize_path(in_workspace.resource_path)
	var index: int = open_workspaces.find(path)
	if index != -1:
		open_workspaces.remove_at(index)
		emit_changed()
