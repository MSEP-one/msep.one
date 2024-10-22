class_name DockerTabContainer
extends VBoxContainer

## A custom tab container specifically made for the dock area
##
## + Uses a custom tab bar (see DockerTabBar)
## + Auto hide the control when there is nothing to show


signal tab_added
signal tab_removed

var _secondary_split: HSplitContainer = null
var _old_tab_index: int = 0
var _tab_splits: Dictionary = {
		# tab_id<int> = size<float>
}

@onready var docker_tab_bar: DockerTabBar = %DockerTabBar
@onready var tab_container: TabContainer = %TabContainer


func _ready() -> void:
	tab_container.child_exiting_tree.connect(_on_child_exiting_tree)
	docker_tab_bar.tab_changed.connect(_on_tab_changed)
	resized.connect(docker_tab_bar.update)
	
	# TODO: How can I communicate more reliably?
	_secondary_split = owner.get_parent()
	if _secondary_split.name != "SecondarySplit":
		_secondary_split = null

# Region: public

## Add the control node as a new tab.
## Use this method instead of directly calling add_child() on this node.
func add_tab(control: Control, tab_name: String, tab_hidden: bool) -> void:
	tab_container.add_child(control)
	var tab_index: int = control.get_index()
	docker_tab_bar.add_tab(tab_name)
	set_tab_hidden(tab_index, tab_hidden)
	tab_added.emit(control)


## Remove the control from the tab container.
## Automatically called with the control is manually removed from the TabContainer.
func remove_tab(control: Control) -> void:
	if control.get_parent() != tab_container:
		return
	
	var tab_index: int = control.get_index()
	docker_tab_bar.remove_tab(tab_index)
	tab_container.remove_child.call_deferred(control)
	tab_removed.emit(control)


## Make visible the tab at the given index and scroll the tab bar to make
## the active tab visible
func focus_tab(tab_index: int) -> void:
	docker_tab_bar.focus_tab(tab_index)
	tab_container.current_tab = tab_index


## Same as focus_tab(), but using the control node instead of the tab index.
func focus_tab_control(control: Control) -> void:
	if control.get_parent() == tab_container:
		var index: int = control.get_index()
		focus_tab(index)


## Hides this control if there are no tabs of if they are all hidden.
## Makes it visible otherwise.
func update_visibility() -> void:
	var container_visible: bool = false
	var first_visible_tab: int = -1
	for i in tab_container.get_tab_count():
		if not tab_container.is_tab_hidden(i):
			if first_visible_tab == -1:
				first_visible_tab = i
			container_visible = true
			break
		else:
			# controls with tab hidden are also hidden
			tab_container.get_tab_control(i).hide()
	var current_control: Control = get_current_control()
	if current_control == null:
		if first_visible_tab != -1:
			focus_tab(first_visible_tab)
	elif not current_control.visible:
		focus_tab(tab_container.current_tab)
	visible = container_visible
	docker_tab_bar.update()


func has_visible_content() -> bool:
	for i in tab_container.get_tab_count():
		if not tab_container.is_tab_hidden(i):
			return true
	return false


# Region: TabContainer API replication
func get_tab_count() -> int:
	return tab_container.get_tab_count()


func get_current_tab() -> int:
	return tab_container.current_tab


func get_current_control() -> Control:
	var current_tab: int = tab_container.get_current_tab()
	return tab_container.get_tab_control(current_tab)


func set_tab_title(index: int, title: String) -> void:
	docker_tab_bar.set_tab_title(index, title)


func set_tab_hidden(index: int, tab_hidden: bool) -> void:
	tab_container.set_tab_hidden(index, tab_hidden)
	docker_tab_bar.set_tab_hidden(index, tab_hidden)


func is_tab_hidden(index: int) -> bool:
	return tab_container.is_tab_hidden(index)


# Region: private

## Called when the user clicked a tab in the docker tab bar
func _on_tab_changed(tab: int) -> void:
	tab_container.set_current_tab(tab)
	
	if _secondary_split != null:
		_tab_splits[_old_tab_index] = _secondary_split.split_offset
		_secondary_split.adjust_split(_get_split_for_tab(docker_tab_bar.tab_bar.current_tab))
	
	_old_tab_index = tab


func _get_split_for_tab(in_tab_id: int) -> int:
	const DEFAULT_SPLIT: int = 1000000
	return _tab_splits.get(in_tab_id, DEFAULT_SPLIT)


## Called when a child was manually removed from the tab container.
## Calls remove_tab to keep the tab bar in sync
func _on_child_exiting_tree(node: Node) -> void:
	if node is TabBar:
		# Ignore if it's an internal node
		return
	
	remove_tab(node)
