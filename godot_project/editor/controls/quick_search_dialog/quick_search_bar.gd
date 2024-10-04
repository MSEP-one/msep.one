class_name QuickSearchBar
extends LineEdit

# Allows the user to navigate and select items in a Tree node while the
# search bar is focused.


@export var tree: Tree


func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(tree) or not has_focus() or not event is InputEventKey:
		return
	
	if event.is_action(&"open_quick_search"):
		return # This conflicts with ui_accept so it needs to be ignored.
	
	var current_selected: TreeItem = tree.get_selected()
	if not current_selected:
		return

	if event.is_action_pressed(&"quick_search_select_next"):
		var next: TreeItem = current_selected.get_next_visible()
		if next:
			next.select(0)
	
	elif event.is_action_pressed(&"quick_search_select_prev"):
		var prev: TreeItem = current_selected.get_prev_visible()
		if prev:
			prev.select(0)
	
	elif event.is_action_pressed(&"ui_accept"):
		tree.item_activated.emit()
