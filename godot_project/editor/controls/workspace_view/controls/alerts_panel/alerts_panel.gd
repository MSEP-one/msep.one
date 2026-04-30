class_name AlertsPanel extends PanelContainer


const ICONS: Dictionary[AlertLevel, Texture2D] = {
	AlertLevel.WARNING: preload("res://editor/icons/icon_warning_x16.svg"),
	AlertLevel.ERROR: preload("res://editor/icons/icon_error_x16.svg"),
	AlertLevel.FIXED: preload("res://editor/icons/icon_valid_x16.svg"),
	AlertLevel.INVALID: preload("res://editor/controls/menu_bar/menu_edit/icons/icon_delete.svg"),
}
const COLOR_OUTDATED: Color = Color(0.64, 0.64, 0.64)

enum AlertLevel {
	WARNING,
	ERROR,
	FIXED,
	INVALID,
}

var _fixed_mask_button: Button
var _warnings_mask_button: Button
var _errors_mask_button: Button
var _invalid_mask_button: Button
var _close_button: Button
var _tree: Tree
var _data: Dictionary[int, AlertData] = {} # AlertID : Data
var _highest_id: int = 0
var _settings: RepresentationSettings


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_fixed_mask_button = %FixedMaskButton as Button
		_warnings_mask_button = %WarningsMaskButton as Button
		_errors_mask_button = %ErrorsMaskButton as Button
		_invalid_mask_button = %InvalidMaskButton as Button
		_close_button = %CloseButton as Button
		_tree = %Tree as Tree
		_fixed_mask_button.toggled.connect(_on_fixed_mask_button_toggled)
		_warnings_mask_button.toggled.connect(_on_warnings_mask_button_toggled)
		_errors_mask_button.toggled.connect(_on_errors_mask_button_toggled)
		_invalid_mask_button.toggled.connect(_on_invalid_mask_button_toggled)
		_close_button.pressed.connect(_on_close_button_pressed)
		_tree.item_selected.connect(_on_tree_item_selected)
		_tree.item_activated.connect(_on_tree_item_activated)
		clear_and_close()
		hide()


func initialize(workspace_context: WorkspaceContext) -> void:
	workspace_context.register_snapshotable(self)
	_settings = workspace_context.workspace.representation_settings
	_settings.theme_changed.connect(_update_panel_color)
	_settings.changed.connect(_update_panel_color)
	_update_panel_color()


## Returns the number of alerts being displayed
func get_alerts_count() -> int:
	return _tree.get_root().get_child_count()


## Returns the selected alert id, or 0 if nothing is selected.
func get_alert_selected() -> int:
	var selected: TreeItem = _tree.get_selected()
	if not selected:
		return 0
	var alert_data: AlertData = selected.get_meta(&"alert_data")
	return alert_data.id


func clear_and_close() -> void:
	clear_contents()
	hide()


func clear_contents() -> void:
	_highest_id = 0
	_tree.clear()
	_data.clear()
	# Create Root
	_tree.create_item(null)
	_tree.hide_root = true
	_warnings_mask_button.set_pressed_no_signal(false)
	_errors_mask_button.set_pressed_no_signal(false)
	ScriptUtils.call_deferred_once(_update_mask_buttons)


## Adds a Warning item to the Alerts list, [code]in_selected_callback[/code] should
## take the alert ID [int] as first argument
func add_warning(in_text:String, in_selected_callback: Callable, in_activated_callback: Callable) -> int:
	_warnings_mask_button.button_pressed = true
	ScriptUtils.call_deferred_once(_update_mask_buttons)
	return _add_item(in_text, AlertLevel.WARNING, in_selected_callback, in_activated_callback)


## Adds an Error item to the Alerts list, [code]in_selected_callback[/code] should
## take the alert ID [int] as first argument
func add_error(in_text:String, in_selected_callback: Callable, in_activated_callback: Callable) -> int:
	_errors_mask_button.button_pressed = true
	ScriptUtils.call_deferred_once(_update_mask_buttons)
	return _add_item(in_text, AlertLevel.ERROR, in_selected_callback, in_activated_callback)


func mark_as_fixed(in_alert_id: int) -> void:
	var alert: AlertData = _data.get(in_alert_id)
	if not alert:
		return
	alert.level = AlertLevel.FIXED
	alert.update_tree_item()
	_update_mask_buttons()


func mark_as_invalid(in_alert_id: int) -> void:
	var alert: AlertData = _data.get(in_alert_id)
	if not alert:
		return
	alert.level = AlertLevel.INVALID
	alert.update_tree_item()
	_invalid_mask_button.button_pressed = true
	_update_mask_buttons()


func toggle_all(in_enabled: bool) -> void:
	toggle_fixed(in_enabled)
	toggle_warnings(in_enabled)
	toggle_errors(in_enabled)
	toggle_invalid(in_enabled)


func toggle_fixed(in_enabled: bool) -> void:
	_fixed_mask_button.button_pressed = in_enabled
	_on_fixed_mask_button_toggled(in_enabled)


func toggle_warnings(in_enabled: bool) -> void:
	_warnings_mask_button.button_pressed = in_enabled
	_on_warnings_mask_button_toggled(in_enabled)


func toggle_errors(in_enabled: bool) -> void:
	_errors_mask_button.button_pressed = in_enabled
	_on_errors_mask_button_toggled(in_enabled)


func toggle_invalid(in_enabled: bool) -> void:
	_invalid_mask_button.button_pressed = in_enabled
	_on_invalid_mask_button_toggled(in_enabled)


func create_state_snapshot() -> Dictionary:
	var copy: Dictionary = {}
	for alert_id: int in _data:
		var data: AlertData = _data[alert_id]
		copy[alert_id] = data.get_copy()
	return {"data": copy}


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	clear_contents()
	var snapshot_data: Dictionary = in_snapshot.get("data", {})
	for alert_id: int in snapshot_data:
		var alert_data: AlertData = snapshot_data[alert_id].get_copy()
		_data[alert_id] = alert_data
		alert_data.create_tree_item(_tree)
		_highest_id = max(_highest_id, alert_id)
	_update_mask_buttons()


func _update_panel_color() -> void:
	var background: Color = _settings.get_final_background_color()
	self_modulate.v = remap(background.v, 0.0, 1.0, 1.0, 0.25)


func _on_fixed_mask_button_toggled(in_button_pressed: bool) -> void:
	_filter_contents(AlertLevel.FIXED, in_button_pressed)


func _on_warnings_mask_button_toggled(in_button_pressed: bool) -> void:
	_filter_contents(AlertLevel.WARNING, in_button_pressed)


func _on_errors_mask_button_toggled(in_button_pressed: bool) -> void:
	_filter_contents(AlertLevel.ERROR, in_button_pressed)


func _on_invalid_mask_button_toggled(in_button_pressed: bool) -> void:
	_filter_contents(AlertLevel.INVALID, in_button_pressed)


func _filter_contents(in_type: AlertLevel, in_visible: bool) -> void:
	var tree_items: Array[TreeItem] = _tree.get_root().get_children()
	for item in tree_items:
		var alert_data: AlertData = item.get_meta(&"alert_data")
		if alert_data.level == in_type:
			item.visible = in_visible


func _on_close_button_pressed() -> void:
	hide()


func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	var alert_data: AlertData = item.get_meta(&"alert_data")
	var callback: Callable = alert_data.selected_callback
	if callback.is_valid():
		callback.call(alert_data.id)


func _on_tree_item_activated() -> void:
	var item: TreeItem = _tree.get_selected()
	var alert_data: AlertData = item.get_meta(&"alert_data")
	var callback: Callable = alert_data.activated_callback
	if callback.is_valid():
		callback.call(alert_data.id)


func _update_mask_buttons() -> void:
	var fixed_count: int = 0
	var warnings_count: int = 0
	var errors_count: int = 0
	var invalid_count: int = 0
	for alert: AlertData in _data.values():
		match alert.level:
			AlertLevel.WARNING:
				warnings_count += 1
			AlertLevel.ERROR:
				errors_count += 1
			AlertLevel.FIXED:
				fixed_count += 1
			AlertLevel.INVALID:
				invalid_count += 1
	
	_warnings_mask_button.text = str(warnings_count)
	_warnings_mask_button.disabled = (warnings_count == 0)
	_errors_mask_button.text = str(errors_count)
	_errors_mask_button.disabled = (errors_count == 0)
	_fixed_mask_button.text = str(fixed_count)
	_fixed_mask_button.visible = fixed_count > 0
	_invalid_mask_button.text = str(invalid_count)
	_invalid_mask_button.visible = invalid_count > 0


func _add_item(in_text: String, in_level: AlertLevel, in_selected_callback: Callable, in_activated_callback: Callable) -> int:
	_highest_id += 1
	var alert_data := AlertData.new(_highest_id, in_text, in_level, in_selected_callback, in_activated_callback)
	_data[alert_data.id] = alert_data
	alert_data.create_tree_item(_tree)
	return alert_data.id


class AlertData:
	var id: int
	var level: AlertLevel
	var text: String
	var selected_callback: Callable
	var activated_callback: Callable
	var _tree_item: TreeItem
	
	func _init(in_id: int, in_text: String, in_level: AlertLevel, in_selected: Callable, in_activated: Callable) -> void:
		id = in_id
		text = in_text
		level = in_level
		selected_callback = in_selected
		activated_callback = in_activated
	
	func create_tree_item(tree: Tree) -> TreeItem:
		_tree_item = tree.create_item(tree.get_root())
		_tree_item.set_meta(&"alert_data", self)
		update_tree_item()
		return _tree_item
	
	func update_tree_item() -> void:
		if not _tree_item:
			return
		const COLUMN_0 = 0
		_tree_item.set_text(COLUMN_0, text)
		_tree_item.set_icon(COLUMN_0, ICONS[level])
		if level == AlertLevel.INVALID:
			_tree_item.set_custom_color(0, COLOR_OUTDATED)
			_tree_item.set_icon_modulate(0, COLOR_OUTDATED)
			_tree_item.set_selectable(0, false)
			_tree_item.deselect(0)
	
	func get_copy() -> AlertData:
		return AlertData.new(id, text, level, selected_callback, activated_callback)
