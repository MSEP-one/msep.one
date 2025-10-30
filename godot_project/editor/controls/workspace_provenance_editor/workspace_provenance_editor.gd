@tool extends VBoxContainer


enum Columns {
	ProjectName,
	Version,
	Uploader,
}


var _provenance_tree: Tree
var _new_provenance_url_line_edit: LineEdit
var _add_provenance_button: Button


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_provenance_tree = %ProvenanceTree as Tree
		_new_provenance_url_line_edit = %NewProvenanceUrlLineEdit as LineEdit
		_add_provenance_button = %AddProvenanceButton as Button
		
		_provenance_tree.set_column_title(Columns.ProjectName, tr("Project"))
		_provenance_tree.set_column_title(Columns.Version, tr("Version"))
		_provenance_tree.set_column_title(Columns.Uploader, tr("Prublisher"))
		_provenance_tree.clear()
		# Create root
		_provenance_tree.create_item()
		_provenance_tree.hide_root = true
		
		if Engine.is_editor_hint():
			return
		_add_provenance_button.pressed.connect(_on_add_provenance_button_pressed)


func setup(_in_workspace: Workspace) -> void:
	# TODO: read provenance from Workspace and fill table
	pass


func _on_add_provenance_button_pressed() -> void:
	# TODO: validate url and add
	pass
