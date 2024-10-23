extends CanvasLayer

const _EXPORT_DATE_SETTING_NAME: StringName = &"application/config/export_date"
const _EXPORT_DATE_SETTING_DEFAULT: String  = "yyyy-mm-dd"
const _EXPORT_COMMIT_SETTING_NAME: StringName = &"application/config/export_commit"
const _EXPORT_COMMIT_SETTING_DEFAULT: String  = ""
const _BLUR_NODEPATH: NodePath = NodePath("_blur")
const _BLUR_WHEN_VISIBLE: float = 2.0
const _BLUR_WHEN_HIDDEN: float = 0.0

signal confirmed()

var was_closed: bool = false

var _blur_background: ColorRect
var _label_date_of_build: Label
var _button_close: Button
var _blur_tween: Tween = null

var _blur: float = 0.0:
	set = _set_blur

func _init() -> void:
	hide()


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_WM_ABOUT:
		if not get_window().has_focus():
			get_window().grab_focus()
		appear()
	elif in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_blur_background = %BlurBackground
		_label_date_of_build = %LabelDateOfBuild
		_button_close = %ButtonClose
		
		var build_date: String = ProjectSettings.get_setting(
			_EXPORT_DATE_SETTING_NAME,
			_EXPORT_DATE_SETTING_DEFAULT
		)
		_label_date_of_build.text = tr(&"Build date: ") + build_date
		var commit_hash: String = ProjectSettings.get_setting(
			_EXPORT_COMMIT_SETTING_NAME,
			_EXPORT_COMMIT_SETTING_DEFAULT
		)
		if !commit_hash.is_empty():
			var short_hash: String = commit_hash.substr(0, 10)
			_label_date_of_build.text += "." + short_hash
		
		_button_close.pressed.connect(_on_button_close_pressed)


func _on_button_close_pressed() -> void:
	if is_instance_valid(_blur_tween) and _blur_tween.is_running():
		return
	was_closed = true
	disappear()
	confirmed.emit()


func appear(in_fade_time: float = 0.3) -> void:
	show()
	_button_close.grab_focus()
	if in_fade_time <= 0:
		_blur = 1
		return
	if _blur != _BLUR_WHEN_VISIBLE:
		if is_instance_valid(_blur_tween):
			_blur_tween.kill()
		_blur_tween = create_tween()
		_blur_tween.tween_property(self, _BLUR_NODEPATH, _BLUR_WHEN_VISIBLE, in_fade_time) \
			.set_trans(Tween.TRANS_CUBIC)


func disappear(in_fade_time: float = 0.3) -> void:
	if _blur != _BLUR_WHEN_HIDDEN:
		if is_instance_valid(_blur_tween):
			_blur_tween.kill()
		_blur_tween = create_tween()
		_blur_tween.tween_property(self, _BLUR_NODEPATH, _BLUR_WHEN_HIDDEN, in_fade_time) \
			.set_trans(Tween.TRANS_CUBIC)
		await _blur_tween.finished
	hide()


func _set_blur(in_blur: float) -> void:
	_blur = in_blur
	var mat := _blur_background.material as ShaderMaterial
	mat.set_shader_parameter(&"blur", in_blur)
