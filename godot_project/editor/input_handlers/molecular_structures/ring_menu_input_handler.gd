extends InputHandlerBase


func get_priority() -> int:
	return BuiltinInputHandlerPriorities.RING_MENU_HANDLER


func handles_empty_selection() -> bool:
	return true


func handles_structure_context(_in_structure_context: StructureContext) -> bool:
	return true

func is_exclusive_input_consumer() -> bool:
	var viewport: WorkspaceEditorViewport = get_workspace_context().get_editor_viewport()
	if viewport == null:
		return false
	var ring_menu: NanoRingMenu = viewport.get_ring_menu()
	if ring_menu == null:
		return false
	return ring_menu.is_active()


func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, _in_context: StructureContext) -> bool:
	var viewport: WorkspaceEditorViewport = _in_camera.get_viewport()
	var ring_menu: NanoRingMenu = viewport.get_ring_menu()
	var workspace_context: WorkspaceContext = viewport.get_workspace_context()
	
	if in_input_event.is_action_pressed(&"close_ring_menu", false, true):
		if ring_menu.is_active() and in_input_event.pressed:
			ring_menu.close()
			return true
	if in_input_event.is_action_pressed(&"toggle_ring_menu", false, true):
		if in_input_event.pressed:
			# Right click detected, show
			if ring_menu.is_active():
				ring_menu.close()
			else:
				if in_input_event is InputEventKey or in_input_event is InputEventAction:
					# Show in the center of the viewport
					var main_view: WorkspaceMainView = workspace_context.workspace_main_view
					var fit_in_rect: Rect2i = main_view.workspace_tools_container.get_global_rect()
					var desired_position: Vector2 = fit_in_rect.get_center()
					_show_contextual_menu(ring_menu, workspace_context, fit_in_rect, desired_position)
				else:
					# Show in mouse position
					_show_contextual_menu(ring_menu, workspace_context, Rect2i(), in_input_event.position)
			return true
	return false


func _show_contextual_menu(in_ring_menu: NanoRingMenu, in_workspace_context: WorkspaceContext,
			in_fit_in_rect: Rect2i, in_desired_position: Vector2) -> void:
	if !is_instance_valid(in_workspace_context) || !is_instance_valid(in_ring_menu):
		return
	in_ring_menu.set_context(NanoRingMenu.CONTEXT_MAIN)
	if in_ring_menu.is_empty():
		var main_menu: RingMenuLevel = RingLevelMainMenu.new(in_workspace_context, in_ring_menu)
		in_ring_menu.add_level(main_menu)
	if !in_ring_menu._state.is_empty():
		in_ring_menu.show_in_desired_position(in_desired_position, in_fit_in_rect)

