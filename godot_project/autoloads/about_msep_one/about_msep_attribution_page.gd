class_name AboutMsepAttributionPage extends MarginContainer

var _tree: Tree
var _rich_text_label: RichTextLabel

var _last_selected_item: TreeItem = null
var _custom_control: Control = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_tree = %Tree as Tree
		_rich_text_label = %RichTextLabel as RichTextLabel
		
		_tree.clear()
		var _root: TreeItem = _tree.create_item()
		_tree.hide_root = true
	if what == NOTIFICATION_READY:
		_tree.item_selected.connect(_on_tree_item_selected)
		_rich_text_label.meta_clicked.connect(_on_rich_text_label_meta_clicked)


func _create_software_tree_item(in_info: LicenseInfo) -> TreeItem:
	var tree_item: TreeItem = _tree.create_item(_tree.get_root())
	const COLUMN_0: int = 0
	tree_item.set_text(COLUMN_0, in_info.software_name)
	tree_item.set_tooltip_text(COLUMN_0, "{0} ({1})".format([in_info.license_short_name, in_info.license_long_name]))
	tree_item.set_metadata(COLUMN_0, in_info)
	return tree_item


func _create_custom_control_tree_item(in_name: String, in_custom_control_scene: PackedScene) -> TreeItem:
	var tree_item: TreeItem = _tree.create_item(_tree.get_root())
	const COLUMN_0: int = 0
	tree_item.set_text(COLUMN_0, in_name)
	tree_item.set_tooltip_text(COLUMN_0, in_name)
	tree_item.set_metadata(COLUMN_0, in_custom_control_scene)
	return tree_item


func _format_lisence(in_text: String, in_year: String, in_copyright_holders: String) -> String:
	var text: String = in_text
	text = text.replace("<year>", in_year)
	text = text.replace("<copyright holders>", in_copyright_holders)
	return text


func _on_tree_item_selected() -> void:
	var selected: TreeItem = _tree.get_selected()
	if _last_selected_item == selected:
		return
	_last_selected_item = selected
	_rich_text_label.clear()
	_rich_text_label.show()
	if is_instance_valid(_custom_control):
		_custom_control.queue_free()
		_custom_control = null
	if selected == null:
		return
	const COLUMN_0: int = 0
	var meta: Variant = selected.get_metadata(COLUMN_0)
	if meta is LicenseInfo:
		_fill_license_info(meta)
	elif meta is PackedScene:
		# Custom scene with a control
		_custom_control = meta.instantiate() as Control
		_rich_text_label.get_parent_control().add_child(_custom_control)
		_custom_control.size_flags_horizontal = _rich_text_label.size_flags_horizontal
		_custom_control.size_flags_vertical = _rich_text_label.size_flags_vertical
		_custom_control.size_flags_stretch_ratio = _rich_text_label.size_flags_stretch_ratio
		_rich_text_label.hide()


func _fill_license_info(in_info: LicenseInfo) -> void:
	var has_url: bool = not in_info.software_external_url.is_empty()
	# Header
	_rich_text_label.add_text("\n\n")
	_rich_text_label.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	if has_url:
		_rich_text_label.push_meta(in_info.software_external_url)
	_rich_text_label.add_text(in_info.software_name)
	_rich_text_label.pop_all()
	_rich_text_label.add_text("\n\n")
	# Version
	if not in_info.software_version.is_empty():
		_rich_text_label.push_list(0, RichTextLabel.LIST_DOTS, false)
		_rich_text_label.add_text(tr(&"Version: ") + in_info.software_version)
		_rich_text_label.pop_all()
		_rich_text_label.add_text("\n\n")
	
	_rich_text_label.push_list(0, RichTextLabel.LIST_DOTS, false)
	var lic_info: String = "{0} ({1})".format([in_info.license_short_name, in_info.license_long_name])
	_rich_text_label.add_text(tr(&"License: ") + lic_info)
	_rich_text_label.pop_all()
	_rich_text_label.add_text("\n\n")
	
	_rich_text_label.push_indent(2)
	_rich_text_label.add_text(in_info.license_text)
	_rich_text_label.pop_all()


func _on_rich_text_label_meta_clicked(in_meta: String) -> void:
	assert(in_meta.begins_with("https://"), "Unexpected meta: %s" % in_meta)
	OS.shell_open(in_meta)


class LicenseInfo:
	var software_name: String
	var software_version: String
	var software_external_url: String
	var license_short_name: String
	var license_long_name: String
	var license_text: String
	
	func _init(in_name: String, in_version: String, in_url: String,
			in_license_short: String, in_license_long: String,
			in_license_text: String) -> void:
		software_name = in_name
		software_version = in_version
		software_external_url = in_url
		license_short_name = in_license_short
		license_long_name = in_license_long
		license_text = in_license_text
