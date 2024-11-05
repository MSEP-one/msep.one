@tool
class_name PeriodicTableColorPalette extends Resource

@export var _data: Dictionary = _create_default_data()
var _page: int = 1

func _init() -> void:
	_page = 1


func get_color_for_element(in_atomic_number: int) -> Color:
	return _get_property_for_element(in_atomic_number, "color")


func get_noise_color_for_element(in_atomic_number: int) -> Color:
	return _get_property_for_element(in_atomic_number, "noise_color")


func get_bond_color_for_element(in_atomic_number: int) -> Color:
	return _get_property_for_element(in_atomic_number, "bond_color")


func get_font_color_for_element(in_atomic_number: int) -> Color:
	return _get_property_for_element(in_atomic_number, "font_color")


func _get_property_for_element(in_atomic_number: int, in_property: String) -> Color:
	assert(in_atomic_number >= 1 and in_atomic_number <= PeriodicTable.MAX_ATOMIC_NUMBER,
	"Invalid atomic number %d" % in_atomic_number)
	if _data[in_atomic_number].set:
		return _data[in_atomic_number][in_property]
	# Color is unset, return fallback
	return _data[0][in_property]


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		"name": "page",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1,12,1"
	})
	_page = clamp(_page, 1, 12)
	for i in range((_page-1)*10, (_page*10), 1):
		if i > PeriodicTable.MAX_ATOMIC_NUMBER:
			break
		if i == 0:
			properties.append({
				"name": "fallback",
				"type": TYPE_STRING,
				"usage": PROPERTY_USAGE_GROUP
			})
		else:
			properties.append({
				"name": PeriodicTable.get_by_atomic_number(i).name,
				"type": TYPE_STRING,
				"usage": PROPERTY_USAGE_GROUP
			})
			properties.append({
				"name": str(i) + "/set",
				"type": TYPE_BOOL,
			})
		var show_more_properties: bool = i == 0 or _data.get(i,{}).get("set", false)
		if show_more_properties:
			properties.append({
				"name": str(i) + "/color",
				"type": TYPE_COLOR,
				"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
			})
			properties.append({
				"name": str(i) + "/noise_color",
				"type": TYPE_COLOR,
				"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
			})
			properties.append({
				"name": str(i) + "/bond_color",
				"type": TYPE_COLOR,
				"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
			})
			properties.append({
				"name": str(i) + "/font_color",
				"type": TYPE_COLOR,
				"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
			})
		{
			"name": str(i) + "/set",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT, # See above assignment.
			"hint": PROPERTY_HINT_NONE,
			"hint_string": ""
		}
	return properties

func _set(in_property: StringName, in_value: Variant) -> bool:
	if in_property == &"page":
		if _page != clamp(in_value, 1, 12):
			_page = clamp(in_value, 1, 12)
			notify_property_list_changed()
		return true
	if in_property.count("/") != 1:
		return false
	var atomic_number: int = in_property.split("/")[0].to_int()
	var subproperty: String = in_property.split("/")[1]
	if not subproperty in ["set", "color", "noise_color", "bond_color", "font_color"]:
		return false
	assert(_data.has(atomic_number), "Missing atomic number %d in _data" % atomic_number)
	var notify_list_changed: bool = subproperty == "set" and in_value != _data[atomic_number].get("set", false)
	_data[atomic_number][subproperty] = in_value
	if Engine.is_editor_hint() and subproperty == "set" and in_value == false:
		var element_data: Dictionary = _data[atomic_number]
		for to_erase: String in ["color","noise_color","bond_color","font_color"]:
			element_data.erase(to_erase)
	if Engine.is_editor_hint() and subproperty == "color":
		var color: Color = in_value as Color
		var luminisence: float = (color.r + color.g + color.b) / 3.0
		if not _data[atomic_number].has("noise_color"):
			var noise_color: Color
			if luminisence > 0.5:
				noise_color = color * 0.7
			else:
				noise_color = (color * 1.5).clamp()
			noise_color.a = 1.0
			set(str(atomic_number) + "/noise_color", noise_color)
		if not _data[atomic_number].has("bond_color"):
			set(str(atomic_number) + "/bond_color", color)
		if not _data[atomic_number].has("font_color"):
			if luminisence > 0.5:
				set(str(atomic_number) + "/font_color", Color.BLACK)
			else:
				set(str(atomic_number) + "/font_color", Color.WHITE)
		notify_list_changed = true
	if notify_list_changed:
		notify_property_list_changed()
	return true


func _get(in_property: StringName) -> Variant:
	if in_property == &"page":
		return _page
	if in_property.count("/") != 1:
		return null
	var atomic_number: int = in_property.split("/")[0].to_int()
	var subproperty: String = in_property.split("/")[1]
	if not subproperty in ["set", "color", "noise_color", "bond_color", "font_color"]:
		return null
	assert(_data.has(atomic_number), "Missing atomic number %d in _data" % atomic_number)
	return _data.get(atomic_number, {}).get(subproperty, null)


func _create_default_data() -> Dictionary:
	var default: Dictionary = {
		0: {
			"color": Color.WHITE,
			"noise_color": Color.DARK_GRAY,
			"bond_color": Color.GRAY,
			"font_color": Color.BLACK,
		}
	}
	for i in range(1, PeriodicTable.MAX_ATOMIC_NUMBER+1):
		default[i] = {"set" = false}
	return default


func _create_msep_palette() -> Dictionary:
	var msep_palette: Dictionary = {
		0: {
			"color": Color.WHITE,
			"noise_color": Color.DARK_GRAY,
			"bond_color": Color.GRAY,
			"font_color": Color.BLACK,
		}
	}
	for i in range(1, PeriodicTable.MAX_ATOMIC_NUMBER+1):
		var data: ElementData = PeriodicTable.get_by_atomic_number(i)
		msep_palette[i] = {
			"set": true,
			"color": data.color,
			"noise_color": data.noise_color,
			"bond_color": data.bond_color,
			"font_color": data.font_color,
		}
	return msep_palette
