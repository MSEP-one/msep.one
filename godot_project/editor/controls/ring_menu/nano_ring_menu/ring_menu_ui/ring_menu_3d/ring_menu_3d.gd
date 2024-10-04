class_name RingMenu3D extends Node3D
# Class responsible for 3d representation of the RingMenu
# It also propagates click events through signals

const LIGHT_LAYER_REALTIME = 3
const LIGHT_LAYER_HIGHLIGHT = 20
const MIN_MSEC_DELAY_BETWEEN_LVL_TRANSITIONS: int = 625


signal close_requested
signal back_requested
signal btn_clicked(in_btn_action: RingMenuAction)
signal tooltip_changed(in_tooltip: String)


enum ButtonAnimationType {
	NONE, POP, MILD_CLOCKWISE, MILD_COUNTER_CLOCKWISE, ICON_ROTATION_CHANGE, GRADIENT_FROM_RIGHT_TO_LEFT
}

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")
const NextPageTexture = preload("res://editor/controls/ring_menu/nano_ring_menu/ring_menu_ui/ring_menu_3d/ring_menu_button/assets/arrow_right.png")
const PrevPageTexture = preload("res://editor/controls/ring_menu/nano_ring_menu/ring_menu_ui/ring_menu_3d/ring_menu_button/assets/arrow_left.png")

const MAX_NMB_OF_BUTTONS_PER_PAGE: int = 9
const MAX_NMB_OF_ACTIONS_PER_MULTIPAGE_PAGE: int = MAX_NMB_OF_BUTTONS_PER_PAGE - 2
const BTN_IDX_PREV_PAGE: int = 0
const BTN_IDX_NEXT_PAGE: int = 8
const BTN_NAME_PREVIOUS_PAGE: String = "Previous Page"
const BTN_NAME_NEXT_PAGE: String = "Next Page"
const NMB_OF_BTNS_AT_PAGE_TO_BTN_START_IDX: Dictionary = {
	1 : 4,
	2 : 4,
	3 : 3,
	4 : 3,
	5 : 2,
	6 : 1,
	7 : 1,
	8 : 0,
	9 : 0
}

var _buttons_holder: Node3D
var _circle: RingInnerCircle
var _level_indicator_animator: AnimationPlayer
var _back_button: SideButton
var _close_button: SideButton
var _ring_real_time_visuals: RingRealTimeVisuals

var _current_lvl: int = 0
var _nmb_of_pages: int = 1
var _current_page: int = 0
var _current_level_actions: Array[RingMenuAction]

var _lvl_change_queue: Array[LvlChangeData] = []
var _last_lvl_transition_at_time: int = Time.get_ticks_msec()


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_buttons_holder = $buttons
		_circle = $RingInnerCircle
		_level_indicator_animator = $LevelIndicatorAnimator
		_back_button = $BackButton
		_close_button = $CloseButton
		_ring_real_time_visuals = $RingRealTimeVisuals
	if in_what == NOTIFICATION_READY:
		assert(NMB_OF_BTNS_AT_PAGE_TO_BTN_START_IDX.size() == MAX_NMB_OF_BUTTONS_PER_PAGE, "Please adjust button mapping")
		hide()
		_level_indicator_animator.play("level_0")
		_circle.title_refresh_requested.connect(_on_circle_title_refresh_requested)
		for button in _buttons_holder.get_children():
			button.hovered.connect(_on_button_hovered)
			button.focused.connect(_on_button_focused)
			button.unfocused.connect(_on_button_unfocused)
			button.clicked.connect(_on_button_clicked.bind(button))


func _on_button_focused(_in_name: String, in_tooltip: String) -> void:
	EditorSfx.rollover()
	tooltip_changed.emit(in_tooltip)


func _on_button_hovered(in_name: String, in_tooltip: String, in_button_enabled: bool) -> void:
	_circle.set_title(in_name)
	_circle.set_dimmed(not in_button_enabled)
	tooltip_changed.emit(in_tooltip)


func _on_button_unfocused(_in_name: String) -> void:
	_circle.set_title("")
	tooltip_changed.emit("")


func _on_button_clicked(in_button: RingMenuButton) -> void:
	if _nmb_of_pages > 1:
		if in_button.get_index() == BTN_IDX_PREV_PAGE:
			_change_page_prev()
			return
		if in_button.get_index() == BTN_IDX_NEXT_PAGE:
			_change_page_next()
			return
	
	var action: RingMenuAction = _get_related_action_for_button_with_index(in_button.get_index(),
			_current_page, _current_level_actions)
	btn_clicked.emit(action)
	EditorSfx.mouse_down()


func _on_circle_title_refresh_requested() -> void:
	var new_title: String = ""
	for button: RingMenuButton in _buttons_holder.get_children():
		if button.is_mouse_hovering():
			new_title = button.get_icon_name()
			break
	_circle.set_title(new_title)


func _input(event: InputEvent) -> void:
	_ring_real_time_visuals.input(event)


func disable_back_button() -> void:
	_back_button.disable()
	_back_button.dissapear(0.25)


func is_point_inside_exit_btn(in_point: Vector2) -> bool:
	return _close_button.is_point_inside(in_point)


func is_point_inside_back_btn(in_point: Vector2) -> bool:
	if not _back_button.is_active():
		return false
	return _back_button.is_point_inside(in_point)


func refresh_button_availability() -> void:
	_change_page(_current_page, ButtonAnimationType.NONE, _current_level_actions)


func popup(in_category_name: String, in_actions: Array[RingMenuAction], in_deepness: int) -> void:
	
	#
	var menu_changed: bool = (in_actions != _current_level_actions)
	_current_level_actions = in_actions
	_ring_real_time_visuals.reset(_buttons_holder)
	_current_lvl = in_deepness
	
	#
	var nmb_of_entries: int = in_actions.size()
	if nmb_of_entries <= MAX_NMB_OF_BUTTONS_PER_PAGE:
		_nmb_of_pages = 1
	else:
		_nmb_of_pages = ceil(float(nmb_of_entries) / MAX_NMB_OF_ACTIONS_PER_MULTIPAGE_PAGE)
	if (menu_changed):
		_current_page = 0
	
	show()
	_circle.popup(in_category_name)
	
	#
	_close_button.popup(0.3)
	_close_button.enable()
	
	#
	for button in _buttons_holder.get_children():
		button.prepare_for_usage()
	
	_back_button.prepare_for_usage()
	_close_button.prepare_for_usage()
	
	#
	_change_page(_current_page, ButtonAnimationType.POP, in_actions)


func lvl_up(in_category_name: String, in_actions: Array[RingMenuAction]) -> void:
	var is_category_already_queued: bool = not _lvl_change_queue.is_empty() and \
			_lvl_change_queue.back().category_name == in_category_name
	if is_category_already_queued:
		return
	_lvl_change_queue.append(LvlChangeData.new(LvlChangeData.Type.LVL_UP, in_category_name, in_actions, false))


func lvl_down(in_category_name: String, in_actions: Array[RingMenuAction], in_is_top_level: bool) -> void:
	var is_category_already_queued: bool = not _lvl_change_queue.is_empty() and \
			_lvl_change_queue.front().category_name == in_category_name
	if is_category_already_queued:
		return
	_lvl_change_queue.append(LvlChangeData.new(LvlChangeData.Type.LVL_DOWN, in_category_name, in_actions, in_is_top_level))


func update(delta: float) -> void:
	_ring_real_time_visuals.update(_buttons_holder, delta)
	_check_lvl_transition()


func _check_lvl_transition() -> void:
	if _lvl_change_queue.is_empty():
		return
	
	var time_since_last_transition: int = Time.get_ticks_msec() - _last_lvl_transition_at_time
	var enough_time_passed_since_last_transition: bool = time_since_last_transition > MIN_MSEC_DELAY_BETWEEN_LVL_TRANSITIONS
	if not enough_time_passed_since_last_transition:
		return
	
	var lvl_change_data: LvlChangeData = _lvl_change_queue.pop_front()
	if lvl_change_data.type == LvlChangeData.Type.LVL_UP:
		_change_lvl_up(lvl_change_data.category_name, lvl_change_data.actions)
	if lvl_change_data.type == LvlChangeData.Type.LVL_DOWN:
		_change_lvl_down(lvl_change_data.category_name, lvl_change_data.actions, lvl_change_data.is_top_lvl)
	

func _change_lvl_up(in_category_name: String, in_actions: Array[RingMenuAction]) -> void:
	
	#
	_last_lvl_transition_at_time = Time.get_ticks_msec()
	
	#
	_current_level_actions = in_actions
	_current_page = 0
		
	#
	var nmb_of_entries: int = in_actions.size()
	if nmb_of_entries <= MAX_NMB_OF_BUTTONS_PER_PAGE:
		_nmb_of_pages = 1
	else:
		_nmb_of_pages = ceil(float(nmb_of_entries) / float(MAX_NMB_OF_ACTIONS_PER_MULTIPAGE_PAGE))
	_current_lvl += 1
	
	#
	_circle.lvl_up(in_category_name)
	_change_page(0,ButtonAnimationType.ICON_ROTATION_CHANGE, in_actions)
	_increase_lvl_highlight(_current_lvl)

	#
	if not _back_button.is_active():
		_back_button.pop_counter_clockwise(0.65)
		_back_button.enable()


func _increase_lvl_highlight(new_lvl: int) -> void:
	if new_lvl == 1:
		_level_indicator_animator.play("level_1")
	if new_lvl == 2:
		_level_indicator_animator.play("level_2")


func _change_lvl_down(in_category_name: String, in_actions: Array[RingMenuAction], in_is_top_level: bool) -> void:
	
	#
	_last_lvl_transition_at_time = Time.get_ticks_msec()
	
	#
	_current_level_actions = in_actions
	_current_page = 0
	
	#
	var nmb_of_entries: int = in_actions.size()
	if nmb_of_entries <= MAX_NMB_OF_BUTTONS_PER_PAGE:
		_nmb_of_pages = 1
	else:
		_nmb_of_pages = ceil(float(nmb_of_entries) / float(MAX_NMB_OF_ACTIONS_PER_MULTIPAGE_PAGE))
	
	#
	_current_lvl -= 1
	_circle.lvl_down(in_category_name)
	_change_page(0, ButtonAnimationType.GRADIENT_FROM_RIGHT_TO_LEFT, in_actions)
	_lower_lvl_highlight(_current_lvl)
	
	#
	if in_is_top_level:
		disable_back_button()


func _lower_lvl_highlight(new_lvl: int) -> void:
	if new_lvl == 1:
		_level_indicator_animator.play("lower_to_level_1")
	if new_lvl == 0:
		_level_indicator_animator.play("lower_to_level_0")


func _on_close_button_clicked() -> void:
	close_requested.emit()
	EditorSfx.mouse_down()


func _on_back_button_clicked() -> void:
	var is_top_level_already_queued: bool = not _lvl_change_queue.is_empty() and _lvl_change_queue.back().is_top_lvl
	var is_top_level: bool = _current_lvl == 0
	if is_top_level or is_top_level_already_queued:
		return
	back_requested.emit()
	EditorSfx.mouse_down()


func _change_page_next() -> void:
	var new_page: int = _current_page + 1
	if new_page >= _nmb_of_pages:
		new_page = 0
	_change_page(new_page, ButtonAnimationType.MILD_CLOCKWISE, _current_level_actions)
	_circle.indicate_next_page()


func _change_page_prev() -> void:
	var new_page: int = _current_page - 1
	if new_page < 0:
		new_page = _nmb_of_pages - 1
	_change_page(new_page, ButtonAnimationType.MILD_COUNTER_CLOCKWISE, _current_level_actions)
	_circle.indicate_prev_page()


func _change_page(in_new_page: int, in_button_animation_type: ButtonAnimationType, in_actions: Array[RingMenuAction]) -> void:
	_current_page = in_new_page
	
	for button_idx in range(_buttons_holder.get_child_count()):
		var button: RingMenuButton = _buttons_holder.get_child(button_idx)
		var icon: RingMenuIcon = _get_icon_for_button_with_index(button_idx, in_new_page, in_actions)
		var btn_name: String = _get_name_for_button_with_index(button_idx, in_new_page, in_actions)
		var btn_tooltip: String = _get_tooltip_for_button_with_index(button_idx, in_new_page, in_actions)
		var should_be_disabled: bool = icon == null
		var is_available: bool = _get_availability_for_button_with_index(button_idx, in_new_page, in_actions)
		should_be_disabled = should_be_disabled or not is_available
	
		var activation_delay: float = 0.0
		if in_button_animation_type == ButtonAnimationType.POP:
			var btn_delay: float =  0.03 + button_idx * 0.02
			button.popup(btn_delay, icon, btn_name, btn_tooltip)
			activation_delay = 0.03 + button_idx * 0.02
		
		if in_button_animation_type == ButtonAnimationType.MILD_CLOCKWISE:
			var btn_delay: float =  0.03 + button_idx * 0.030
			if button_idx != BTN_IDX_PREV_PAGE and button_idx != BTN_IDX_NEXT_PAGE:
				button.change_icon_mild(btn_delay, icon, btn_name, btn_tooltip)
			activation_delay = btn_delay
			
		if in_button_animation_type == ButtonAnimationType.MILD_COUNTER_CLOCKWISE:
			var btn_delay: float =  0.03 + (BTN_IDX_NEXT_PAGE - button_idx) * 0.030
			activation_delay = btn_delay
			if button_idx != BTN_IDX_PREV_PAGE and button_idx != BTN_IDX_NEXT_PAGE:
				button.change_icon_mild(btn_delay, icon, btn_name, btn_tooltip)
		
		if in_button_animation_type == ButtonAnimationType.ICON_ROTATION_CHANGE:
			activation_delay = 0.25
			button.change_icon(activation_delay, icon, btn_name, btn_tooltip)
		
		if in_button_animation_type == ButtonAnimationType.GRADIENT_FROM_RIGHT_TO_LEFT:
			var btn_delay: float =  0.03 + (BTN_IDX_NEXT_PAGE - button_idx) * 0.045
			activation_delay = btn_delay
			button.change_icon_mild(btn_delay, icon, btn_name, btn_tooltip)
		
		if should_be_disabled:
			button.disable(activation_delay)
		else:
			button.enable(activation_delay)


func _get_related_action_for_button_with_index(in_button_idx: int, in_page: int, in_actions: Array[RingMenuAction]) -> RingMenuAction:
	var entry_idx: int = _get_entry_idx_for_button(in_button_idx, in_page, in_actions.size())
	if entry_idx == -1:
		if _nmb_of_pages > 1:
			if in_button_idx == BTN_IDX_PREV_PAGE:
				return null
			if in_button_idx == BTN_IDX_NEXT_PAGE:
				return null
		return null
	return in_actions[entry_idx]


func _get_icon_for_button_with_index(in_button_idx: int, in_page: int, in_actions: Array[RingMenuAction]) -> RingMenuIcon:
	var entry_idx: int = _get_entry_idx_for_button(in_button_idx, in_page, in_actions.size())
	if entry_idx == -1:
		if _nmb_of_pages > 1:
			if in_button_idx == BTN_IDX_PREV_PAGE:
				return RingMenuSpriteIconScn.instantiate().init(PrevPageTexture)
			if in_button_idx == BTN_IDX_NEXT_PAGE:
				return RingMenuSpriteIconScn.instantiate().init(NextPageTexture)
		return null
	return in_actions[entry_idx].get_icon()


func _get_availability_for_button_with_index(in_button_idx: int, in_page: int, in_actions: Array[RingMenuAction]) -> bool:
	var entry_idx: int = _get_entry_idx_for_button(in_button_idx, in_page, in_actions.size())
	if entry_idx == -1:
		if _nmb_of_pages > 1:
			if in_button_idx == BTN_IDX_PREV_PAGE:
				return true
			if in_button_idx == BTN_IDX_NEXT_PAGE:
				return true
		return false
	return in_actions[entry_idx].can_execute()


func _get_name_for_button_with_index(in_button_idx: int, in_page: int, in_actions: Array[RingMenuAction]) -> String:
	var entry_idx: int = _get_entry_idx_for_button(in_button_idx, in_page, in_actions.size())
	if entry_idx == -1:
		if _nmb_of_pages > 1:
			if in_button_idx == BTN_IDX_PREV_PAGE:
				return BTN_NAME_PREVIOUS_PAGE
			if in_button_idx == BTN_IDX_NEXT_PAGE:
				return BTN_NAME_NEXT_PAGE
		return ""
	return in_actions[entry_idx].get_title()

func _get_tooltip_for_button_with_index(in_button_idx: int, in_page: int, in_actions: Array[RingMenuAction]) -> String:
	var entry_idx: int = _get_entry_idx_for_button(in_button_idx, in_page, in_actions.size())
	if entry_idx == -1:
		if _nmb_of_pages > 1:
			if in_button_idx == BTN_IDX_PREV_PAGE:
				return BTN_NAME_PREVIOUS_PAGE
			if in_button_idx == BTN_IDX_NEXT_PAGE:
				return BTN_NAME_NEXT_PAGE
		return ""
	return in_actions[entry_idx].get_description()

# returns the corresponding ['entry' index from the _current_level_actions] for a button on a given page
# or -1 if the button should remain empty
func _get_entry_idx_for_button(in_button_idx: int, in_page: int, in_nmb_of_entries: int) -> int:
	var is_single_page: bool = in_nmb_of_entries <= MAX_NMB_OF_BUTTONS_PER_PAGE
	if is_single_page:
		var first_btn_idx_on_page: int = NMB_OF_BTNS_AT_PAGE_TO_BTN_START_IDX[in_nmb_of_entries]
		var last_used_btn_idx_on_page: int = in_nmb_of_entries + first_btn_idx_on_page - 1
		var entry_shift: int = in_button_idx - first_btn_idx_on_page
		var should_button_be_empty: bool = entry_shift < 0 or in_button_idx > last_used_btn_idx_on_page
		if should_button_be_empty:
			return -1
		return entry_shift
	
	if in_button_idx == BTN_IDX_PREV_PAGE:
		return -1
	
	if in_button_idx == BTN_IDX_NEXT_PAGE:
		return -1
	
	var entry_idx: int
	var page_starts_at_entry: int = in_page * MAX_NMB_OF_ACTIONS_PER_MULTIPAGE_PAGE
	var btns_nmb_at_current_page: int = min(in_nmb_of_entries - page_starts_at_entry, MAX_NMB_OF_ACTIONS_PER_MULTIPAGE_PAGE)
	var first_btn_idx_on_page: int = NMB_OF_BTNS_AT_PAGE_TO_BTN_START_IDX[btns_nmb_at_current_page]
	var current_page_entry_shift: int = in_button_idx - first_btn_idx_on_page
	if current_page_entry_shift < 0:
		return -1
	
	entry_idx = page_starts_at_entry + current_page_entry_shift
	if entry_idx >= in_nmb_of_entries:
		return -1
	return entry_idx


class LvlChangeData:
	enum Type{LVL_UP, LVL_DOWN}
	var type: Type
	var category_name: String
	var actions: Array[RingMenuAction]
	var is_top_lvl: bool
	
	func _init(in_type: Type, in_category_name: String, in_actions: Array[RingMenuAction], in_is_top_lvl: bool) -> void:
		type = in_type
		category_name = in_category_name
		actions = in_actions
		is_top_lvl = in_is_top_lvl
	
