class_name RingMenuUI extends SubViewportContainer


signal button_clicked(in_btn_action: RingMenuAction)
signal deactivated()
signal back_clicked


const RING_RADIUS_IN_PIXELS_SQR = 210 * 210
# To prevent pushing ring out of the viewport, when window becomes too small.
const SIDE_OFFSET: Vector2 = Vector2(250.0, 250.0)

var _initial_position: Vector2 = Vector2.ZERO
var _initial_size: Vector2 = Vector2.ZERO
var _camera: Camera3D
var _ring_menu: RingMenu3D
var _subviewport: SubViewport
var _fadeAnimator: AnimationPlayer


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_camera = $SubViewport/Camera3D
		_ring_menu = $SubViewport/RingMenu3D
		_subviewport = $SubViewport
		_fadeAnimator = $FadeAnimator as AnimationPlayer
		_ring_menu.tooltip_changed.connect(_on_ring_menu_tooltip_changed)


func _on_ring_menu_tooltip_changed(in_tooltip: String) -> void:
	tooltip_text = in_tooltip


func is_active() -> bool:
	return _ring_menu.is_visible_in_tree() and (_fadeAnimator.current_animation == &"fade_in" or modulate.a >= 0.95)


func is_point_inside_ring(in_point: Vector2) -> bool:
	var sqr_dst: float = get_rect().get_center().distance_squared_to(in_point)
	var is_inside_ring: bool = sqr_dst < RING_RADIUS_IN_PIXELS_SQR
	if is_inside_ring:
		return true

	if _ring_menu.is_point_inside_exit_btn(in_point - global_position):
		return true

	if _ring_menu.is_point_inside_back_btn(in_point - global_position):
		return true

	return false


func refresh_button_availability() -> void:
	_ring_menu.refresh_button_availability()


func popup_at_position(in_pop_position: Vector2, in_category_name: String,
			in_actions: Array[RingMenuAction], in_deepness: int) -> void:
	_subviewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_subviewport.gui_disable_input = false
	_subviewport.physics_object_picking = true
	_fadeAnimator.play("fade_in")
	var pop_position: Vector2 = in_pop_position + get_rect().size / -2.0
	set_position(pop_position)
	_ring_menu.popup(in_category_name, in_actions, in_deepness)
	_initial_position = position
	_initial_size = get_viewport_rect().size
	if !get_tree().root.size_changed.is_connected(_on_viewport_size_changed):
		get_tree().root.size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	keep_ring_in_bounds()


func keep_ring_in_bounds() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	var new_position: Vector2 = _initial_position + viewport_rect.size - _initial_size
	var half_size: Vector2 = size * .5
	var new_reference_position: Vector2 = new_position + half_size
	if viewport_rect.position.x + SIDE_OFFSET.x < new_reference_position.x:
		position.x = new_position.x
	else:
		position.x = SIDE_OFFSET.x - half_size.x
	
	if viewport_rect.position.y + SIDE_OFFSET.y < new_reference_position.y:
		position.y = new_position.y
	else:
		position.y = SIDE_OFFSET.y - half_size.y


func animate_hide() -> void:
	_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_subviewport.gui_disable_input = true
	_subviewport.physics_object_picking = false
	_fadeAnimator.play("fade_out")
	deactivated.emit()
	if get_tree().root.size_changed.is_connected(_on_viewport_size_changed):
		get_tree().root.size_changed.disconnect(_on_viewport_size_changed)

func _on_ring_menu_3d_close_requested() -> void:
	animate_hide()


func lvl_up(in_category_name: String, in_actions: Array[RingMenuAction]) -> void:
	_ring_menu.lvl_up(in_category_name, in_actions)


func lvl_down(in_category_name: String, in_actions: Array[RingMenuAction], in_is_top_level: bool, ) -> void:
	_ring_menu.lvl_down(in_category_name, in_actions, in_is_top_level)


func update(in_delta: float) -> void:
	_ring_menu.update(in_delta)


func _on_ring_menu_3d_btn_clicked(in_btn_action: RingMenuAction) -> void:
	button_clicked.emit(in_btn_action)


func _on_ring_menu_3d_back_requested() -> void:
	back_clicked.emit()
