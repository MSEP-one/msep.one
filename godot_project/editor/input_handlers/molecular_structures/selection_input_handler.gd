extends SelectionInputHandlerBase


const MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED = 20 * 20


var _press_down_position: Vector2 = Vector2(-100, -100)


func handles_empty_selection() -> bool:
	return true


func handles_structure_context(_in_structure_context: StructureContext) -> bool:
	return true


func handle_inputs_end() -> void:
	pass


func is_exclusive_input_consumer() -> bool:
	return false


func get_priority() -> int:
	return BuiltinInputHandlerPriorities.SELECTION_ATOM_HANDLER


func forward_input(in_input_event: InputEvent, in_camera: Camera3D, in_context: StructureContext) -> bool:
	var is_left_mouse_button_event: bool = in_input_event is InputEventMouseButton and \
			in_input_event.button_index == MOUSE_BUTTON_LEFT
	
	var is_double_click: bool = \
			in_input_event is InputEventMouseButton \
			and in_input_event.double_click \
			and is_left_mouse_button_event
	
	if is_double_click:
		var editable_structures: Array[StructureContext] = _workspace_context.get_editable_structure_contexts()
		if _activate_selection_logic(in_camera, in_input_event.position, editable_structures):
			_workspace_context.snapshot_moment("Change Selection")
			return true
	
	if is_left_mouse_button_event:
		if in_input_event.is_pressed():
			_press_down_position = in_input_event.global_position
	
	if in_input_event.is_action_pressed(&"clear_selection", false, true) and in_context != null:
		var workspace_context: WorkspaceContext = get_workspace_context()
		if workspace_context.has_selection():
			var selected_structure_contexts: Array[StructureContext] = \
					workspace_context.get_structure_contexts_with_selection()
			for struct_context in selected_structure_contexts:
				struct_context.clear_selection()
			# Selection was cleared, DynamicContextDocker is no longer relevant
			MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
			_workspace_context.snapshot_moment("Clear Selection")
			return true
	
	var workspace_context: WorkspaceContext = in_context.workspace_context
	var editable_structures: Array[StructureContext] = workspace_context.get_editable_structure_contexts()
	if in_input_event.is_action_pressed(&"unselect", false, true) or \
		_user_is_unselecting_on_mac_pressed(in_input_event, false, true):
		var input_consumed: bool = _screen_deselection_logic(in_camera, in_input_event.position, editable_structures)
		if input_consumed and !get_workspace_context().has_selection():
			# Selection was cleared, DynamicContextDocker is no longer relevant
			MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
		return input_consumed
	elif in_input_event.is_action_pressed(&"multiselect", false, true) or _user_is_selecting_on_mac_pressed(in_input_event, false, true):
		var input_consumed: bool = _screen_selection_logic(in_camera, in_input_event.position, editable_structures, true)
		if input_consumed:
			if !get_workspace_context().has_selection():
				# Selection was cleared, DynamicContextDocker is no longer relevant
				if get_workspace_context().is_simulating():
					MolecularEditorContext.request_workspace_docker_focus(SimulationsDocker.UNIQUE_DOCKER_NAME)
				else:
					MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
			elif MolecularEditorContext.is_workspace_docker_active(GroupsDocker.UNIQUE_DOCKER_NAME):
				# User is managing groups, dont bother him/her
				pass
			else:
				MolecularEditorContext.request_workspace_docker_focus(DynamicContextDocker.UNIQUE_DOCKER_NAME)
		return input_consumed
	
	if in_input_event.is_action_released(&"select", true) and _is_near_press_down_pos(in_input_event):
		var rendering: Rendering = get_workspace_context().get_rendering()
		if rendering.is_atom_preview_visible():
			# Atom is being added, avoid changing selection
			return false
		if rendering.is_shape_preview_visible():
			# Shape is being created, avoid changing selection
			return false
		if rendering.is_structure_preview_visible():
			# Molecule is being created, avoid changing selection
			return false
		if rendering.is_virtual_motor_preview_visible():
			# Virtual Motor is being created, avoid changing selection
			return false
		if rendering.is_virtual_anchor_preview_visible():
			# Virtual Anchor and/or Spring is being created, avoid changing selection
			return false
		var input_consumed: bool = _screen_selection_logic(in_camera, in_input_event.position, editable_structures, false)
		if input_consumed:
			if !get_workspace_context().has_selection():
				if MolecularEditorContext.is_workspace_docker_active(DynamicContextDocker.UNIQUE_DOCKER_NAME):
					# DynamicContextDocker docker is no longer relevant, switch to another docker if the selection docker is active
					MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
			else:
				MolecularEditorContext.request_workspace_docker_focus(DynamicContextDocker.UNIQUE_DOCKER_NAME)
		return input_consumed
	
	if in_input_event is InputEventMouse:
		var hovering_object: StructureContext = null
		var hovering_atom_id: int = -1
		var hovering_bond_id: int = -1
		var hovering_spring_id: int = -1
		var hover_position: Vector3 = Vector3(INF, INF, INF)
		if not editable_structures.is_empty():
			var multi_structure_hit_result := MultiStructureHitResult.new(in_camera, in_input_event.position, editable_structures)
			match multi_structure_hit_result.hit_type:
				MultiStructureHitResult.HitType.HIT_ATOM:
					hovering_object = multi_structure_hit_result.closest_hit_structure_context
					hovering_atom_id = multi_structure_hit_result.closest_hit_atom_id
					hover_position = hovering_object.nano_structure.atom_get_position(hovering_atom_id)
				MultiStructureHitResult.HitType.HIT_BOND:
					hovering_object = multi_structure_hit_result.closest_hit_structure_context
					hovering_bond_id = multi_structure_hit_result.closest_hit_bond_id
					var bond_data: Vector3i = hovering_object.nano_structure.get_bond(hovering_bond_id)
					hover_position = (hovering_object.nano_structure.atom_get_position(bond_data.x) + \
							hovering_object.nano_structure.atom_get_position(bond_data.y)) / 2.0
				MultiStructureHitResult.HitType.HIT_SPRING:
					hovering_object = multi_structure_hit_result.closest_hit_structure_context
					hovering_spring_id = multi_structure_hit_result.closest_hit_spring_id
					hover_position = (hovering_object.nano_structure.spring_get_atom_position(hovering_spring_id) + \
							hovering_object.nano_structure.spring_get_anchor_position(hovering_spring_id, hovering_object)) / 2.0
				MultiStructureHitResult.HitType.HIT_MOTOR:
					hovering_object = multi_structure_hit_result.closest_hit_structure_context
					hover_position = hovering_object.nano_structure.get_transform().origin
				MultiStructureHitResult.HitType.HIT_ANCHOR:
					hovering_object = multi_structure_hit_result.closest_hit_structure_context
					hover_position = hovering_object.nano_structure.get_position()
				MultiStructureHitResult.HitType.HIT_SHAPE:
					if _is_shape_selectable():
						hovering_object = multi_structure_hit_result.closest_hit_structure_context
						hover_position = hovering_object.nano_structure.get_position()
				_:
					# do nothing
					pass
		get_workspace_context().set_hovered_structure_context(hovering_object, hovering_atom_id, hovering_bond_id, hovering_spring_id)
		var selection_center: Vector3 = workspace_context.get_selection_aabb().get_center() if \
				workspace_context.has_selection() else Vector3(INF, INF,INF)
		_update_distance_message(workspace_context, hover_position, selection_center)
		
		var consume_input: bool = hovering_object != null
		return consume_input
	
	return false


func _update_distance_message(in_workspace_context: WorkspaceContext, in_position_one: Vector3,
			in_position_two: Vector3) -> void:
	var are_positions_valid: bool = not in_position_one.is_equal_approx(Vector3(INF, INF, INF)) and \
			not in_position_two.is_equal_approx(Vector3(INF, INF, INF))
	var distance: float = in_position_one.distance_to(in_position_two)
	var is_anything_selected: bool = in_workspace_context.has_selection()
	var should_show_distance: bool = are_positions_valid and is_anything_selected and not is_equal_approx(distance, 0.0)
	if should_show_distance:
		MolecularEditorContext.bottom_bar_update_distance(in_workspace_context, "Distance to selection center: ", distance)
	else:
		MolecularEditorContext.bottom_bar_update_distance(in_workspace_context, "", 0.0)


func _is_near_press_down_pos(in_input_event: InputEventMouseButton) -> bool:
	var is_near_press_down_pos: bool = in_input_event.global_position.distance_squared_to(_press_down_position) \
			< MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED
	return is_near_press_down_pos


func _activate_selection_logic(
			in_camera: Camera3D,
			in_screen_position: Vector2,
			out_editable_structures: Array[StructureContext]) -> bool:
	
	if out_editable_structures.is_empty():
		return false
	
	var multi_structure_hit_result := MultiStructureHitResult.new(in_camera, in_screen_position, out_editable_structures)
	if multi_structure_hit_result.did_hit():
		# perform selection
		var hit_context: StructureContext = multi_structure_hit_result.closest_hit_structure_context
		if hit_context != get_workspace_context().get_current_structure_context():
			var affected_context: = get_workspace_context().get_toplevel_editable_context(hit_context)
			if affected_context.nano_structure.is_virtual_object():
				# Shapes, Motors, Springs, etc; cannot be activated, this is on purpose to have a more compact group hierarchy
				return false
			get_workspace_context().change_current_structure_context(affected_context)
			return true
	return false


func _screen_selection_logic(
			in_camera: Camera3D,
			in_screen_position: Vector2,
			out_editable_structures: Array[StructureContext],
			is_multiselecting: bool) -> bool:
	
	if out_editable_structures.is_empty():
		return false
	
	var snapshot_name: String = ""
	var need_to_create_snapshot: bool = false
	# If not multiselecting clear all selection first
	if not is_multiselecting:
		if not out_editable_structures.is_empty():
			snapshot_name = "Change Selection"
		for structure_context in out_editable_structures:
			if structure_context.has_selection():
				structure_context.clear_selection()
				need_to_create_snapshot = true
	
	var multi_structure_hit_result := MultiStructureHitResult.new(in_camera, in_screen_position, out_editable_structures)
	if multi_structure_hit_result.did_hit():
		# perform selection
		var hit_context: StructureContext = multi_structure_hit_result.closest_hit_structure_context
		const GROUP_SELECTION_BLACKLIST = [&"AnchorPoint", &"Spring"]
		if hit_context != get_workspace_context().get_current_structure_context() and not hit_context.nano_structure.get_type() in GROUP_SELECTION_BLACKLIST:
			# Clicked an object that is a child of current edited structure, select the entire group
			if not need_to_create_snapshot:
				snapshot_name = "Select Group"
				need_to_create_snapshot = true
			var affected_context: StructureContext = _workspace_context.get_toplevel_editable_context(hit_context)
			if affected_context.is_fully_selected() and is_multiselecting:
				affected_context.clear_selection(true)
			else:
				affected_context.select_all(true)
		else:
			match multi_structure_hit_result.hit_type:
				MultiStructureHitResult.HitType.HIT_ATOM:
					var selected_atom: int = multi_structure_hit_result.closest_hit_atom_id
					var new_selection: PackedInt32Array = [selected_atom]
					if not need_to_create_snapshot:
						snapshot_name = "Select Atom"
						need_to_create_snapshot = true
					if hit_context.is_atom_selected(selected_atom):
						hit_context.deselect_atoms(new_selection)
					else:
						hit_context.select_atoms(new_selection)
				MultiStructureHitResult.HitType.HIT_BOND:
					var selected_bond_id: int = multi_structure_hit_result.closest_hit_bond_id
					var new_selection: PackedInt32Array = [selected_bond_id]
					if not need_to_create_snapshot:
						snapshot_name = "Select Bond"
						need_to_create_snapshot = true
					if hit_context.is_bond_selected(selected_bond_id):
						hit_context.deselect_bonds(new_selection)
					else:
						hit_context.select_bonds(new_selection)
				MultiStructureHitResult.HitType.HIT_SPRING:
					var selected_spring_id: int = multi_structure_hit_result.closest_hit_spring_id
					var new_selection: PackedInt32Array = PackedInt32Array([selected_spring_id])
					if not need_to_create_snapshot:
						snapshot_name = "Deselect Spring" if hit_context.is_spring_selected(selected_spring_id) \
								else "Select Spring"
						need_to_create_snapshot = true
					if hit_context.is_spring_selected(selected_spring_id):
						hit_context.deselect_springs(new_selection)
					else:
						hit_context.select_springs(new_selection)
				MultiStructureHitResult.HitType.HIT_SHAPE:
					if _is_shape_selectable():
						if hit_context.is_shape_selected():
							if not need_to_create_snapshot:
								snapshot_name = "Deselect Shape"
								need_to_create_snapshot = true
							hit_context.set_shape_selected(false)
						else:
							if not need_to_create_snapshot:
								snapshot_name = "Select Shape"
								need_to_create_snapshot = true
							hit_context.set_shape_selected(true)
				MultiStructureHitResult.HitType.HIT_MOTOR:
					if _is_select_mode_enabled():
						if hit_context.is_motor_selected():
							if not need_to_create_snapshot:
								snapshot_name = "Deselect Motor"
								need_to_create_snapshot = true
							hit_context.set_motor_selected(false)
						else:
							if not need_to_create_snapshot:
								snapshot_name = "Select Motor"
								need_to_create_snapshot = true
							hit_context.set_motor_selected(true)
				MultiStructureHitResult.HitType.HIT_ANCHOR:
					if hit_context.is_anchor_selected():
						if not need_to_create_snapshot:
							snapshot_name = "Deselect Anchor"
							need_to_create_snapshot = true
						hit_context.set_anchor_selected(false)
					else:
						if not need_to_create_snapshot:
							snapshot_name = "Select Anchor"
							need_to_create_snapshot = true
						hit_context.set_anchor_selected(true)
				_:
					assert(false, "Invalid hit result")
	if need_to_create_snapshot:
		_workspace_context.refresh_group_saturation()
		_workspace_context.snapshot_moment(snapshot_name)
	return need_to_create_snapshot


func _screen_deselection_logic(
			in_camera: Camera3D,
			in_screen_position: Vector2,
			out_editable_structures: Array[StructureContext]) -> bool:
	
	if out_editable_structures.is_empty():
		return false
	
	var multi_structure_hit_result := MultiStructureHitResult.new(in_camera, in_screen_position, out_editable_structures)
	
	var snapshot_name: String = ""
	var did_create_undo_action: bool = false
	# If got a hit perform deselection
	if multi_structure_hit_result.did_hit():
		var hit_context: StructureContext = multi_structure_hit_result.closest_hit_structure_context
		if hit_context != get_workspace_context().get_current_structure_context():
			if not did_create_undo_action:
				snapshot_name = "Deselect Group"
				did_create_undo_action = true
			var affected_context: StructureContext = _workspace_context.get_toplevel_editable_context(hit_context)
			affected_context.clear_selection(true)
		else:
			match multi_structure_hit_result.hit_type:
				MultiStructureHitResult.HitType.HIT_ATOM:
					snapshot_name = "Deselect Atom"
					did_create_undo_action = true
					var deselected_atom_id: int = multi_structure_hit_result.closest_hit_atom_id
					var deselected_atom: PackedInt32Array = [deselected_atom_id]
					hit_context.deselect_atoms(deselected_atom)
				MultiStructureHitResult.HitType.HIT_BOND:
					snapshot_name = "Deselect Bond"
					did_create_undo_action = true
					var deselected_bond_id: int = multi_structure_hit_result.closest_hit_bond_id
					var deselected_bond: PackedInt32Array = [deselected_bond_id]
					hit_context.deselect_bonds(deselected_bond)
				MultiStructureHitResult.HitType.HIT_SHAPE:
					snapshot_name = "Deselect Shape"
					did_create_undo_action = true
					hit_context.set_shape_selected(false)
				MultiStructureHitResult.HitType.HIT_MOTOR:
					snapshot_name = "Deselect MOTOR"
					did_create_undo_action = true
					hit_context.set_motor_selected(false)
				MultiStructureHitResult.HitType.HIT_SPRING:
					snapshot_name = "Deselect Spring"
					did_create_undo_action = true
					var deselected_spring_id: int = multi_structure_hit_result.closest_hit_spring_id
					var deselected_spring: PackedInt32Array = [deselected_spring_id]
					hit_context.deselect_springs(deselected_spring)
				_:
					assert(false, "Invalid hit result")
		if did_create_undo_action:
			_workspace_context.snapshot_moment(snapshot_name)
		return true
	
	return false



func _is_select_mode_enabled() -> bool:
	var workspace_context: WorkspaceContext = get_workspace_context()
	return not workspace_context.create_object_parameters.get_create_mode_enabled()


# Shapes can be selected at all times, except when creating atoms with the
# snap to surface feature turned on.
func _is_shape_selectable() -> bool:
	var create_object_parameters: CreateObjectParameters = get_workspace_context().create_object_parameters
	var select_mode_enabled: bool = not create_object_parameters.get_create_mode_enabled()
	var is_creating_atoms: bool = create_object_parameters.get_create_mode_type() == CreateObjectParameters.CreateModeType.CREATE_ATOMS_AND_BONDS
	var snap_to_surface_enabled: bool = create_object_parameters.get_snap_to_shape_surface()
	if select_mode_enabled or not is_creating_atoms:
		return true
	return not snap_to_surface_enabled
