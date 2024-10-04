class_name DockerTabBar
extends HBoxContainer

## A custom tab bar with tab buttons for navigation.
##
## Displays arrow buttons on each side of the tabs if scrolling is possible
## in these directions.
## The TabBar is in a control node that acts as a mask, scrolling works by
## changing the TabBar x position.
## 
## Otherwise behaves like a regular TabBar.


const SCROLL_DISTANCE: float = 80.0
const SCROLL_ANIMATION_DURATION: float = 0.1

signal tab_changed


@onready var tab_bar_mask: Control = %TabBarMask
@onready var tab_bar: TabBar = %TabBar
@onready var next_button: Button = %NextButton
@onready var previous_button: Button = %PreviousButton


func _ready() -> void:
	tab_bar.clear_tabs()
	tab_bar.tab_changed.connect(_on_tab_changed)
	next_button.pressed.connect(_on_next_button_pressed)
	previous_button.pressed.connect(_on_previous_button_pressed)


## Scrolls the tab bar horizontally on mouse scroll.
## This is the same as clicking the left and right arrows.
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	# Ignore the event if the mouse is not directly over the tab bar
	if not tab_bar.get_rect().has_point(event.position):
		return
	
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			accept_event()
			if previous_button.visible:
				_on_previous_button_pressed()
		MOUSE_BUTTON_WHEEL_DOWN:
			accept_event()
			if next_button.visible:
				_on_next_button_pressed()


# Region: Public

## Updates the navigation buttons visibility and the tab bar scroll position.
func update() -> void:
	ScriptUtils.call_deferred_once(_update)


func focus_tab(index: int) -> void:
	tab_bar.current_tab = index


# TabBar API replication

func add_tab(tab_name: String) -> void:
	tab_bar.add_tab(tab_name)


func remove_tab(tab_index: int) -> void:
	if tab_index > 0 and tab_index < tab_bar.get_tab_count():
		tab_bar.remove_tab(tab_index)


func set_tab_title(index: int, title: String) -> void:
	tab_bar.set_tab_title(index, title)


func set_tab_hidden(index: int, tab_hidden: bool) -> void:
	tab_bar.set_tab_hidden(index, tab_hidden)


# Region: Private

func _update() -> void:
	# Wait for a complete frame before updating or the controls sizes and
	# positions after a resize will be outdated
	await get_tree().process_frame
	
	if tab_bar.get_tab_count() == 0:
		return
	
	if tab_bar.size.x < size.x:
		# Every tabs can fit, hide the navigation buttons
		previous_button.visible = false
		next_button.visible = false
		tab_bar.position.x = 0
		return
	
	# Tab container is too narrow, show the navigation arrows
	previous_button.visible = true
	next_button.visible = true
	
	# Showing the arrows shrinked the mask control, force the container to resort the children now.
	queue_sort()
	await sort_children
	
	# Update scroll position
	var current_tab: int = tab_bar.current_tab
	var tab_rect: Rect2 = tab_bar.get_global_transform() * tab_bar.get_tab_rect(current_tab)
	var mask_rect: Rect2 = get_global_transform() * tab_bar_mask.get_rect()
	
	if mask_rect.encloses(tab_rect): 
		# Focused tab already fully visible, ensure resizing the docker didn't 
		# create a blank space on the right of the tabs
		_scroll_tabs(0.0) 
	elif tab_rect.position.x < 0.0: 
		_scroll_tabs(-tab_rect.position.x)
	else:
		_scroll_tabs(mask_rect.end.x - tab_rect.end.x)


func _scroll_tabs(in_scroll_offset: float) -> void:
	var min_position_x: float = tab_bar_mask.size.x - tab_bar.size.x
	var max_position_x: float = 0.0
	var tab_bar_position_x: float = tab_bar.position.x + in_scroll_offset
	tab_bar_position_x = clamp(tab_bar_position_x, min_position_x, max_position_x)
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(tab_bar, "position:x", tab_bar_position_x, SCROLL_ANIMATION_DURATION)
	
	# Selectively disable the arrows if we can't scroll in that direction
	previous_button.disabled = tab_bar_position_x >= 0
	next_button.disabled = tab_bar_position_x <= min_position_x


func _on_next_button_pressed() -> void:
	_scroll_tabs(-SCROLL_DISTANCE)


func _on_previous_button_pressed() -> void:
	_scroll_tabs(SCROLL_DISTANCE)
 

func _on_tab_changed(tab: int) -> void:
	tab_changed.emit(tab)
	update()
