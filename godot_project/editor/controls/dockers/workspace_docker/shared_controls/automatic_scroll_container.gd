extends ScrollContainer
class_name AutomaticScrollContainer


@export var max_size := Vector2i(150, 200)

var _main_container: Container
var _extra_margin: Vector2

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		if _main_container == null:
			_main_container = get_child(0)
			_main_container.visibility_changed.connect(_update)
			_main_container.resized.connect(_update)
			
			var stylebox: StyleBox = get_theme_stylebox(&"panel")
			_extra_margin.x = stylebox.content_margin_left + stylebox.content_margin_right
			_extra_margin.y = stylebox.content_margin_top + stylebox.content_margin_bottom
			
	if what == NOTIFICATION_READY:
		_update()


func _update() -> void:
	if not _main_container.is_visible_in_tree():
		return
	var child_size: Vector2 = _main_container.get_combined_minimum_size()
	child_size += _extra_margin
	if horizontal_scroll_mode != SCROLL_MODE_DISABLED:
		custom_minimum_size.x = min(child_size.x, max_size.x)
	
	if vertical_scroll_mode != SCROLL_MODE_DISABLED:
		custom_minimum_size.y = min(child_size.y, max_size.y)
	
	size = get_combined_minimum_size()
