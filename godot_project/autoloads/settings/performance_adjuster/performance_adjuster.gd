class_name PerformanceAdjuster extends Node

const LOWEST_RESOLUTION_SCALE: float = 0.65
const MAX_RESOLUTION_SCALE: float = 1.0

const NMB_OF_MEASUREMENTS: int = 25
const LOWER_QUALITY_BELOW_FPS: int = 30
const IMPROVE_QUALITY_ABOVE_FPS: int = 55
const ACCEPTABLE_DEVIATION_FROM_ENGINE_FPS_REPORT: float = 0.2


var _measurements: Array[float] = []
var _heavy_operation_in_current_frame: bool = false


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_reset_measurements()
		set_process_priority(Constants.ProcessPriority.LOWEST)


func _reset_measurements() -> void:
	_measurements.clear()
	for i in range(NMB_OF_MEASUREMENTS):
		_measurements.append(LOWER_QUALITY_BELOW_FPS + 1)


func handle_heavy_operation() -> void:
	_heavy_operation_in_current_frame = true


# The content of this function is a result engine limitations as for 4.1:
# It's impossible to reliably get the duration that took to render current frame due to:
# 1. Engine.get_frames_per_second() is updated periodically around once every second
# 2. Doing manual measurement or using delta results in sporadic edge cases where measurement is
#   abnormally small (suggesting there was a frame that rendered 100x or even 1000x quicker then others)
func _process(delta: float) -> void:
	if _heavy_operation_in_current_frame:
		# skip frame from auto performance adjustement - there was heavy operation happening in this frame,
		# it's expected for nmb of fps to be lower
		_heavy_operation_in_current_frame = false
		return
	
	if delta == 0.0:
		# Guard against potential delta time issue that was observed in pre-4.0, where delta times 
		# entering 'process' were sometimes == 0.0
		# Since it's easy to observe abnormally small delta times when system is overloaded this
		# feels like a good thing to do
		return
	
	var current_frame_fps: float = 1.0 / delta
	var engine_reported_fps: float = Engine.get_frames_per_second()
	var threshold: float = engine_reported_fps * ACCEPTABLE_DEVIATION_FROM_ENGINE_FPS_REPORT
	var manual_measurement_and_engine_reporting_agrees := is_similar(current_frame_fps, engine_reported_fps, threshold)
	if not manual_measurement_and_engine_reporting_agrees:
		# it's better to skip the measurement when it's unlikely it represents actual state of the application
		# (our logic cannot agree with engine reporting, none separatelly is guaranted to give good
		# values but when they agree the measurement is very likely)
		return
	
	var avg_measurement: float = 0.0
	for measurement in _measurements:
		avg_measurement += measurement
	avg_measurement = avg_measurement / _measurements.size()
	
	var need_to_improve_quality: bool = round(avg_measurement) > IMPROVE_QUALITY_ABOVE_FPS
	var need_to_lower_quality: bool = round(avg_measurement) < LOWER_QUALITY_BELOW_FPS
	if need_to_lower_quality:
		_lower_quality(avg_measurement)
	if need_to_improve_quality:
		_improve_quality()
		
	_measurements.pop_front()
	_measurements.append(current_frame_fps)


func is_similar(in_val1: float, in_val2: float, threshold: float) -> bool:
	return abs(in_val1 - in_val2) < threshold


func _lower_quality(in_measurement: float) -> void:
	var resolution_change_step: float = 0.01
	if in_measurement < LOWER_QUALITY_BELOW_FPS * 0.33:
		resolution_change_step = 0.1
	elif in_measurement < LOWER_QUALITY_BELOW_FPS * 0.5:
		resolution_change_step = 0.08
	elif in_measurement < LOWER_QUALITY_BELOW_FPS * 0.7:
		resolution_change_step = 0.05
	elif in_measurement < LOWER_QUALITY_BELOW_FPS * 0.85:
		resolution_change_step = 0.025
		
	if Settings.scale_method == Viewport.Scaling3DMode.SCALING_3D_MODE_FSR:
		# Settings.msaa2d do not work together with SCALING_3D_MODE_FSR
		# TODO: After migration to 4.2 check if this is needed, could not reproduce on 4.2
		if Settings.msaa2d != Viewport.MSAA_DISABLED:
			Settings.msaa2d = Viewport.MSAA_DISABLED
	
	if Settings.screen_space_aa != Viewport.ScreenSpaceAA.SCREEN_SPACE_AA_DISABLED:
		# for lower resolution scales there is no need to add 'blurriness', it's already blurred by nature
		Settings.screen_space_aa = Viewport.ScreenSpaceAA.SCREEN_SPACE_AA_DISABLED
	
	if Settings.resolution_scale > LOWEST_RESOLUTION_SCALE:
		Settings.resolution_scale = max(LOWEST_RESOLUTION_SCALE, Settings.resolution_scale - resolution_change_step)


func _improve_quality() -> void:
	
	if Settings.resolution_scale == MAX_RESOLUTION_SCALE:
		if Settings.screen_space_aa == Viewport.ScreenSpaceAA.SCREEN_SPACE_AA_DISABLED:
			Settings.screen_space_aa = Viewport.ScreenSpaceAA.SCREEN_SPACE_AA_FXAA
			return
		if Settings.msaa2d == Viewport.MSAA_DISABLED:
			Settings.msaa2d = Viewport.MSAA_2X
			return
		if Settings.msaa2d == Viewport.MSAA_2X:
			Settings.msaa2d = Viewport.MSAA_4X
			return
		if Settings.msaa2d == Viewport.MSAA_4X:
			Settings.msaa2d = Viewport.MSAA_8X
			return
	
	if Settings.resolution_scale != MAX_RESOLUTION_SCALE:
		var resolution_change_step: float = 0.005
		Settings.resolution_scale = min(MAX_RESOLUTION_SCALE, Settings.resolution_scale + resolution_change_step)

