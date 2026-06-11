extends PopupPanel


@onready var _toggles: Dictionary[Vector2, Button] = {
	Vector2(-100,  100) : %AlignHBeginVBeginButton,
	Vector2(   0,  100) : %AlignVBeginButton,
	Vector2( 100,  100) : %AlignHEndVBeginButton,
	Vector2(-100,    0) : %AlignHBeginButton,
	Vector2(   0,    0) : %AlignCenterButton,
	Vector2( 100,    0) : %AlignHEndButton,
	Vector2(-100, -100) : %AlignHBeginVEndButton,
	Vector2(   0, -100) : %AlignVEndButton,
	Vector2( 100, -100) : %AlignHEndVEndButton,
	Vector2.INF     : %CustomAlignCheckButton
}
@onready var _depth_toggles: Dictionary[float, Button] = {
	-100 : %DBeginButton,
	   0 : %DCenterButton,
	 100 : %DEndButton,
}
@onready var _depth_controls_container: HBoxContainer = %DepthControlsContainer
@onready var _depth_toggles_container: VBoxContainer = %DepthTogglesContainer
@onready var _h_custom_spin_box_slider: SpinBoxSlider = %HCustomSpinBoxSlider
@onready var _v_custom_spin_box_slider: SpinBoxSlider = %VCustomSpinBoxSlider
@onready var _d_custom_spin_box: SpinBox = %DCustomSpinBox
@onready var _d_custom_slider: VSlider = %DCustomSlider

var _box: AlignableOBB
var _parameters: AlignSelectionParameters
var _align_to_rect: Rect2

func _ready() -> void:
	_toggles[Vector2.INF].button_group.pressed.connect(_on_button_group_pressed)
	_depth_toggles[0].button_group.pressed.connect(_on_depth_button_group_pressed)
	_h_custom_spin_box_slider.value_changed.connect(_on_h_custom_spin_box_slider_value_changed)
	_v_custom_spin_box_slider.value_changed.connect(_on_v_custom_spin_box_slider_value_changed)
	_d_custom_spin_box.value_changed.connect(_on_d_custom_spin_box_value_changed)
	_d_custom_spin_box.visibility_changed.connect(_on_d_custom_spin_box_visibility_changed)
	_d_custom_spin_box.share(_d_custom_slider)
	_h_custom_spin_box_slider.hide()
	_v_custom_spin_box_slider.hide()
	_d_custom_spin_box.hide()
	visibility_changed.connect(_on_visibility_changed)
	size_changed.connect(_on_size_changed)


func popup_attached_to_control(in_control: Control) -> void:
	var popup_separation: int = 4
	var button_rect: Rect2 = in_control.get_global_rect().grow(popup_separation)
	popup_attached_to_global_rect(button_rect)


func popup_attached_to_global_rect(in_rect: Rect2) -> void:
	align_to_global_rect(in_rect)
	popup()


func align_to_global_rect(in_rect: Rect2) -> void:
	_align_to_rect = in_rect
	var screen_size: Vector2 = get_parent().get_window().size
	var desired_position: Vector2 = in_rect.end - Vector2(in_rect.size.x, 0)
	if desired_position.x + size.x > screen_size.x:
		desired_position.x -= (size.x - in_rect.size.x)
	if desired_position.y + size.y > screen_size.y:
		desired_position.y -= in_rect.size.y + size.y
	position = desired_position


func setup(out_box: AlignableOBB, out_parameters: AlignSelectionParameters) -> void:
	_box = out_box
	_parameters = out_parameters
	var alignment := Vector2(out_box.offset_ratio_h, out_box.offset_ratio_v) * 200.0
	if _toggles.has(alignment):
		_toggles[alignment].button_pressed = true
	else:
		_toggles[Vector2.INF].button_pressed = true
		_h_custom_spin_box_slider.value = alignment.x
		_v_custom_spin_box_slider.value = alignment.y
	_depth_controls_container.visible = out_parameters.is_align_depth_enabled()
	var d_alignment: float = out_box.offset_ratio_d * 200.0
	if _depth_toggles.has(d_alignment):
		_depth_toggles[d_alignment].button_pressed = true
	else:
		_d_custom_spin_box.value = d_alignment
	size = Vector2.ZERO


func _on_button_group_pressed(button: Button) -> void:
	var is_custom: bool = button == _toggles[Vector2.INF]
	_h_custom_spin_box_slider.visible = is_custom
	_v_custom_spin_box_slider.visible = is_custom
	_d_custom_spin_box.visible = is_custom and _depth_controls_container.visible
	_depth_toggles_container.visible = not is_custom
	if _box:
		if is_custom:
			_h_custom_spin_box_slider.set_value_no_signal(_box.offset_ratio_h * 200.0)
			_v_custom_spin_box_slider.set_value_no_signal(_box.offset_ratio_v * 200.0)
			_d_custom_spin_box.set_value_no_signal(_box.offset_ratio_d * 200.0)
		else:
			var offset_ratio: Vector2 = _toggles.find_key(button)
			_h_custom_spin_box_slider.set_value_no_signal(offset_ratio.x)
			_v_custom_spin_box_slider.set_value_no_signal(offset_ratio.y)
			_box.offset_ratio_h = offset_ratio.x / 200.0
			_box.offset_ratio_v = offset_ratio.y / 200.0
			var pressed_d: Button = _depth_toggles[0].button_group.get_pressed_button()
			var depth_offset_ratio: float = _depth_toggles.find_key(pressed_d)
			_box.offset_ratio_d = depth_offset_ratio / 200.0
			_parameters.request_redraw_preview()
	size = Vector2.ZERO


func _on_depth_button_group_pressed(button: Button) -> void:
	var depth_offset_ratio: float = _depth_toggles.find_key(button)
	_d_custom_spin_box.set_value_no_signal(depth_offset_ratio)
	if _box:
		_box.offset_ratio_d = depth_offset_ratio / 200.0
		_parameters.request_redraw_preview()


func _on_h_custom_spin_box_slider_value_changed(in_value: float) -> void:
	if _box:
		_box.offset_ratio_h = in_value / 200.0
		_parameters.request_redraw_preview()


func _on_v_custom_spin_box_slider_value_changed(in_value: float) -> void:
	if _box:
		_box.offset_ratio_v = in_value / 200.0
		_parameters.request_redraw_preview()


func _on_d_custom_spin_box_value_changed(in_value: float) -> void:
	if _box:
		_box.offset_ratio_d = in_value / 200.0
		_parameters.request_redraw_preview()


func _on_d_custom_spin_box_visibility_changed() -> void:
	_d_custom_slider.visible = _d_custom_spin_box.is_visible_in_tree()


func _on_visibility_changed() -> void:
	if not visible:
		_box = null


func _on_size_changed() -> void:
	if visible:
		align_to_global_rect(_align_to_rect)
