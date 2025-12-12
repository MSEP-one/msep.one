extends SelectionInputHandlerBase


const MAX_MOVEMENT_PIXEL_THRESHOLD_TO_DETECT_SELECTION_SQUARED = 20 * 20


var _select_connected_queued_at: int = 0
var _press_down_position: Vector2 = Vector2(-100, -100)

func _init(in_context: WorkspaceContext) -> void:
	super._init(in_context)
	in_context.history_changed.connect(_on_workspace_context_history_changed)

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
		# Selection logic needs to happen on mouse release
		# because of that we give a window of 200 msec for releasing the mouse after double click
		_select_connected_queued_at = Time.get_ticks_msec()
	
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
		var input_consumed: bool = _select_connected_selection_logic(in_camera, in_input_event.position, editable_structures, false, true)
		if input_consumed == false:
			input_consumed = _screen_deselection_logic(in_camera, in_input_event.position, editable_structures)
		if input_consumed and !get_workspace_context().has_selection():
			# Selection was cleared, DynamicContextDocker is no longer relevant
			MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
		return input_consumed
	elif in_input_event.is_action_pressed(&"multiselect", false, true):
		var input_consumed: bool = _select_connected_selection_logic(in_camera, in_input_event.position, editable_structures, true)
		if input_consumed == false:
			input_consumed = _screen_selection_logic(in_camera, in_input_event.position, editable_structures, true)
		if input_consumed:
			if MolecularEditorContext.is_workspace_docker_area_hidden_by_user(DynamicContextDocker.UNIQUE_DOCKER_NAME):
				# Do not make dockers visible when are hidden by user
				pass
			elif !get_workspace_context().has_selection():
				# Selection was cleared, DynamicContextDocker is no longer relevant
				if get_workspace_context().is_simulating():
					MolecularEditorContext.request_workspace_docker_focus(SimulationsDocker.UNIQUE_DOCKER_NAME)
				else:
					MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
			elif MolecularEditorContext.is_workspace_docker_active(GroupsDocker.UNIQUE_DOCKER_NAME):
				# User is managing groups, dont bother him/her
				pass
			elif MolecularEditorContext.msep_editor_settings.selection_tab_policy == \
						MSEPSettings.SelectionTabPolicy.FOCUS_TAB_ON_SELECTION_CHANGE:
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
		if rendering.is_particle_emitter_preview_visible():
			# Particle Emitter is being created, avoid changing selection
			return false
		if rendering.is_virtual_anchor_preview_visible():
			# Virtual Anchor and/or Spring is being created, avoid changing selection
			return false
		var input_consumed: bool = _select_connected_selection_logic(in_camera, in_input_event.position, editable_structures, false)
		if input_consumed == false:
			input_consumed = _screen_selection_logic(in_camera, in_input_event.position, editable_structures, false)
		if input_consumed:
			if MolecularEditorContext.is_workspace_docker_area_hidden_by_user(DynamicContextDocker.UNIQUE_DOCKER_NAME):
				# Do not make dockers visible when are hidden by user
				pass
			elif !get_workspace_context().has_selection():
				if MolecularEditorContext.is_workspace_docker_active(DynamicContextDocker.UNIQUE_DOCKER_NAME):
					# DynamicContextDocker docker is no longer relevant, switch to another docker if the selection docker is active
					MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME)
			elif MolecularEditorContext.msep_editor_settings.selection_tab_policy == \
						MSEPSettings.SelectionTabPolicy.FOCUS_TAB_ON_SELECTION_CHANGE:
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
				MultiStructureHitResult.HitType.HIT_MOTOR, MultiStructureHitResult.HitType.HIT_EMITTER:
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


func _on_workspace_context_history_changed() -> void:
	_update_distance_message(_workspace_context, _last_position_1, _last_position_2)


# _last_position_1 and 2 are used for re-updating distance on undo/redo and changes
var _last_position_1 := Vector3(INF, INF, INF)
var _last_position_2 := Vector3(INF, INF, INF)
func _update_distance_message(in_workspace_context: WorkspaceContext, in_position_one: Vector3,
			in_position_two: Vector3) -> void:
	_last_position_1 = in_position_one
	_last_position_2 = in_position_two
	var are_positions_valid: bool = not in_position_one.is_equal_approx(Vector3(INF, INF, INF)) and \
			not in_position_two.is_equal_approx(Vector3(INF, INF, INF))
	var distance: float = in_position_one.distance_to(in_position_two)
	var is_anything_selected: bool = in_workspace_context.has_selection()
	var should_show_distance: bool = are_positions_valid and is_anything_selected and not is_equal_approx(distance, 0.0)
	if should_show_distance:
		MolecularEditorContext.bottom_bar_update_distance(in_workspace_context, "Distance to selection center: ", distance)
		return
	# Fallback to atom selection
	var selected_contexts: Array[StructureContext] = in_workspace_context.get_structure_contexts_with_selection()
	if selected_contexts.size() == 1 \
			and selected_contexts[0].get_selected_atoms().size() == 2:
		var atom_ids: PackedInt32Array = selected_contexts[0].get_selected_atoms()
		var atomic_structure := selected_contexts[0].nano_structure as AtomicStructure
		var pos1: Vector3 = atomic_structure.atom_get_position(atom_ids[0])
		var pos2: Vector3 = atomic_structure.atom_get_position(atom_ids[1])
		distance = pos1.distance_to(pos2)
		MolecularEditorContext.bottom_bar_update_distance(in_workspace_context, "Distance between selected atoms: ", distance)
		return
	# Check if can show angle between 3 selected atoms
	if selected_contexts.size() == 1 \
			and selected_contexts[0].get_selected_atoms().size() == 3:
		var atom_ids: PackedInt32Array = selected_contexts[0].get_selected_atoms()
		var find_angle_result: Dictionary = _check_can_show_angle(selected_contexts[0].nano_structure, atom_ids)
		if find_angle_result.has_bond_angle:
			var atomic_structure := selected_contexts[0].nano_structure as AtomicStructure
			var pos1: Vector3 = atomic_structure.atom_get_position(find_angle_result.median_atom_id)
			var pos2: Vector3 = atomic_structure.atom_get_position(find_angle_result.other_atoms[0])
			var pos3: Vector3 = atomic_structure.atom_get_position(find_angle_result.other_atoms[1])
			# check for overlapping atoms
			var can_show_angle:bool = not(
				is_zero_approx(pos1.distance_squared_to(pos2)) 
				or is_zero_approx(pos1.distance_squared_to(pos3))
			)
			if can_show_angle:
				var dir1: Vector3 = pos1.direction_to(pos2)
				var dir2: Vector3 = pos1.direction_to(pos3)
				var angle: float = rad_to_deg(dir1.angle_to(dir2))
				MolecularEditorContext.bottom_bar_update_angle(in_workspace_context, "Angle between selected atoms: ", angle)
				return
	# Nothing to show
	MolecularEditorContext.bottom_bar_update_distance(in_workspace_context, "", 0.0)


func _check_can_show_angle(in_atomic_structure: AtomicStructure, atom_ids: PackedInt32Array) -> Dictionary:
	assert(in_atomic_structure)
	assert(atom_ids.size() == 3)
	atom_ids.sort()
	var result: Dictionary = {
		has_bond_angle = false,
		median_atom_id = -1,
		other_atoms = [],
	}
	# check for overlapping atoms:
	var bond_ids: Dictionary[int, Array] = {
		atom_ids[0]: in_atomic_structure.atom_get_bonds(atom_ids[0]),
		atom_ids[1]: in_atomic_structure.atom_get_bonds(atom_ids[1]),
		atom_ids[2]: in_atomic_structure.atom_get_bonds(atom_ids[2]),
	}
	var pair1 := Vector2i(atom_ids[0], atom_ids[1])
	var pair2 := Vector2i(atom_ids[0], atom_ids[2])
	var pair3 := Vector2i(atom_ids[1], atom_ids[2])
	var bond_id_pairs: Dictionary[Vector2i, Array] = {
		pair1: bond_ids[atom_ids[0]].filter(bond_ids[atom_ids[1]].has),
		pair2: bond_ids[atom_ids[0]].filter(bond_ids[atom_ids[2]].has),
		pair3: bond_ids[atom_ids[1]].filter(bond_ids[atom_ids[2]].has),
	}
	var common_bonds_count: int = (
		bond_id_pairs[pair1].size() +
		bond_id_pairs[pair2].size() +
		bond_id_pairs[pair3].size()
	)
	result.has_bond_angle = common_bonds_count == 2
	if not result.has_bond_angle:
		return result
	var common_bonds: Array = []
	common_bonds.append_array(bond_id_pairs[pair1])
	common_bonds.append_array(bond_id_pairs[pair2])
	common_bonds.append_array(bond_id_pairs[pair3])
	if bond_ids[atom_ids[0]].filter(common_bonds.has).size() == 2:
		# atom_ids[0] is the median
		result.median_atom_id = atom_ids[0]
	elif bond_ids[atom_ids[1]].filter(common_bonds.has).size() == 2:
		# atom_ids[1] is the median
		result.median_atom_id = atom_ids[1]
	elif bond_ids[atom_ids[2]].filter(common_bonds.has).size() == 2:
		# atom_ids[2] is the median
		result.median_atom_id = atom_ids[2]
	result.other_atoms = Array(atom_ids.duplicate())
	result.other_atoms.erase(result.median_atom_id)
	return result


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
				# Shapes, Motors, Emitters, Springs, etc; cannot be activated, this is on purpose to have a more compact group hierarchy
				return false
			get_workspace_context().change_current_structure_context(affected_context)
			return true
	return false


func _select_connected_selection_logic(
			in_camera: Camera3D,
			in_screen_position: Vector2,
			out_editable_structures: Array[StructureContext],
			in_is_multiselect: bool,
			in_is_deselect: bool = false) -> bool:
	if Time.get_ticks_msec() - _select_connected_queued_at > 200 or out_editable_structures.is_empty():
		return false
	
	var multi_structure_hit_result := MultiStructureHitResult.new(in_camera, in_screen_position, out_editable_structures)
	if multi_structure_hit_result.did_hit():
		# perform selection
		var hit_context: StructureContext = multi_structure_hit_result.closest_hit_structure_context
		if hit_context != get_workspace_context().get_current_structure_context():
			return false
		if multi_structure_hit_result.hit_type != MultiStructureHitResult.HitType.HIT_ATOM:
			# Bonds doesn't count
			return false
		var hit_atom: int = multi_structure_hit_result.closest_hit_atom_id
		var result: Dictionary[StringName, PackedInt32Array] = \
				hit_context.find_atoms_and_bonds_connected_to(hit_atom)
		var atoms: PackedInt32Array = result.atoms
		var bonds: PackedInt32Array = result.bonds
		var selected_atoms: PackedInt32Array = hit_context.get_selected_atoms()
		var selected_bonds: PackedInt32Array = hit_context.get_selected_bonds()
		var int_in_array: Callable = func (id: int, array: PackedInt32Array) -> bool:
			return id in array
		# Case 1: deselect connected
		if in_is_deselect:
			var any_selected: int = (
				Array(atoms).any(int_in_array.bind(selected_atoms))
				and
				Array(bonds).any(int_in_array.bind(selected_bonds))
			)
			if any_selected:
				hit_context.deselect_atoms(atoms)
				hit_context.deselect_bonds(bonds)
				_workspace_context.snapshot_moment("Change Selection")
				return true
			return false
		# When double clicking an atom and holding shift, the first click will deselect the atom
		# This is why this condition excludes it
		var atoms_without_clicked := Array(atoms.duplicate())
		atoms_without_clicked.erase(hit_atom)
		var all_except_clicked_selected: int = (
			atoms_without_clicked.all(int_in_array.bind(selected_atoms))
			and
			Array(bonds).all(int_in_array.bind(selected_bonds))
		)
		# Case 2: if all is selected, deselect it, no matter keyboard shortcuts
		if all_except_clicked_selected:
			hit_context.deselect_atoms(atoms)
			hit_context.deselect_bonds(bonds)
			_workspace_context.snapshot_moment("Change Selection")
			return true
		# Case 3: if not multiselection, deselect all before selecting atoms and bonds
		if not in_is_multiselect:
			hit_context.deselect_atoms(selected_atoms)
			hit_context.deselect_bonds(selected_bonds)
		# Case 4 (and second part of 3): select connected atoms and bonds
		hit_context.select_atoms(atoms)
		hit_context.select_bonds(bonds)
		_workspace_context.snapshot_moment("Change Selection")
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
				MultiStructureHitResult.HitType.HIT_EMITTER:
					if _is_select_mode_enabled():
						if hit_context.is_particle_emitter_selected():
							if not need_to_create_snapshot:
								snapshot_name = "Deselect Particle Emitter"
								need_to_create_snapshot = true
							hit_context.set_particle_emitter_selected(false)
						else:
							if not need_to_create_snapshot:
								snapshot_name = "Select Particle Emitter"
								need_to_create_snapshot = true
							hit_context.set_particle_emitter_selected(true)
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
					snapshot_name = "Deselect Motor"
					did_create_undo_action = true
					hit_context.set_motor_selected(false)
				MultiStructureHitResult.HitType.HIT_EMITTER:
					snapshot_name = "Deselect Particle Emitter"
					did_create_undo_action = true
					hit_context.set_particle_emitter_selected(false)
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
