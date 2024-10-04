class_name RingMenuAtomIcon extends RingMenuIcon


const _ATOM_PREVIEW_RADIUS: float = 0.037
const _HIGHLIGHT_LIGHT_ENERGY: float = 55.0
const _HIGHLIGHT_COLOR_BOST: float = 1.5

var _preview: MeshInstance3D
var _material: ShaderMaterial
var _press_animator: AnimationPlayer
var _fade_animator: AnimationPlayer
var _label: Label

var _atomic_number: int

var _base_noise: Color
var _base_albedo: Color
var _click_noise: Color
var _click_albedo: Color
var _base_rim: float
var _base_rim_tint: float
var _click_rim: float
var _click_rim_tint: float
var _current_tween: Tween
var _spotlight: SpotLight3D


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_preview = $PreviewInstance
		_preview.material_override = _preview.material_override.duplicate()
		_material = _preview.material_override
		_press_animator = $PressAnimator
		_fade_animator = $FadeAnimator
		_label = $"PreviewInstance/2DNodeIn3DWorld/Label"
		_spotlight = $PreviewInstance/HighlightSpotLight
		_spotlight.light_cull_mask = 1 << (RingMenu3D.LIGHT_LAYER_HIGHLIGHT - 1)
		_turn_off_spotlight()


func init(in_atomic_number: int) -> RingMenuIcon:
	_atomic_number = in_atomic_number
	var data: ElementData = PeriodicTable.get_by_atomic_number(_atomic_number)
	var atom_radius: float = Representation.get_atom_radius(data, null)
	_preview.scale = Vector3(atom_radius, atom_radius, atom_radius)
	
	_base_albedo = data.color * 0.43
	_click_albedo =  data.color * 1.1
	_base_noise = data.color * 0.5
	_click_noise = data.noise_color * 1.1
	_base_rim = 0.0
	_click_rim = 0.2
	_base_rim_tint = 1.0
	_click_rim_tint = 0.5
	
	var noise_texture_id: float = 128 #turns off the noise texture (we can have only up to 16 textures in atlas)
	_material.set_shader_parameter(&"albedo", _base_albedo)
	_material.set_shader_parameter(&"noise_albedo", _base_noise)
	_material.set_shader_parameter(&"atlas_id", noise_texture_id)
	_material.set_shader_parameter(&"rim", _base_rim)
	_material.set_shader_parameter(&"rim_tint", _base_rim_tint)
	_preview.scale = Vector3.ONE * _ATOM_PREVIEW_RADIUS
	_label.text = data.symbol
	return self


func prepare_for_usage() -> void:
	_fade_animator.play(StringName("RESET"))
	_press_animator.play(StringName("RESET"))


func pop_animation() -> void:
	fade_in()


func fade_in() -> void:
	_fade_animator.play("in")
	_fade_animator.advance(0.001)
	_label.show()


func fade_out_and_queue_free() -> void:
	_fade_animator.play("out")
	_fade_animator.advance(0.001)
	_label.hide()
	await(_fade_animator.animation_finished)
	queue_free()


func focus_in() -> void:
	if not is_inside_tree():
		return
	_highlight_icon()


func focus_out() -> void:
	if not is_inside_tree():
		return
	_lowlight_icon()


func press_in() -> void:
	_press_animator.play("in")


func _highlight_icon() -> void:
	var target_albedo_color: Color =  _click_albedo
	var normalized_color: Color = _normalize_color(_click_albedo)
	_spotlight.light_color = normalized_color * _HIGHLIGHT_COLOR_BOST
	target_albedo_color = normalized_color
	_turn_on_spotlight()
	
	if is_instance_valid(_current_tween):
		_current_tween.stop()
	var tween: Tween = create_tween().set_parallel(true)
	_current_tween = tween
	
	var albedo_highlight_duration: float = 0.35
	var rim_highlight_duration: float = 0.35
	var rim_tint_highlight_duration: float = 0.35
	var light_energy_highlight_duration: float = 0.55
	tween.tween_property(_material, "shader_parameter/albedo", target_albedo_color, albedo_highlight_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_material, "shader_parameter/rim", _click_rim, rim_highlight_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_material, "shader_parameter/rim_tint", _click_rim_tint, rim_tint_highlight_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_spotlight, "light_energy", _HIGHLIGHT_LIGHT_ENERGY, light_energy_highlight_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _normalize_color(in_color: Color) -> Color:
	var maxComponent: float = max(in_color.r, in_color.g, in_color.b)
	if is_equal_approx(maxComponent, 0.0):
		return in_color
	var normalized_color: Color = in_color / maxComponent
	return normalized_color


func _turn_on_spotlight() -> void:
	_spotlight.layers = 1
	_spotlight.show()


func press_out() -> void:
	_press_animator.play("out")


func _lowlight_icon() -> void:
	if is_instance_valid(_current_tween):
		_current_tween.stop()
	var tween: Tween = create_tween().set_parallel(true)
	_current_tween = tween
	
	var target_lowlight_albedo: Color = _base_albedo
	var albedo_lowlight_duration: float = 0.35
	var rim_lowlight_duration: float = 0.45
	var rim_tint_lowlight_duration: float = 0.45
	var light_energy_lowlight_duration: float = 1.5
	var light_energy_lowlight_target: float = 0.0
	tween.tween_property(_material, NodePath("shader_parameter/albedo"), target_lowlight_albedo,
			albedo_lowlight_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_material, NodePath("shader_parameter/rim"), _base_rim, rim_lowlight_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_material, NodePath("shader_parameter/rim_tint"), _base_rim_tint,
			rim_tint_lowlight_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_spotlight, NodePath("light_energy"), light_energy_lowlight_target,
			light_energy_lowlight_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false).tween_callback(_turn_off_spotlight)


func _turn_off_spotlight() -> void:
	_spotlight.layers = 0
	_spotlight.hide()


func active() -> void:
	return


func inactive() -> void:
	return
	
