extends Window


const _MSEP_TWEAKS_PATH = "msep/"
const _COLUMN_LABEL: int = 0
const _COLUMN_VALUE: int = 1
const _MIN_RANGE_VALUE: float = -9999999
const _MAX_RANGE_VALUE: float =  9999999
const _INT_STEP: float        =  1
const _FLOAT_STEP: float      =  0.001


@onready var _tweaks_tree: Tree = %TweaksTree
var _tree_root: TreeItem = null
var _branches: Dictionary = {
	# subpath:String = tree_item:TreeItem
}


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	_tweaks_tree.item_edited.connect(_on_tweaks_tree_item_edited)


func _notification(what: int) -> void:
	if what != NOTIFICATION_SCENE_INSTANTIATED:
		return
	_tweaks_tree = %TweaksTree
	var tweaks: Array[String] = []
	_clear()
	for setting in ProjectSettings.get_property_list():
		if setting.name.begins_with(_MSEP_TWEAKS_PATH):
			tweaks.append(setting.name)
	
	for full_path in tweaks:
		var path_parts: PackedStringArray = full_path.split("/").slice(1)
		var parent: TreeItem = _tree_root
		for i in range(path_parts.size()):
			var part: String = path_parts[i]
			var sub_path: String = "/".join(path_parts.slice(0, i+1))
			var item: TreeItem = _branches.get(sub_path, null)
			if item == null:
				item = _tweaks_tree.create_item(parent)
				item.set_text(_COLUMN_LABEL, part.capitalize())
				_branches[sub_path] = item
			parent = item
		var item: TreeItem = parent
		item.set_metadata(_COLUMN_LABEL, full_path)
		var setting_value: Variant = ProjectSettings.get_setting(full_path)
		match typeof(setting_value):
			TYPE_INT:
				item.set_cell_mode(_COLUMN_VALUE, TreeItem.CELL_MODE_RANGE)
				item.set_range_config(_COLUMN_VALUE, _MIN_RANGE_VALUE, _MAX_RANGE_VALUE, _INT_STEP)
				item.set_range(_COLUMN_VALUE, setting_value)
			TYPE_FLOAT:
				item.set_cell_mode(_COLUMN_VALUE, TreeItem.CELL_MODE_RANGE)
				item.set_range_config(_COLUMN_VALUE, _MIN_RANGE_VALUE, _MAX_RANGE_VALUE, _FLOAT_STEP)
				item.set_range(_COLUMN_VALUE, setting_value)
			TYPE_BOOL:
				item.set_cell_mode(_COLUMN_VALUE, TreeItem.CELL_MODE_CHECK)
				item.set_checked(_COLUMN_VALUE, setting_value)
				item.set_text(_COLUMN_VALUE, tr("ON" if setting_value else "OFF"))
			TYPE_STRING, TYPE_STRING_NAME:
				item.set_cell_mode(_COLUMN_VALUE, TreeItem.CELL_MODE_STRING)
				item.set_text(_COLUMN_VALUE, setting_value)
			_:
				item.set_text(_COLUMN_VALUE, str(setting_value))
				push_error("Unhandled tweak %s with unhandled value type %s" %
						[full_path, str(setting_value)])
		item.set_editable(_COLUMN_VALUE, true)
	hide()


func _clear() -> void:
	_tweaks_tree.clear()
	_tweaks_tree.columns = 2
	_tweaks_tree.set_column_title(_COLUMN_LABEL, tr("Property"))
	_tweaks_tree.set_column_title(_COLUMN_VALUE, tr("Value"))
	_tweaks_tree.hide_root = true
	_tree_root = _tweaks_tree.create_item()


func _on_close_requested() -> void:
	hide()


func _on_tweaks_tree_item_edited() -> void:
	var edited_item: TreeItem = _tweaks_tree.get_selected()
	if edited_item == null:
		return
	var setting_path: String = edited_item.get_metadata(_COLUMN_LABEL)
	assert(!setting_path.is_empty() && ProjectSettings.has_setting(setting_path))
	var cell_mode: TreeItem.TreeCellMode = edited_item.get_cell_mode(_COLUMN_VALUE)
	match cell_mode:
		TreeItem.CELL_MODE_RANGE:
			ProjectSettings.set_setting(setting_path, edited_item.get_range(_COLUMN_VALUE))
		TreeItem.CELL_MODE_CHECK:
			ProjectSettings.set_setting(setting_path, edited_item.is_checked(_COLUMN_VALUE))
		_:
			push_error("Unsupported cell mode for tweaks")

