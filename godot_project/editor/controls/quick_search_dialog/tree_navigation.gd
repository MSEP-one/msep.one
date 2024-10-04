extends Tree

# Workaround
# Commit 01f877127e removed the arrow keys from the "ui_up" / "ui_down" actions
# due to a conflict with the camera controls. But the result is we can't navigate
# the UI anymore.
#
# This script is a temporary hack until we fix the root issue with the camera input handling.


func _gui_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	
	var current_selected: TreeItem = get_selected()
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
