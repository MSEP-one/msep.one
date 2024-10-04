class_name NanoRingMenu extends Control

const CONTEXT_MAIN: StringName = &"__NANO_MAIN_MENU__"
const CONTEXT_DELETE: StringName = &"__NANO_DELETE_MENU__"

signal state_level_changed(new_level: RingMenuLevel)
signal state_level_popped(previous_level: RingMenuLevel)
signal state_cleared()
signal closed()

var _state_context: StringName = CONTEXT_MAIN
var _state: RingMenuState: get = _get_state_for_current_context
var _context_to_state_map: Dictionary = {} # [StringName,RingMenuState]

var _ring_menu_ui: RingMenuUI


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_ring_menu_ui = $RingMenuUI
	if what == NOTIFICATION_READY:
		# Note: Unlike `close()`, just playing the animation in the internal _ring_menu_ui
		#+node will avoid playing a Sfx
		_ring_menu_ui.animate_hide()
		hide()


func _on_button_back_pressed() -> void:
	pop_level()
	EditorSfx.mouse_down()


func _on_button_close_pressed() -> void:
	hide()
	EditorSfx.mouse_down()


func refresh_button_availability() -> void:
	if !is_empty():
		_ring_menu_ui.refresh_button_availability()


## NanoRingMenu can contain many RingMenuState for different purposes
## setting the context swaps the current state, default state has an
## empty context [code]StringName()[/code]
func set_context(in_context: StringName) -> void:
	_state_context = in_context


func get_current_context() -> StringName:
	return _state_context


func is_active() -> bool:
	return _ring_menu_ui.is_active()


func is_empty(in_optional_context := StringName()) -> bool:
	var state: RingMenuState = _state
	if in_optional_context != StringName():
		state = _get_state_for_context_ensured(in_optional_context)
	return true if state == null else state.is_empty()


func is_top_level() -> bool:
	return _state.is_top_level()


func is_current_level(in_level: RingMenuLevel, in_optional_context := StringName()) -> bool:
	assert(in_level, "p_level cannot be null")
	var state: RingMenuState = _state
	if in_optional_context != StringName():
		state = _get_state_for_context_ensured(in_optional_context)
	if !is_instance_valid(state) or state.is_empty() or !is_instance_valid(state.get_current_level()):
		return false
	return state.get_current_level().get_instance_id() == in_level.get_instance_id()


func get_current_level(in_optional_context := StringName()) -> RingMenuLevel:
	var state: RingMenuState = _state
	if in_optional_context != StringName():
		state = _get_state_for_context_ensured(in_optional_context)
	if !is_instance_valid(state) or state.is_empty():
		return null
	return state.get_current_level()


func add_level(level: RingMenuLevel) -> void:
	if not _state.is_empty():
		var current_lvl_title: String = _state.get_current_level().get_title()
		var is_lvl_already_added: bool = current_lvl_title == level.get_title()
		if is_lvl_already_added:
			return
	
	var need_to_lvl_up: bool = not _state.is_empty()
	_state.push(level)
	state_level_changed.emit(level)
	
	if need_to_lvl_up:
		var current_lvl: RingMenuLevel  = _state.get_current_level()
		var current_lvl_actions: Array[RingMenuAction] = current_lvl.get_actions()
		var category_name: String = current_lvl.get_title()
		_ring_menu_ui.lvl_up(category_name, current_lvl_actions)


func pop_level() -> void:
	if is_top_level():
		return
	_load_previous_level()


func clear() -> void:
	_state.clear()
	state_cleared.emit()


func _load_previous_level() -> void:
	var popped_level: RingMenuLevel = _state.pop()
	if popped_level != null:
		state_level_popped.emit(popped_level)
		state_level_changed.emit(get_current_level())


func show_in_desired_position(in_desired_position: Vector2, in_fit_in_rect: Rect2i = Rect2i()) -> void:
	if !in_fit_in_rect.has_area():
		# Fit in the entire window
		in_fit_in_rect = Rect2i(Vector2i(), get_window().size)
	var half_size: Vector2 = _ring_menu_ui.size / 2.0
	var pos: Vector2 = in_desired_position
	pos.x = clamp(pos.x, in_fit_in_rect.position.x + half_size.x, in_fit_in_rect.end.x - half_size.x)
	pos.y = clamp(pos.y, in_fit_in_rect.position.y + half_size.y, in_fit_in_rect.end.y - half_size.y)
	var current_lvl: RingMenuLevel = _state.get_current_level()
	var current_lvl_actions: Array[RingMenuAction] = current_lvl.get_actions()
	var category_name: String = current_lvl.get_title()
	_ring_menu_ui.popup_at_position(pos, category_name, current_lvl_actions, _state.get_deepness())
	_ring_menu_ui.show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ring_menu_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	EditorSfx.open_menu()
	show()


func close() -> void:
	if is_active():
		_ring_menu_ui.animate_hide()
		EditorSfx.close_menu()
		closed.emit()


func update(in_delta: float) -> void:
	_ring_menu_ui.update(in_delta)


func _get_state_for_current_context() -> RingMenuState:
	return _get_state_for_context_ensured(_state_context)


func _get_state_for_context_ensured(in_context: StringName) -> RingMenuState:
	assert(in_context != StringName(), "Invalid context name")
	if !_context_to_state_map.has(in_context):
		_context_to_state_map[in_context] = RingMenuState.new()
	return _context_to_state_map[in_context]


func _get_state_for_context_dont_create(in_context: StringName) -> RingMenuState:
	assert(in_context != StringName(), "Invalid context name")
	return _context_to_state_map.get(in_context, null)


func _input(event: InputEvent) -> void:
	if not _ring_menu_ui.is_active():
		return
	
	if event.is_action_pressed(&"close_ring_menu") or event.is_action_pressed(&"toggle_ring_menu"):
		# Workaround, it's needed because RingMenuInputHandler is not receiving any inputs from 
		# NanoRing viewport after migration to Godot 4.1
		close()
		return

	if not event is InputEventMouseButton:
		return

	if event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
		if not event.is_pressed():
			return
		if _ring_menu_ui.is_active():
			close()

	if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
		if not event.is_pressed():
			return
		if not _ring_menu_ui.is_point_inside_ring(event.position):
			close()


func _on_ring_menu_ui_deactivated() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_menu_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_ring_menu_ui_button_clicked(in_action: RingMenuAction) -> void:
	in_action.execute()


func _on_ring_menu_ui_back_clicked() -> void:
	assert(not is_top_level(), "It should not be possible to click back when ring is at top level")
	pop_level()
	
	var current_lvl: RingMenuLevel  = _state.get_current_level()
	var current_lvl_actions: Array[RingMenuAction] = current_lvl.get_actions()
	var category_name: String = current_lvl.get_title()
	_ring_menu_ui.lvl_down(category_name, current_lvl_actions, is_top_level())
