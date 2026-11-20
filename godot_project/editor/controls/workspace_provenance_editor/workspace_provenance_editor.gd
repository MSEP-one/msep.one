@tool class_name WorkspaceProvenanceEditor extends VBoxContainer

signal remove_confirmed(record: ProvenanceRecord)

enum Columns {
	Title,
	Creator,
	Date,
	Description,
	Keywords,
}

const DATE_CHARACTER_COUNT: int = 10

@onready var _provenance_tree: Tree = %ProvenanceTree
@onready var _image_preview_texture_rect: TextureRect = %ImagePreviewTextureRect
@onready var _remove_button: Button = %RemoveButton
@onready var _remove_confirmation_dialog: ConfirmationDialog = %RemoveConfirmationDialog
@onready var _record_opener: ProvenanceRecordOpener = %ProvenanceRecordOpener


func _ready() -> void:
	_provenance_tree.set_column_title(Columns.Title, tr("Title"))
	_provenance_tree.set_column_title(Columns.Creator, tr("Creator"))
	_provenance_tree.set_column_title(Columns.Date, tr("Date"))
	_provenance_tree.set_column_title(Columns.Description, tr("Description"))
	_provenance_tree.set_column_title(Columns.Keywords, tr("Keywords"))
	_provenance_tree.set_column_expand(Columns.Date, false)
	_provenance_tree.set_column_custom_minimum_width(Columns.Date, 90)
	_provenance_tree.set_column_expand_ratio(Columns.Title, 2)
	_provenance_tree.set_column_expand_ratio(Columns.Description, 2)
	_provenance_tree.clear()


func setup(in_workspace: Workspace, in_is_editable: bool) -> void:
	_remove_button.visible = in_is_editable
	_provenance_tree.clear()
	var root: TreeItem = _provenance_tree.create_item()
	_add_records(root, in_workspace.get_provenance())
	_remove_button.disabled = true
	_show_image_preview(null)


func _add_records(out_parent: TreeItem, in_records: Array[ProvenanceRecord]) -> void:
	for record: ProvenanceRecord in in_records:
		var item: TreeItem = _provenance_tree.create_item(out_parent)
		item.set_metadata(Columns.Title, record)
		item.set_text(Columns.Title, record.project_name)
		item.set_text(Columns.Creator, record.creator)
		item.set_tooltip_text(Columns.Creator, record.organization)
		item.set_text(Columns.Date, record.upload_date.left(DATE_CHARACTER_COUNT))
		item.set_text(Columns.Description, record.description.get_slice("\n", 0))
		item.set_tooltip_text(Columns.Description, record.description)
		item.set_text(Columns.Keywords, ", ".join(record.keywords))
		item.set_custom_color(Columns.Title, get_theme_color("font_hover_color", "Button"))
		item.set_custom_color(Columns.Creator, get_theme_color("font_hover_color", "Button"))
		item.collapsed = true
		_add_records(item, record.children)


func _get_selected_record() -> ProvenanceRecord:
	var selected_item: TreeItem = _provenance_tree.get_selected()
	if selected_item == null:
		return null
	return selected_item.get_metadata(Columns.Title) as ProvenanceRecord


func _on_provenance_tree_item_selected() -> void:
	_remove_button.disabled = false
	var record: ProvenanceRecord = _get_selected_record()
	_show_image_preview(record)


func _on_provenance_tree_nothing_selected() -> void:
	_remove_button.disabled = true
	_show_image_preview(null)


func _show_image_preview(in_record: ProvenanceRecord) -> void:
	var image: Texture2D = null if in_record == null else in_record.get_image()
	_image_preview_texture_rect.texture = image
	_image_preview_texture_rect.visible = image != null


func _on_provenance_tree_item_activated() -> void:
	var record: ProvenanceRecord = _get_selected_record()
	if record == null:
		return
	var selected_column: int = _provenance_tree.get_selected_column()
	if selected_column == Columns.Title:
		_record_opener.open_record(record)
	elif selected_column == Columns.Creator:
		_record_opener.open_creator_page(record)


func _on_remove_button_pressed() -> void:
	var record: ProvenanceRecord = _get_selected_record()
	if record == null:
		return
	_remove_confirmation_dialog.dialog_text = tr(
		"Remove the provenance record of '%s' together with all records nested in it?"
	) % record.project_name
	_remove_confirmation_dialog.popup_centered()


func _on_remove_confirmation_dialog_confirmed() -> void:
	var record: ProvenanceRecord = _get_selected_record()
	if record == null:
		return
	remove_confirmed.emit(record)
