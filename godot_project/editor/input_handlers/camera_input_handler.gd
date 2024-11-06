extends InputHandlerBase

var camera_orbit_modifier_is_pressed := false
var camera_forward_is_pressed := false
var camera_back_is_pressed := false
var camera_left_is_pressed := false
var camera_right_is_pressed := false
var camera_up_is_pressed := false
var camera_down_is_pressed := false
var structure_context_selection_changed: bool = false
var is_direction_key_pressed := false
var axes_widget : AxesWidget3D = null
var axes_widget_gizmo : AxesWidget = null

var _is_in_use: bool = false
var _is_hovering: bool = false
var _last_visible_mouse_position: Vector2
var _pending_scroll_return: bool = false

var _alt_key_is_held_down: bool = false
var _ctrl_key_is_held_down: bool = false
var _shift_key_is_held_down: bool = false
var _meta_key_is_held_down: bool = false


## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return true


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(_in_structure_context: StructureContext) -> bool:
	return true


func is_exclusive_input_consumer() -> bool:
	var is_keyboard_in_use: bool = camera_forward_is_pressed or camera_back_is_pressed or \
			camera_left_is_pressed or camera_right_is_pressed or camera_up_is_pressed or camera_down_is_pressed
	var is_exclusive: bool = _is_in_use or is_keyboard_in_use
	GizmoRoot.input_is_allowed = !is_exclusive
	return is_exclusive


func handle_inputs_end() -> void:
	_is_hovering = false
	if _is_in_use:
		_is_in_use = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func handle_input_omission() -> void:
	reset_input()


func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	
	MolecularEditorContext.workspace_activated.connect(_on_manage_workspace_activation)
	in_context.workspace_main_view.get_window().connect(&"focus_exited", _on_workspace_window_focus_exited)
	var camera_widget: CameraWidget = in_context.get_editor_viewport_container().get_camera_widget()
	assert(camera_widget != null, "Could not locate Camera Widget")
	camera_widget.camera_movement_started.connect(_on_camera_widget_camera_movement_started)
	camera_widget.camera_movement_ended.connect(_on_camera_widget_camera_movement_ended)


func _on_camera_widget_camera_movement_started() -> void:
	_is_in_use = true


func _on_camera_widget_camera_movement_ended() -> void:
	_is_in_use = false


func _on_workspace_window_focus_exited() -> void:
	reset_input()


func _on_manage_workspace_activation(_in_workspace : Workspace) -> void:
	reset_input()


func _reset_mouse() -> void:
	if axes_widget:
		axes_widget.last_mouse_deltas = []
		axes_widget.rotation_must_follow_mouse = false
		if axes_widget_gizmo.mouse_drag_in_widget_is_active:
			axes_widget_gizmo.restore_mouse_position()
		axes_widget_gizmo.mouse_drag_in_widget_is_active = false
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			Input.warp_mouse(_last_visible_mouse_position)
		_is_in_use = false
		disable_orbiting()



func reset_input() -> void:
	# Reset mouse
	_reset_mouse()
	
	# Reset keyboard
	if axes_widget != null:
		camera_orbit_modifier_is_pressed = false
		axes_widget.transform_faster = false
		
		disable_orbiting()
		
		camera_forward_is_pressed = false
		camera_back_is_pressed = false
		camera_left_is_pressed = false
		camera_right_is_pressed = false
		camera_up_is_pressed = false
		camera_down_is_pressed = false

		_is_in_use = false
		_is_hovering = false

		is_direction_key_pressed = false

		stop_key_rotation()
		stop_key_movement()


func _on_structure_context_selection_changed() -> void:
	structure_context_selection_changed = true


# Manage old orbit position per workspace. To prevent initial orbiting and have correct fallback
# position.
func _manage_old_orbit_position(_in_context: StructureContext) -> void:
	axes_widget_gizmo.old_selection_position = axes_widget_gizmo.get_orbit_pivot_position()
	if !_in_context.selection_changed.is_connected(_on_structure_context_selection_changed):
		_in_context.selection_changed.connect(_on_structure_context_selection_changed)
	axes_widget_gizmo.orbiting_allowed = structure_context_selection_changed
	
	var visible_structure_contexts: Array[StructureContext] = \
	_in_context.workspace_context.get_visible_structure_contexts(false)
	var visible_structure_found: bool = visible_structure_contexts.size() > 0
	if !axes_widget_gizmo.orbiting_allowed:
		axes_widget_gizmo.orbiting_allowed = visible_structure_found
		if axes_widget_gizmo.orbiting_allowed:
			var visible_object_center: Vector3 = \
			WorkspaceUtils.get_visible_objects_aabb(_in_context.workspace_context).get_center()
			axes_widget_gizmo.old_selection_position = visible_object_center
	else:
		axes_widget_gizmo.orbiting_allowed = visible_structure_found


func _detect_which_modifiers_are_being_held_down(in_input_event: InputEvent) -> void:
	if in_input_event is InputEventKey:
		match in_input_event.keycode:
			KEY_ALT:
				_alt_key_is_held_down = in_input_event.pressed
			KEY_CTRL:
				_ctrl_key_is_held_down = in_input_event.pressed
			KEY_META:
				_meta_key_is_held_down = in_input_event.pressed
			KEY_SHIFT:
				_shift_key_is_held_down = in_input_event.pressed
	elif in_input_event is InputEventWithModifiers:
		_alt_key_is_held_down = in_input_event.alt_pressed
		_ctrl_key_is_held_down = in_input_event.ctrl_pressed
		_meta_key_is_held_down = in_input_event.meta_pressed
		_shift_key_is_held_down = in_input_event.shift_pressed


func _finish_orientation_snap(_orientation_widget: Node3D) -> void:
	if _orientation_widget:
		if _orientation_widget.is_snap_active():
			_orientation_widget.finish_snap()


## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input in_input_event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, in_camera: Camera3D, \
		_in_context: StructureContext) -> bool:
	
	_detect_which_modifiers_are_being_held_down(in_input_event)
	
	_pending_scroll_return = _shift_key_is_held_down
	
	if in_input_event is InputEventKey:
		if in_input_event.keycode != KEY_SHIFT:
			_pending_scroll_return = false
	
	# We could also add _alt_key_is_held_down ||, but that would disable the Alt+wasd camera
	# orbiting/rotation. If the alt key check is not added the behavior will differ on Windows vs
	# Linux/Mac, but it won't significantly affect usability. This check was previously added to
	# obfuscate differences between different operating systems. (To achieve the same behavior on
	# all operating systems, we should investigate, why _forward_input behaves differently on
	# Windows from other operating systems.).
	if _meta_key_is_held_down:
		reset_input()
		return false
	
	# Camera clashes with inputs of shortcuts, so we want to make sure ctrl/cmd is not pressed at
	# this point so it doesn't eat shortcut inputs
	if in_input_event is InputEventWithModifiers and in_input_event.is_command_or_control_pressed():
		reset_input()
		return false
	# Implement lose coupling to orientation widget, so that we can prevent input during snaping.
	# But if orientation widget isn't found, that's fine too.
	var orientation_widget: Node3D = in_camera.get_viewport().get_orientation_widget()
	
	var camera_pivot: Node3D = in_camera.get_owner()
	
	if axes_widget_gizmo != null:
		axes_widget_gizmo.workspace_has_transformable_selection = get_workspace_context().has_transformable_selection()
	
	# This acquisition might look a bit confusing, it's because the axes_widget is assigned in
	# camera pivot as a temporary hack.
	axes_widget_gizmo = camera_pivot.axes_widget
	axes_widget = axes_widget_gizmo.axes_widget_3d
	
	_manage_old_orbit_position(_in_context)
	
	if in_input_event is InputEventMouse:
		_is_hovering = axes_widget_gizmo.mouse_is_in_drag_radius
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			_last_visible_mouse_position = in_input_event.global_position
		
		if in_input_event is InputEventMouseButton:
			if in_input_event.is_pressed():
				if in_input_event.button_index == MOUSE_BUTTON_LEFT:
					if axes_widget_gizmo.mouse_is_in_drag_radius:
						axes_widget_gizmo.mouse_drag_in_widget_is_active = true
						# Captured is nicer than confined, because as mouse must be invisible in
						# both cases it moves, but with captured we won't stop transformation
						# when mouse reaches the edge of the window. Plus mouse pointer position
						# is warped back now.
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
						_is_in_use = true
					else:
						if !_pending_scroll_return:
							reset_input()
				elif in_input_event.button_index == MOUSE_BUTTON_MIDDLE:
					_is_in_use = true
					axes_widget.rotation_must_follow_mouse = true
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				elif in_input_event.button_index == MOUSE_BUTTON_WHEEL_UP || \
				in_input_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					if in_input_event.is_action_pressed(&"camera_forward"):
						axes_widget.movement_z_coefficient = axes_widget.FORWARD
					if in_input_event.is_action_pressed(&"camera_back"):
						axes_widget.movement_z_coefficient = axes_widget.BACK
					
					axes_widget.start_mouse_wheel_movement_step()
			else:
				_reset_mouse()
				if axes_widget_gizmo.workspace_has_transformable_selection:
					GizmoRoot.enable_gizmo()
		elif in_input_event is InputEventMouseMotion:
			# To restore orbiting intertia check: 8c59342316b0407e60043b6a31772e39265e7275
			axes_widget.set_mouse_delta(in_input_event.relative)
		return _is_in_use or _is_hovering
	
	elif in_input_event is InputEventKey:
		_finish_orientation_snap(orientation_widget)
		
		# Speed modifier
		axes_widget.transform_faster = _shift_key_is_held_down
		
		# The control modifier is lower priority than ordinary keys, so must check if it's active
		# instead of making specific input actions with the modifier.
		if in_input_event.is_action_pressed(&"camera_orbit_modifier"):
			camera_orbit_modifier_is_pressed = true
		elif in_input_event.is_action_released(&"camera_orbit_modifier"):
			camera_orbit_modifier_is_pressed = false
		
		var is_this_direction_key_event := false
		if in_input_event.is_action_pressed(&"camera_forward", true):
			camera_forward_is_pressed = true
			is_this_direction_key_event = true
		elif in_input_event.is_action_released(&"camera_forward", false):
			camera_forward_is_pressed = false
			is_this_direction_key_event = true
		if in_input_event.is_action_pressed(&"camera_back", true):
			camera_back_is_pressed = true
			is_this_direction_key_event = true
		elif in_input_event.is_action_released(&"camera_back", false):
			camera_back_is_pressed = false
			is_this_direction_key_event = true
		if in_input_event.is_action_pressed(&"camera_left", true):
			camera_left_is_pressed = true
			is_this_direction_key_event = true
		elif in_input_event.is_action_released(&"camera_left", false):
			camera_left_is_pressed = false
			is_this_direction_key_event = true
		if in_input_event.is_action_pressed(&"camera_right", true):
			camera_right_is_pressed = true
			is_this_direction_key_event = true
		elif in_input_event.is_action_released(&"camera_right", false):
			camera_right_is_pressed = false
			is_this_direction_key_event = true
		if in_input_event.is_action_pressed(&"camera_up", true):
			camera_up_is_pressed = true
			is_this_direction_key_event = true
		elif in_input_event.is_action_released(&"camera_up", false):
			camera_up_is_pressed = false
			is_this_direction_key_event = true
		if in_input_event.is_action_pressed(&"camera_down", true):
			camera_down_is_pressed = true
			is_this_direction_key_event = true
		elif in_input_event.is_action_released(&"camera_down", false):
			camera_down_is_pressed = false
			is_this_direction_key_event = true
		
		if is_this_direction_key_event:
			var all_direction_keys_were_just_released := true
			if camera_forward_is_pressed:
				all_direction_keys_were_just_released = false
			if camera_back_is_pressed:
				all_direction_keys_were_just_released = false
			if camera_left_is_pressed:
				all_direction_keys_were_just_released = false
			if camera_right_is_pressed:
				all_direction_keys_were_just_released = false
			if camera_up_is_pressed:
				all_direction_keys_were_just_released = false
			if camera_down_is_pressed:
				all_direction_keys_were_just_released = false
			
			if all_direction_keys_were_just_released:
				disable_orbiting()
		
	# Disable on orbit.
	if axes_widget.rotation_must_follow_mouse && axes_widget_gizmo.is_orbiting:
		allow_only_forward_back_key_movement()
	
	is_direction_key_pressed = false
	if camera_forward_is_pressed:
		is_direction_key_pressed = true
	if camera_back_is_pressed:
		is_direction_key_pressed = true
	if camera_left_is_pressed:
		is_direction_key_pressed = true
	if camera_right_is_pressed:
		is_direction_key_pressed = true
	if camera_up_is_pressed:
		is_direction_key_pressed = true
	if camera_down_is_pressed:
		is_direction_key_pressed = true
	
	if !is_direction_key_pressed:
		stop_key_movement()
		stop_key_rotation()
	
	if camera_orbit_modifier_is_pressed:
		allow_only_up_down_key_movement()
		
		# Rotation
		if !axes_widget.rotation_must_follow_mouse:
			if camera_forward_is_pressed:
				axes_widget.rotation_y_coefficient = axes_widget.FORWARD
			elif axes_widget.rotation_y_coefficient == axes_widget.FORWARD:
				axes_widget.rotation_y_coefficient = axes_widget.STOP
			if camera_back_is_pressed:
				axes_widget.rotation_y_coefficient = axes_widget.BACK
			elif axes_widget.rotation_y_coefficient == axes_widget.BACK:
				axes_widget.rotation_y_coefficient = axes_widget.STOP
			if camera_left_is_pressed:
				axes_widget.rotation_x_coefficient = axes_widget.RIGHT
			elif axes_widget.rotation_x_coefficient == axes_widget.RIGHT:
				axes_widget.rotation_x_coefficient = axes_widget.STOP
			if camera_right_is_pressed:
				axes_widget.rotation_x_coefficient = axes_widget.LEFT
			elif axes_widget.rotation_x_coefficient == axes_widget.LEFT:
				axes_widget.rotation_x_coefficient = axes_widget.STOP
	else:
		stop_key_rotation()
		
		# Movement
		if camera_forward_is_pressed:
			axes_widget.movement_z_coefficient = axes_widget.FORWARD
			axes_widget.camera_move_ease.z = \
			float(axes_widget.movement_z_coefficient)
		elif axes_widget.movement_z_coefficient == axes_widget.FORWARD:
			if !_pending_scroll_return:
				axes_widget.movement_z_coefficient = axes_widget.STOP
				axes_widget.camera_move_ease.z = \
				float(axes_widget.movement_z_coefficient)
		if camera_back_is_pressed:
			axes_widget.movement_z_coefficient = axes_widget.BACK
			axes_widget.camera_move_ease.z = \
			float(axes_widget.movement_z_coefficient)
		elif axes_widget.movement_z_coefficient == axes_widget.BACK:
			if !_pending_scroll_return:
				axes_widget.movement_z_coefficient = axes_widget.STOP
				axes_widget.camera_move_ease.z = \
				float(axes_widget.movement_z_coefficient)
		if camera_left_is_pressed:
			axes_widget.movement_x_coefficient = axes_widget.LEFT
			axes_widget.camera_move_ease.x = \
			float(axes_widget.movement_x_coefficient)
		elif axes_widget.movement_x_coefficient == axes_widget.LEFT:
			axes_widget.movement_x_coefficient = axes_widget.STOP
			axes_widget.camera_move_ease.x = \
			float(axes_widget.movement_x_coefficient)
		if camera_right_is_pressed:
			axes_widget.movement_x_coefficient = axes_widget.RIGHT
			axes_widget.camera_move_ease.x = \
			float(axes_widget.movement_x_coefficient)
		elif axes_widget.movement_x_coefficient == axes_widget.RIGHT:
			axes_widget.movement_x_coefficient = axes_widget.STOP
			axes_widget.camera_move_ease.x = \
			float(axes_widget.movement_x_coefficient)
	
	disable_orbiting_on_up_down_keyboard_only_input()
	
	if camera_up_is_pressed:
		axes_widget.movement_y_coefficient = axes_widget.DOWN
		axes_widget.camera_move_ease.y = \
		float(axes_widget.movement_y_coefficient)
	elif axes_widget.movement_y_coefficient == axes_widget.DOWN:
		axes_widget.movement_y_coefficient = axes_widget.STOP
		axes_widget.camera_move_ease.y = \
		float(axes_widget.movement_y_coefficient)
		axes_widget.camera_move_direction.y = .0
	if camera_down_is_pressed:
		axes_widget.movement_y_coefficient = axes_widget.UP
		axes_widget.camera_move_ease.y = \
		float(axes_widget.movement_y_coefficient)
	elif axes_widget.movement_y_coefficient == axes_widget.UP:
		axes_widget.movement_y_coefficient = axes_widget.STOP
		axes_widget.camera_move_ease.y = \
		float(axes_widget.movement_y_coefficient)
		axes_widget.camera_move_direction.y = .0
	
	if is_direction_key_pressed:
		return true
 
	if axes_widget_gizmo.workspace_has_transformable_selection:
		GizmoRoot.enable_gizmo()
	return false


func disable_orbiting_on_up_down_keyboard_only_input() -> void:
	if (camera_up_is_pressed || camera_down_is_pressed) && \
			axes_widget_gizmo != null && axes_widget_gizmo.workspace_has_transformable_selection && \
			!camera_left_is_pressed && !camera_right_is_pressed && \
			!camera_forward_is_pressed && !camera_back_is_pressed:
				disable_orbiting()


func disable_orbiting() -> void:
	axes_widget_gizmo.is_orbiting = false
	axes_widget_gizmo.no_selection_orbit_active = false


func stop_key_movement() -> void:
	if !_pending_scroll_return:
		axes_widget.camera_move_ease = Vector3.ZERO
		axes_widget.camera_move_direction = Vector3.ZERO


func allow_only_forward_back_key_movement() -> void:
	axes_widget.movement_x_coefficient = axes_widget.STOP
	axes_widget.movement_y_coefficient = axes_widget.STOP
	axes_widget.camera_move_ease.x = .0
	axes_widget.camera_move_ease.y = .0
	axes_widget.camera_move_direction.x = .0
	axes_widget.camera_move_direction.y = .0


func allow_only_up_down_key_movement() -> void:
	axes_widget.movement_x_coefficient = axes_widget.STOP
	axes_widget.movement_z_coefficient = axes_widget.STOP
	axes_widget.camera_move_ease.x = .0
	axes_widget.camera_move_ease.z = .0
	axes_widget.camera_move_direction.x = .0
	axes_widget.camera_move_direction.z = .0


func stop_key_rotation() -> void:
	axes_widget.rotation_x_coefficient = axes_widget.STOP
	axes_widget.rotation_y_coefficient = axes_widget.STOP


## Input handlers will execute _forward_input_* in an order dictated by this parameter
## highter priority value means the input handler will execute first
func get_priority() -> int:
	return BuiltinInputHandlerPriorities.DEFAULT_CAMERA_INPUT_PRIORITY
