extends Node

signal rotation_changing(dir_vec: Vector3, degrees: float, degrees_formatted_string: String)
signal rotation_ended()

const EPSILON: float = .0001
const BEHIND_GIZMO_RATIO: float = .25
const HANDLE_GIZMO_SCENE: Resource = preload("res://addons/runtimespatialgizmo/RuntimeSpatialGizmo/HandleGizmo.tscn")
# Have to do this, because draw call order is decided by Godot and can even be called arbitrary.
# So can't disable higher in the control flow, and therefore the local variables can get out of
# sync with the source. But I don't want to expose all the scoped variables from the parent to
# the child.
const TRANSFORM_INIT_ITERATION_COUNT: int = 2

# To determine if local or global transformations are active.
enum TransformMode {LOCAL, GLOBAL, ORTHO}
enum AxesMode {TRANSLATION, SCALE}
enum GrabMode {NONE, AXIS, ARC, SURFACE, SCALE, CENTER, ORTHO_Z_HANDLE, ORTHO_Z_SURFACE}
enum CollisionMode {NONE, AXIS, ARC, SURFACE, SCALE, CENTER, ORTHO_Z_HANDLE, ORTHO_Z_SURFACE}
enum GizmoState {DISABLED, ENABLED}

var input_is_allowed := true
# Use this singleton to decouple gizmo elements.
# Local and global transformation state is combined (one variable is used for both).
var mouse_hover_detected := {
	translation_axis = false,
	scale_axis = false,
	rotation_arcs = false,
	translation_surface = false,
	center_drag = false,
	ortho_z_handle = false,
	ortho_z_surface = false
}
# ability to deactive the gizmo completelly
var _is_active: bool = true
var _mouse_inside_subviewport: bool = true
var transform_init_counter: int = TRANSFORM_INIT_ITERATION_COUNT
# This is the node on which transformations are applied.
# Assign it to the node that you want to be transformed.
# If you desire multi node selection, just modify your nodes relative to this node.
# For example use this node as a parent or just read information from this node and
# apply the information on the desired set of nodes in a way that suits your requirements.
var selected_node: Node3D = null
var transform_mode: TransformMode = TransformMode.ORTHO
# Helpful to toggle between modes.
var axes_mode: AxesMode = AxesMode.TRANSLATION
# Helpful for interaction with other functionalities.
var input_is_being_consumed := false
# What is grabbed.
var grab_mode: GrabMode = GrabMode.NONE
# What is highlighted.
var collision_mode: CollisionMode = CollisionMode.NONE
# Is the gizmo currently enabled or disabled.
var gizmo_state: GizmoState = GizmoState.DISABLED
var gizmo_distance: float = 3.0
## The viewport where the transform gizmo is drawn.
var active_viewport: Viewport:
	set(v):
		if v == active_viewport:
			return
		if is_instance_valid(active_viewport) and active_viewport is SubViewport:
			var container := active_viewport.get_parent() as SubViewportContainer
			if is_instance_valid(container):
				container.mouse_entered.disconnect(_on_subviewport_container_mouse_entered)
				container.mouse_exited.disconnect(_on_subviewport_container_mouse_exited)
		active_viewport = v
		if hg.get_parent() != null:
			hg.get_parent().remove_child(hg)
		if gizmo_state == GizmoState.ENABLED:
			active_viewport.add_child(hg)
		if active_viewport is SubViewport:
			var container := active_viewport.get_parent() as SubViewportContainer
			if is_instance_valid(container):
				container.mouse_entered.connect(_on_subviewport_container_mouse_entered)
				container.mouse_exited.connect(_on_subviewport_container_mouse_exited)
				var container_rect := Rect2(Vector2.ZERO, container.size)
				_mouse_inside_subviewport = container_rect.has_point(container.get_local_mouse_position())
		else:
			_mouse_inside_subviewport = true

@onready var hg: Node3D = HANDLE_GIZMO_SCENE.instantiate()
@onready var x_axis: Node3D = hg.get_node("%X")
@onready var y_axis: Node3D = hg.get_node("%Y")
@onready var z_axis: Node3D = hg.get_node("%Z")
@onready var axis_distance: float = x_axis.position.x
## Camera that is using the active viewport.
@onready var camera_3D: Camera3D:
	get:
		if is_instance_valid(active_viewport):
			return active_viewport.get_camera_3d()
		return null


func _ready() -> void:
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	var display_gizmo: bool = FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_DISPLAY_GIZMO)
	if not display_gizmo:
		_is_active = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Manually free HandleGizmo that may not be in the tree
		#+This avoids leaks when exit the application
		if is_instance_valid(hg):
			hg.queue_free()


func _on_feature_flag_toggled(in_path: String, in_display_gizmo: bool) -> void:
	if in_path != FeatureFlagManager.FEATURE_FLAG_DISPLAY_GIZMO:
		return
	_is_active = in_display_gizmo
	set_process_input(in_display_gizmo)
	if not _is_active:
		disable_gizmo()

func _on_subviewport_container_mouse_entered() -> void:
	_mouse_inside_subviewport = true

func _on_subviewport_container_mouse_exited() -> void:
	_mouse_inside_subviewport = false


func _input(event: InputEvent) -> void:
	if gizmo_state == GizmoState.ENABLED \
		and hg != null \
		and event is InputEventMouse:
		hg.process_gizmo_input(event)
	if event is InputEventMouseButton:
		if !event.pressed:
			grab_mode = GrabMode.NONE


func is_active() -> bool:
	return _is_active


func create_state_snapshot() -> Dictionary:
	#print("gizmo transform ", hg.global_transform)
	print("selected_node.global_transform: ", selected_node.global_transform)
	return {
		"selected_node.global_transform" : selected_node.global_transform,
		#"hg.global_transform" : hg.global_transform,
	}


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	#hg.global_transform = in_snapshot["hg.global_transform"]
	#selected_node.global_transform = in_snapshot["selected_node.global_transform"]
	pass


func transform_gizmo() -> void:
	if gizmo_state == GizmoState.DISABLED:
		return
	
	if !is_instance_valid(selected_node) || !is_instance_valid(camera_3D):
		return
	var camera_to_selected_node_dir: Vector3 = (selected_node.global_position - camera_3D.global_position).normalized()
	hg.global_position = camera_3D.global_position + camera_to_selected_node_dir * gizmo_distance / max(hg.gizmo_size_ratio, EPSILON)
	
	if transform_mode == TransformMode.ORTHO:
		hg.look_at(camera_3D.global_position, \
				camera_3D.global_transform.basis.get_rotation_quaternion() * Vector3.UP)
	else:
		hg.rotation = selected_node.rotation
	
	var camera_forward: Vector3 = camera_3D.global_transform.basis.get_rotation_quaternion() * Vector3.FORWARD
	var gizmo_scale: float = camera_to_selected_node_dir.dot(camera_forward)
	hg.scale = Vector3(gizmo_scale, gizmo_scale, gizmo_scale)
	
	if transform_mode == TransformMode.LOCAL:
		if selected_node.scale.x < .0:
			x_axis.position = Vector3.LEFT * axis_distance
		else:
			x_axis.position = Vector3.RIGHT * axis_distance
		if selected_node.scale.y < .0:
			y_axis.position = Vector3.DOWN * axis_distance
		else:
			y_axis.position = Vector3.UP * axis_distance
		if selected_node.scale.z < .0:
			z_axis.position = Vector3.FORWARD * axis_distance
		else:
			z_axis.position = Vector3.BACK * axis_distance
	
	transform_init_counter -= 1


var prev_print: Vector3 = Vector3()
func _process(_delta: float) -> void:
	if selected_node != null:
		prev_print = selected_node.global_position
	
	# These are naive, but reliable solutions.
	# If we decide to set mouse cursor manually in the future this code may have to be adjusted.
	if Input.get_current_cursor_shape() != Input.CursorShape.CURSOR_ARROW:
		input_is_allowed = false
	# Perhaps it's possible to decouple the gizmo so that it doesn't have to know about ring menu?
	if not is_instance_valid(active_viewport):
		input_is_allowed = false
	elif active_viewport.get_ring_menu().is_active():
		input_is_allowed = false
	
	if not _mouse_inside_subviewport and grab_mode == GrabMode.NONE:
		input_is_allowed = false
	
	calculate_gizmo_state()


func calculate_gizmo_state() -> void:
	if gizmo_state == GizmoState.ENABLED:
		
		transform_gizmo.call_deferred()
		
		collision_mode = CollisionMode.NONE
		input_is_being_consumed = false
	else:
		transform_init_counter = TRANSFORM_INIT_ITERATION_COUNT


func sort_ascending_by_first_element(a, b) -> bool:
	if a[0] < b[0]:
		return true
	return false


func calculate_pointing_away() -> void:
	var axis_data = [
#		[
#			axis_distance_to_pointer,
#			axis_direction,
#			invert_camera_direction,
#			local_scale_component
#		]
	]
	var mouse_position: Vector2
	var axis_position_in_viewport: Vector2
	var gizmo_position_in_viewport: Vector2 = camera_3D.unproject_position(hg.global_position)
	var axis_distance_to_pointer: float
	
	# Axis X (Right)
	mouse_position = active_viewport.get_mouse_position()
	axis_position_in_viewport = camera_3D.unproject_position(x_axis.global_position)
	axis_distance_to_pointer = axis_position_in_viewport.distance_squared_to(mouse_position)
	axis_data.append([
		axis_distance_to_pointer,
		Vector3.RIGHT,
		false,
		sign(selected_node.scale.x)
	])
	# Axis Y (UP)
	axis_position_in_viewport = camera_3D.unproject_position(y_axis.global_position)
	axis_distance_to_pointer = axis_position_in_viewport.distance_squared_to(mouse_position)
	axis_data.append([
		axis_distance_to_pointer,
		Vector3.UP,
		false,
		sign(selected_node.scale.y)
	])
	# Axis Z (BACK)
	axis_position_in_viewport = camera_3D.unproject_position(z_axis.global_position)
	axis_distance_to_pointer = axis_position_in_viewport.distance_squared_to(mouse_position)
	axis_data.append([
		axis_distance_to_pointer,
		Vector3.FORWARD,
		true, # invert camera direction (Forward is negative Z space)
		sign(selected_node.scale.z)
	])
	axis_data.sort_custom(sort_ascending_by_first_element)
	
	var closest_axis_in_selected_node_space: Vector3 = selected_node.global_transform.basis.get_rotation_quaternion() * axis_data[0][1]
	var camera_to_selected_node_dir: Vector3 = (selected_node.global_position - camera_3D.global_position).normalized()
	var camera_fwd_to_axis_dot: float = camera_to_selected_node_dir.dot(closest_axis_in_selected_node_space)
	
	var inverted_camera_direction = axis_data[0][2]
	var selected_node_component_scale_is_negative = axis_data[0][3] < .0
	
	if (!inverted_camera_direction && camera_fwd_to_axis_dot > BEHIND_GIZMO_RATIO) || \
		(inverted_camera_direction && camera_fwd_to_axis_dot < BEHIND_GIZMO_RATIO):
		hg.active_axis_is_pointing_away = true
	else:
		hg.active_axis_is_pointing_away = false
	if selected_node_component_scale_is_negative:
		hg.active_axis_is_pointing_away = !hg.active_axis_is_pointing_away


func toggle_local_global() -> void:
	if transform_mode == TransformMode.LOCAL:
		transform_mode = TransformMode.GLOBAL
		
		remove_translation_axes()
		remove_translation_surfaces()
		remove_scale_axes()
		remove_rotation_arcs()
		
		if axes_mode == AxesMode.TRANSLATION:
			add_global_translation_axes()
		else:
			add_global_scale_axes()
		add_global_translation_surfaces()
		add_global_rotation_arcs()
	else:
		transform_mode = TransformMode.LOCAL
		
		remove_global_translation_axes()
		remove_global_translation_surfaces()
		remove_global_scale_axes()
		remove_global_rotation_arcs()
		
		if axes_mode == AxesMode.TRANSLATION:
			add_translation_axes()
		else:
			add_scale_axes()
		add_translation_surfaces()
		add_rotation_arcs()


func enable_gizmo() -> void:
	if not _is_active:
		return
	if weakref(selected_node).get_ref():
		if hg.get_parent() != active_viewport:
			if hg.get_parent() != null:
				hg.get_parent().remove_child(hg)
			active_viewport.add_child(hg)
		gizmo_state = GizmoState.ENABLED


func disable_gizmo() -> void:
	if hg.is_inside_tree():
		hg.get_parent().remove_child(hg)
	gizmo_state = GizmoState.DISABLED


func set_axes_to_translation() -> void:
	if transform_mode == TransformMode.LOCAL:
		remove_scale_axes()
		add_translation_axes()
	else:
		remove_global_scale_axes()
		add_global_translation_axes()
	axes_mode = AxesMode.TRANSLATION
	mouse_hover_detected.scale_axis = false


func set_axes_to_scale() -> void:
	if transform_mode == TransformMode.LOCAL:
		remove_translation_axes()
		add_scale_axes()
	else:
		remove_global_translation_axes()
		add_global_scale_axes()
	axes_mode = AxesMode.SCALE
	mouse_hover_detected.translation_axis = false


func toggle_scale_or_translation() -> void:
	if axes_mode == AxesMode.TRANSLATION:
		set_axes_to_scale()
	else:
		set_axes_to_translation()


func remove_scale_axes() -> void:
	if hg.scale_axes_wrapper.get_child_count() == 1:
		hg.scale_axes_wrapper.remove_child(hg.scale_axes)
		mouse_hover_detected.scale_axis = false


func add_scale_axes() -> void:
	if hg.scale_axes_wrapper.get_child_count() == 0:
		hg.scale_axes_wrapper.add_child(hg.scale_axes)


func remove_global_scale_axes() -> void:
	if hg.global_scale_axes_wrapper.get_child_count() == 1:
		hg.global_scale_axes_wrapper.remove_child(hg.global_scale_axes)
		mouse_hover_detected.scale_axis = false


func add_global_scale_axes() -> void:
	if hg.global_scale_axes_wrapper.get_child_count() == 0:
		hg.global_scale_axes_wrapper.add_child(hg.global_scale_axes)


func remove_ortho_z_handle() -> void:
	if hg.ortho_z_handle_wrapper.get_child_count() == 1:
		hg.ortho_z_handle_wrapper.remove_child(hg.ortho_z_handle)
		mouse_hover_detected.ortho_z_handle = false


func add_ortho_z_handle() -> void:
	if hg.ortho_z_handle_wrapper.get_child_count() == 0:
		hg.ortho_z_handle_wrapper.add_child(hg.ortho_z_handle)


func remove_ortho_z_surface() -> void:
	if hg.ortho_z_surface_wrapper.get_child_count() == 1:
		hg.ortho_z_surface_wrapper.remove_child(hg.ortho_z_surface)
		mouse_hover_detected.ortho_z_surface = false


func add_ortho_z_surface() -> void:
	if hg.ortho_z_surface_wrapper.get_child_count() == 0:
		hg.ortho_z_surface_wrapper.add_child(hg.ortho_z_surface)


func remove_ortho_scale_axes() -> void:
	if hg.ortho_scale_axes_wrapper.get_child_count() == 1:
		hg.ortho_scale_axes_wrapper.remove_child(hg.ortho_scale_axes)
		mouse_hover_detected.scale_axis = false


func add_ortho_scale_axes() -> void:
	if hg.ortho_scale_axes_wrapper.get_child_count() == 0:
		hg.ortho_scale_axes_wrapper.add_child(hg.ortho_scale_axes)


func remove_translation_axes() -> void:
	if hg.translation_axes_wrapper.get_child_count() == 1:
		hg.translation_axes_wrapper.remove_child(hg.translation_axes)
		mouse_hover_detected.translation_axis = false


func add_translation_axes() -> void:
	if hg.translation_axes_wrapper.get_child_count() == 0:
		hg.translation_axes_wrapper.add_child(hg.translation_axes)


func remove_global_translation_axes() -> void:
	if hg.global_translation_axes_wrapper.get_child_count() == 1:
		hg.global_translation_axes_wrapper.remove_child(hg.global_translation_axes)
		mouse_hover_detected.translation_axis = false


func add_global_translation_axes() -> void:
	if hg.global_translation_axes_wrapper.get_child_count() == 0:
		hg.global_translation_axes_wrapper.add_child(hg.global_translation_axes)


func remove_ortho_translation_axes() -> void:
	if hg.ortho_translation_axes_wrapper.get_child_count() == 1:
		hg.ortho_translation_axes_wrapper.remove_child(hg.ortho_translation_axes)
		mouse_hover_detected.translation_axis = false


func add_ortho_translation_axes() -> void:
	if hg.ortho_translation_axes_wrapper.get_child_count() == 0:
		hg.ortho_translation_axes_wrapper.add_child(hg.ortho_translation_axes)


func remove_rotation_arcs() -> void:
	if hg.rotation_arcs_wrapper.get_child_count() == 1:
		hg.rotation_arcs_wrapper.remove_child(hg.rotation_arcs)
		mouse_hover_detected.rotation_arcs = false


func add_rotation_arcs() -> void:
	if hg.rotation_arcs_wrapper.get_child_count() == 0:
		hg.rotation_arcs_wrapper.add_child(hg.rotation_arcs)


func remove_global_rotation_arcs() -> void:
	if hg.global_rotation_arcs_wrapper.get_child_count() == 1:
		hg.global_rotation_arcs_wrapper.remove_child(hg.global_rotation_arcs)
		mouse_hover_detected.rotation_arcs = false


func add_global_rotation_arcs() -> void:
	if hg.global_rotation_arcs_wrapper.get_child_count() == 0:
		hg.global_rotation_arcs_wrapper.add_child(hg.global_rotation_arcs)


func remove_ortho_rotation_arcs() -> void:
	if hg.ortho_rotation_arcs_wrapper.get_child_count() == 1:
		hg.ortho_rotation_arcs_wrapper.remove_child(hg.ortho_rotation_arcs)
		mouse_hover_detected.rotation_arcs = false


func add_ortho_rotation_arcs() -> void:
	if hg.ortho_rotation_arcs_wrapper.get_child_count() == 0:
		hg.ortho_rotation_arcs_wrapper.add_child(hg.ortho_rotation_arcs)


func remove_translation_surfaces() -> void:
	if hg.translation_surfaces_wrapper.get_child_count() == 1:
		hg.translation_surfaces_wrapper.remove_child(hg.translation_surfaces)
		mouse_hover_detected.translation_surface = false


func add_translation_surfaces() -> void:
	if hg.translation_surfaces_wrapper.get_child_count() == 0:
		hg.translation_surfaces_wrapper.add_child(hg.translation_surfaces)


func remove_global_translation_surfaces() -> void:
	if hg.global_translation_surfaces_wrapper.get_child_count() == 1:
		hg.global_translation_surfaces_wrapper.remove_child(hg.global_translation_surfaces)
		mouse_hover_detected.translation_surface = false


func add_global_translation_surfaces() -> void:
	if hg.global_translation_surfaces_wrapper.get_child_count() == 0:
		hg.global_translation_surfaces_wrapper.add_child(hg.global_translation_surfaces)


func remove_ortho_translation_surfaces() -> void:
	if hg.ortho_translation_surfaces_wrapper.get_child_count() == 1:
		hg.ortho_translation_surfaces_wrapper.remove_child(hg.ortho_translation_surfaces)
		mouse_hover_detected.translation_surface = false


func add_ortho_translation_surfaces() -> void:
	if hg.ortho_translation_surfaces_wrapper.get_child_count() == 0:
		hg.ortho_translation_surfaces_wrapper.add_child(hg.ortho_translation_surfaces)


func remove_center_drag() -> void:
	if hg.center_drag_wrapper.get_child_count() == 1:
		hg.center_drag_wrapper.remove_child(hg.center_drag)
		mouse_hover_detected.center_drag = false


func add_center_drag() -> void:
	if hg.center_drag_wrapper.get_child_count() == 0:
		hg.center_drag_wrapper.add_child(hg.center_drag)


func enable_input() -> void:
	input_is_allowed = true


func disable_input() -> void:
	input_is_allowed = false


func setup_gizmo(new_selected_node: Node3D, new_active_viewport: Viewport) -> void:
	# Call this function before enable_gizmo.
	# You can omit setting certain properties by providing null arguments, then the old values
	# will be kept.
	if new_selected_node != null:
		selected_node = new_selected_node
	if new_active_viewport != null:
		active_viewport = new_active_viewport
