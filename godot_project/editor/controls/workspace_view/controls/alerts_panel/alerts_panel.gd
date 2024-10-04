class_name AlertsPanel extends PanelContainer

var _warnings_mask_button: Button
var _errors_mask_button: Button
var _close_button: Button
var _tree: Tree

var _warnings_count: int = 0
var _errors_count: int = 0
var _callbacks: Dictionary = {
#	item<TreeItem> = callback<Callable>
}
var _activated_callbacks: Dictionary = {
#	item<TreeItem> = callback<Callable>
}


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_warnings_mask_button = %WarningsMaskButton as Button
		_errors_mask_button = %ErrorsMaskButton as Button
		_close_button = %CloseButton as Button
		_tree = %Tree as Tree
		_warnings_mask_button.toggled.connect(_on_warnings_mask_button_toggled)
		_errors_mask_button.toggled.connect(_on_errors_mask_button_toggled)
		_close_button.pressed.connect(_on_close_button_pressed)
		_tree.item_selected.connect(_on_tree_item_selected)
		_tree.item_activated.connect(_on_tree_item_activated)
		clear_and_close()


## Returns the number of alerts being displayed
func get_alerts_count() -> int:
	return _tree.get_root().get_child_count()


## Returns the selected TreeItem, if any
func get_alert_selected() -> TreeItem:
	return _tree.get_selected()


## Clears the content and hides the window
func clear_and_close() -> void:
	_callbacks = {}
	_activated_callbacks = {}
	_tree.clear()
	_warnings_count = 0
	_errors_count = 0
	# Create Root
	_tree.create_item(null)
	_tree.hide_root = true
	_warnings_mask_button.set_pressed_no_signal(false)
	_errors_mask_button.set_pressed_no_signal(false)
	ScriptUtils.call_deferred_once(_update_mask_buttons)
	hide()


## Adds a Warning item to the Alerts list, [code]in_selected_callback[/code] should
## take a [TreeItem] as  first argument
func add_warning(in_text:String, in_selected_callback: Callable, in_activated_callback: Callable) -> TreeItem:
	_warnings_count += 1
	_warnings_mask_button.button_pressed = true
	ScriptUtils.call_deferred_once(_update_mask_buttons)
	return _add_item("⚠ " + in_text, in_selected_callback, in_activated_callback)


## Adds an Error item to the Alerts list, [code]in_selected_callback[/code] should
## take a [TreeItem] as  first argument
func add_error(in_text:String, in_selected_callback: Callable, in_activated_callback: Callable) -> TreeItem:
	_errors_count += 1
	_errors_mask_button.button_pressed = true
	ScriptUtils.call_deferred_once(_update_mask_buttons)
	return _add_item("⛔ " + in_text, in_selected_callback, in_activated_callback)


func _on_warnings_mask_button_toggled(in_button_pressed: bool) -> void:
	_filter_contents("⚠ ", in_button_pressed)

func _on_errors_mask_button_toggled(in_button_pressed: bool) -> void:
	_filter_contents("⛔ ", in_button_pressed)

func _filter_contents(in_prefix: String, in_visible: bool) -> void:
	const COLUMN_0 = 0
	var alert_items: Array[TreeItem] = _tree.get_root().get_children()
	for item in alert_items:
		if item.get_text(COLUMN_0).begins_with(in_prefix):
			item.visible = in_visible


func _on_close_button_pressed() -> void:
	hide()


func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	var callback: Callable = _callbacks.get(item, Callable()) as Callable
	if callback.is_valid():
		callback.call(item)


func _on_tree_item_activated() -> void:
	var item: TreeItem = _tree.get_selected()
	var callback: Callable = _activated_callbacks.get(item, Callable()) as Callable
	if callback.is_valid():
		callback.call(item)


func _update_mask_buttons() -> void:
	_warnings_mask_button.text = "⚠ " + str(_warnings_count)
	_warnings_mask_button.disabled = (_warnings_count == 0)
	_errors_mask_button.text = "⛔ " + str(_errors_count)
	_errors_mask_button.disabled = (_errors_count == 0)


func _add_item(in_text: String, in_selected_callback: Callable, in_activated_callback: Callable) -> TreeItem:
	var item: TreeItem = _tree.create_item(_tree.get_root())
	const COLUMN_0 = 0
	item.set_text(COLUMN_0, in_text)
	if in_selected_callback.is_valid():
		_callbacks[item] = in_selected_callback
	if in_activated_callback.is_valid():
		_activated_callbacks[item] = in_activated_callback
	return item
