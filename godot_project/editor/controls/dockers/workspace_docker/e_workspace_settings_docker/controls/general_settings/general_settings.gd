extends DynamicContextControl

@onready var text_edit_description: TextEdit = $PanelContainer/TextEditDescription
@onready var line_edit_authors: LineEdit = $PanelContainer2/LineEditAuthors


var _workspace_context: WorkspaceContext = null
var _loading: bool = false


func _ready() -> void:
	text_edit_description.focus_exited.connect(_on_text_edit_description_focus_exited)
	line_edit_authors.focus_exited.connect(_on_line_edit_authors_focus_exited)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		_workspace_context.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)
	load_settings()
	return true


func _on_text_edit_description_focus_exited() -> void:
	if !_loading and _workspace_context != null:
		if _workspace_context.workspace.description != text_edit_description.text:
			_workspace_context.workspace.description = text_edit_description.text
			_workspace_context.snapshot_moment("Set Description")


func _on_line_edit_authors_focus_exited() -> void:
	if !_loading and _workspace_context != null:
		if _workspace_context.workspace.authors != line_edit_authors.text:
			_workspace_context.workspace.authors = line_edit_authors.text
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

