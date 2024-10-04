class_name VisualMenuCategory extends VBoxContainer

var items_count: int: get = _get_items_count

@onready var title_label: Label = %TitleLabel
@onready var _item_list: ItemList = %ItemList

var _items: Array[ItemData]

func _ready() -> void:
	_item_list.item_clicked.connect(_on_item_list_item_clicked)

func add_item(in_text: String, in_icon: Texture2D = null, in_selectable: bool = true) -> int:
	var data := ItemData.new()
	data.text = in_text
	data.icon = in_icon
	data.selectable = in_selectable
	var idx: int = _item_list.add_item(in_text, in_icon, in_selectable)
	data.list_index = idx
	_items.push_back(data)
	return (_items.size()-1)


func set_item_text(in_item_id: int, in_text: String) -> void:
	assert(in_item_id >= 0 and in_item_id < items_count, "Invalid index %d in range %d" % [in_item_id, items_count])
	_items[in_item_id].text = in_text
	_update_list_item(in_item_id)


func set_item_icon(in_item_id: int, in_icon: Texture2D) -> void:
	assert(in_item_id >= 0 and in_item_id < items_count, "Invalid index %d in range %d" % [in_item_id, items_count])
	_items[in_item_id].icon = in_icon
	_update_list_item(in_item_id)


func set_item_disabled(in_item_id: int, in_disabled: bool) -> void:
	assert(in_item_id >= 0 and in_item_id < items_count, "Invalid index %d in range %d" % [in_item_id, items_count])
	_items[in_item_id].disabled = in_disabled
	_update_list_item(in_item_id)


func set_item_tooltip(in_item_id: int, in_tooltip: String) -> void:
	assert(in_item_id >= 0 and in_item_id < items_count, "Invalid index %d in range %d" % [in_item_id, items_count])
	_items[in_item_id].tooltip = in_tooltip
	_update_list_item(in_item_id)


func set_item_clicked_callback(in_item_id: int, in_clicked_callback: Callable) -> void:
	assert(in_item_id >= 0 and in_item_id < items_count, "Invalid index %d in range %d" % [in_item_id, items_count])
	_items[in_item_id].on_pressed = in_clicked_callback


## Request to hide items not matching the in_text string parameter
func filter(in_text: String) -> void:
	visible = false
	var all_visible: bool = in_text.is_empty() || title_label.text.findn(in_text) >= 0
	_item_list.clear()
	for i in range(items_count):
		_items[i].visible = all_visible or _items[i].text.findn(in_text) >= 0
		if _items[i].visible:
			_items[i].list_index = _item_list.add_item("")
			_update_list_item(i)
			visible = true
		else:
			_items[i].list_index = -1


func _update_list_item(in_item_id: int) -> void:
	assert(in_item_id >= 0 and in_item_id < items_count, "Invalid index %d in range %d" % [in_item_id, items_count])
	var data: ItemData = _items[in_item_id]
	if !data.visible or data.list_index == -1:
		return
	var idx: int = data.list_index
	_item_list.set_item_text(idx, data.text)
	_item_list.set_item_icon(idx, data.icon)
	_item_list.set_item_selectable(idx, data.selectable)
	_item_list.set_item_disabled(idx, data.disabled)
	_item_list.set_item_tooltip(idx, data.tooltip)


func _get_items_count() -> int:
	return _items.size()


func _on_item_list_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var candidates: Array[ItemData] = _items.filter(func (in_data: ItemData) -> bool:
			return in_data.list_index == index
	)
	assert(candidates.size() <= 1, "Found more than 1 candidate, this should not happen")
	if candidates.is_empty():
		return
	var activated_item: ItemData = candidates.front()
	if activated_item.on_pressed.is_valid():
		activated_item.on_pressed.call()

class ItemData:
	var list_index: int = -1
	var text: String = ""
	var icon: Texture2D = null
	var selectable: bool = true
	var disabled: bool = false
	var visible: bool = true
	var tooltip: String = ""
	var on_pressed := Callable()
