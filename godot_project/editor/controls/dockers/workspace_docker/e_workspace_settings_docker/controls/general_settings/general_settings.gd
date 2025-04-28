extends DynamicContextControl

@onready var text_edit_description: TextEdit = $PanelContainer/TextEditDescription
@onready var line_edit_authors: LineEdit = $PanelContainer2/LineEditAuthors


var _workspace_context: WorkspaceContext = null
var _loading: bool = false


func _ready() -> void:
	text_edit_description.text_changed.connect(_on_text_edit_description_text_changed)
	line_edit_authors.text_changed.connect(_on_line_edit_authors_text_changed)
	text_edit_description.focus_exited.connect(_on_text_edit_description_focus_exited)
	line_edit_authors.focus_exited.connect(_on_line_edit_authors_focus_exited)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		_workspace_context.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)
	load_settings()
	return true


func _on_text_edit_description_text_changed() -> void:
	const CREATE_SNAPSHOT = false # Dont create snapshot because have not finished editing
	_update_workspace_description(CREATE_SNAPSHOT)


func _on_line_edit_authors_text_changed(_in_new_text: String) -> void:
	const CREATE_SNAPSHOT = false # Dont create snapshot because have not finished editing
	_update_workspace_authors(CREATE_SNAPSHOT)


func _on_text_edit_description_focus_exited() -> void:
	const CREATE_SNAPSHOT = true # Creating snapshot because finished editing
	_update_workspace_description(CREATE_SNAPSHOT)


func _on_line_edit_authors_focus_exited() -> void:
	const CREATE_SNAPSHOT = true # Creating snapshot because finished editing
	_update_workspace_authors(CREATE_SNAPSHOT)


func _update_workspace_description(in_create_snapshot: bool) -> void:
	if !_loading and _workspace_context != null:
		if _workspace_context.workspace.description != text_edit_description.text:
			_workspace_context.workspace.description = text_edit_description.text
			if in_create_snapshot:
				_workspace_context.snapshot_moment("Set Description")


func _update_workspace_authors(in_create_snapshot: bool) -> void:
	if !_loading and _workspace_context != null:
		if _workspace_context.workspace.authors != line_edit_authors.text:
			_workspace_context.workspace.authors = line_edit_authors.text
			if in_create_snapshot:
				_workspace_context.snapshot_moment("Set Authors")


func _on_workspace_context_history_snapshot_applied() -> void:
	load_settings()


func load_settings() -> void:
	if _workspace_context == null:
		return
	_loading = true
	text_edit_description.text = _workspace_context.workspace.description
	line_edit_authors.text = _workspace_context.workspace.authors
	_loading = false

