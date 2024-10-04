extends Node


signal changed()
signal resolution_scale_changed(new_scale: float)
signal scale_method_changed(new_method: Viewport.Scaling3DMode)
signal msaa2d_changed(new_mssa2d: Viewport.MSAA)
signal screen_space_aa_changed(new_screen_space_aa: Viewport.ScreenSpaceAA)


var resolution_scale: float = 1.0 : set = set_resolution_scale, get = get_resolution_scale
var scale_method: Viewport.Scaling3DMode = Viewport.SCALING_3D_MODE_FSR : 
		set = set_scale_method, get = get_scale_method
var msaa2d: Viewport.MSAA = Viewport.MSAA_8X : set = set_msaa2d, get = get_msaa2d
var screen_space_aa: Viewport.ScreenSpaceAA = Viewport.ScreenSpaceAA.SCREEN_SPACE_AA_FXAA :
		set = set_screen_space_aa, get = get_screen_space_aa

var _performance_adjuster: PerformanceAdjuster


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_performance_adjuster = get_node("PerformanceAdjuster")


func set_resolution_scale(new_resolution_scale: float) -> void:
	if new_resolution_scale == resolution_scale:
		return
	resolution_scale = new_resolution_scale
	resolution_scale_changed.emit(resolution_scale)
	changed.emit()


func get_resolution_scale() -> float:
	return resolution_scale


func set_scale_method(new_scale_method: Viewport.Scaling3DMode) -> void:
	if scale_method == new_scale_method:
		return
	scale_method = new_scale_method
	scale_method_changed.emit(scale_method)
	changed.emit()


func get_scale_method() -> Viewport.Scaling3DMode:
	return scale_method


func set_msaa2d(new_msaa2d: Viewport.MSAA) -> void:
	if msaa2d == new_msaa2d:
		return
	msaa2d = new_msaa2d
	msaa2d_changed.emit(msaa2d)
	changed.emit()


func get_msaa2d() -> Viewport.MSAA:
	return msaa2d


func set_screen_space_aa(in_screen_space_aa: Viewport.ScreenSpaceAA) -> void:
	if screen_space_aa == in_screen_space_aa:
		return
	screen_space_aa = in_screen_space_aa
	screen_space_aa_changed.emit(screen_space_aa)
	changed.emit()


func get_screen_space_aa() -> Viewport.ScreenSpaceAA:
	return screen_space_aa


# We do not want to include in our measurements cases where fps drop is caused by some heavy operation
func handle_heavy_operation() -> void:
	_performance_adjuster.handle_heavy_operation()
