class_name BoxSelection extends Control
## BoxSelection class [br]
## It's responsible for holding 'selection rectangle' info and drawing it to the screen [br]
## It also asks NanoMolecularStructure to convert that rectangle into actual selection and applies it to AtomSelection [br]

const COLOR = Color(1,1,1,0.3)
const CONTOUR_COLOR = Color(1,1,1,1)
const GROUP_SELECTION_BLACKLIST = [&"AnchorPoint"]


signal region_changed(new_region: Rect2)


var _rect: Rect2i = Rect2i()
var _is_enabled: bool = false
var _workspace_context: WorkspaceContext


func init(in_context: WorkspaceContext) -> void:
	_workspace_context = in_context


func start_selection(in_start_point: Vector2i) -> void:
	_rect.position = in_start_point
	_rect.end = in_start_point
	_is_enabled = true
	show()
	region_changed.emit(Rect2(_rect))


func apply_selection() -> void:
	if not is_instance_valid(_workspace_context):
		# not initialized yet
		hide()
		return
	
	_is_enabled = false
	hide()
	region_changed.emit(Rect2())
	
	var camera: Camera3D = _workspace_context.get_camera()
	var editable_structure_contexts: Array[StructureContext] = _workspace_context.get_editable_structure_contexts()
	
	#
	var handled_contexts: Dictionary = {
		#context<StructureContext> = true<bool>
	}
	
	for context: StructureContext in editable_structure_contexts:
		var handle_as_group: bool = (not context == _workspace_context.get_current_structure_context()) \
				and not context.nano_structure.get_type() in GROUP_SELECTION_BLACKLIST
		if handle_as_group:
			context = _workspace_context.get_toplevel_editable_context(context)
		if handled_contexts.get(context, false) == true:
			continue
		handled_contexts[context] = true
		var collision_engine: CollisionEngine = context.get_collision_engine()
		var selected_atoms: PackedInt32Array = collision_engine.get_atoms_colliding_with_screen_rectangle(camera, _rect)
		var selected_springs: PackedInt32Array = collision_engine.find_springs_colliding_with_screen_rectangle(camera, _rect)
		assert(_are_all_atoms_visible(selected_atoms, context), "error: CollisionEngine is detecting collisions with invisible atoms")
		if handle_as_group:
			var group_selected: bool = not selected_atoms.is_empty() or not selected_springs.is_empty()
			if group_selected:
				context.select_all(true)
			else:
				for other_context: StructureContext in editable_structure_contexts:
					var is_child_of_context: bool = _workspace_context.workspace.is_a_ancestor_of_b(context.nano_structure, other_context.nano_structure)
					if not is_child_of_context or other_context.nano_structure.get_type() in GROUP_SELECTION_BLACKLIST:
						continue
					if other_context.nano_structure.is_virtual_object() and _is_virtual_object_within_screen_rect(other_context, camera):
						context.select_all(true)
						break
					collision_engine = other_context.get_collision_engine()
					selected_atoms = collision_engine.get_atoms_colliding_with_screen_rectangle(camera, _rect)
					assert(_are_all_atoms_visible(selected_atoms, other_context), "error: CollisionEngine is detecting collisions with invisible atoms")
					if not selected_atoms.is_empty():
						context.select_all(true)
						break
		else:
			if context.nano_structure is AtomicStructure:
				var selected_bonds: PackedInt32Array = context.select_atoms_and_get_auto_selected_bonds(selected_atoms)
				context.select_bonds(selected_bonds)
				context.select_springs(selected_springs)
		if context.nano_structure.is_virtual_object() and _is_virtual_object_within_screen_rect(context, camera):
			context.set_virtual_object_selected(true)


func _are_all_atoms_visible(in_atoms: PackedInt32Array, in_context: StructureContext) -> bool:
	for atom_id in in_atoms:
		if not in_context.nano_structure.is_atom_visible(atom_id):
			return false
	return true


func apply_deselection() -> void:
	if not is_instance_valid(_workspace_context):
		# not initialized yet
		return
	
	_is_enabled = false
	hide()
	region_changed.emit(Rect2())
	
	var camera: Camera3D = _workspace_context.get_camera()
	var editable_structure_contexts: Array[StructureContext] = _workspace_context.get_editable_structure_contexts()
	
	#
	var handled_contexts: Dictionary = {
	#	context<StructureContext> = true<bool>
	}

	for context: StructureContext in editable_structure_contexts:
		var handle_as_group: bool = (not context == _workspace_context.get_current_structure_context()) \
				and not context.nano_structure.get_type() in GROUP_SELECTION_BLACKLIST
		if handle_as_group:
			context = _workspace_context.get_toplevel_editable_context(context)
		if handled_contexts.get(context, false) == true:
			continue
		handled_contexts[context] = true
		var collision_engine: CollisionEngine = context.get_collision_engine()
		var deselected_atoms: PackedInt32Array = collision_engine.get_atoms_colliding_with_screen_rectangle(camera, _rect)
		if handle_as_group:
			if not deselected_atoms.is_empty():
				context.clear_selection(true)
			else:
				for other_context: StructureContext in editable_structure_contexts:
					var is_child_of_context: bool = _workspace_context.workspace.is_a_ancestor_of_b(context.nano_structure, other_context.nano_structure)
					if not is_child_of_context or other_context.nano_structure.get_type() in GROUP_SELECTION_BLACKLIST:
						continue
					if other_context.nano_structure.is_virtual_object() and _is_virtual_object_within_screen_rect(other_context, camera):
						context.clear_selection(true)
						break
					collision_engine = other_context.get_collision_engine()
					deselected_atoms = collision_engine.get_atoms_colliding_with_screen_rectangle(camera, _rect)
					assert(_are_all_atoms_visible(deselected_atoms, other_context), "error: CollisionEngine is detecting collisions with invisible atoms")
					if not deselected_atoms.is_empty():
						context.clear_selection(true)
						break
		else:
			if context.nano_structure is AtomicStructure:
				var deselected_bonds: PackedInt32Array = collision_engine.get_bonds_colliding_with_screen_rectangle(camera, _rect)
				var deselected_springs: PackedInt32Array = collision_engine.find_springs_colliding_with_screen_rectangle(camera, _rect)
				context.deselect_atoms(deselected_atoms)
				context.deselect_bonds(deselected_bonds)
				context.deselect_springs(deselected_springs)
		if context.nano_structure.is_virtual_object() and _is_virtual_object_within_screen_rect(context, camera):
			context.set_virtual_object_selected(false)
	
	#
	_workspace_context.snapshot_moment("Box Deselection")


func _is_virtual_object_within_screen_rect(in_context: StructureContext, in_camera: Camera3D) -> bool:
	assert(in_context.nano_structure.is_virtual_object())
	if in_context.nano_structure is NanoShape:
		return in_context.nano_structure.is_shape_within_screen_rect(in_camera, _rect)
	if in_context.nano_structure is NanoVirtualMotor:
		return in_context.nano_structure.is_motor_within_screen_rect(in_camera, _rect)
	if in_context.nano_structure is NanoVirtualAnchor:
		return in_context.nano_structure.is_anchor_within_screen_rect(in_camera, _rect)
	return false


func is_enabled() -> bool:
	return _is_enabled


## should be called each time the rectangle is modified[br]
## [code]in_current_point[/code] is new end point for the selection rectangle
func update(in_current_point: Vector2i) -> void:
	_rect.end = in_current_point
	queue_redraw()
	region_changed.emit(Rect2(_rect))


func _draw() -> void:
	if not _is_enabled:
		return
	
	draw_rect(_rect, COLOR, true)
	
	var line_points := PackedVector2Array()
	line_points.append(_rect.position)
	line_points.append(Vector2(_rect.end.x, _rect.position.y))
	line_points.append(_rect.end)
	line_points.append(Vector2(_rect.position.x, _rect.end.y))
	line_points.append(_rect.position)
	draw_polyline(line_points, CONTOUR_COLOR, 2)
