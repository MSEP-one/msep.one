extends InputHandlerBase

var _stop_exclusivity: bool = false
var _previous_frame_grab_mode: GizmoRoot.GrabMode = GizmoRoot.GrabMode.NONE
var _helper: TransformHelper = TransformHelper.new()

var _capturing_inputs: bool = false

var _structure_context_2_initial_atom_selection_positions: Dictionary = {
#	structure_context_id<int> = position_data<Array[AtomPosition]>
}
var _structure_context_2_initial_object_transforms: Dictionary = {
#	structure_context_id<int> = transform<Transform3D>
}
var _selection_initial_position: Vector3 = Vector3()
var _is_grabbed: bool = false

# region: virtual

## VIRTUAL: Returns true when the the input handler expects to process inputs
## when nothing is selected in the Object tree view
func handles_empty_selection() -> bool:
	return false


## VIRTUAL: Returns true when the the input handler expects to process inputs
## based on an active NanoStructure. This may depend on the active StructureOperator(s)
func handles_structure_context(in_structure_context: StructureContext) -> bool:
	if in_structure_context.nano_structure == null:
		return false
	return true


# TODO: handle selection changed
func _init(in_context: WorkspaceContext) -> void:
	super(in_context)
	if !_helper.transform_changed.is_connected(_on_helper_transform_changed):
		_helper.transform_changed.connect(_on_helper_transform_changed)
	in_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
	in_context.atoms_position_in_structure_changed.connect(_on_atoms_position_in_structure_changed)
	in_context.virtual_object_transform_changed.connect(_on_virtual_object_transform_changed)
	in_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
	
	
	if is_instance_valid(in_context.get_current_structure_context()):
		_prepare_gizmo_for_structures([in_context.get_current_structure_context()])
	
	MolecularEditorContext.workspace_activated.connect(_on_workspace_activated)
	
	in_context.atoms_relaxation_started.connect(_on_workspace_context_atom_relaxation_started)
	in_context.atoms_relaxation_finished.connect(_on_workspace_context_atoms_relaxation_finished)
	
	in_context.register_snapshotable(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Manually free TransformHelper that may not be in the tree
		#+This avoids leaks when exit the application
		if is_instance_valid(_helper):
			_helper.queue_free()


func _on_workspace_activated(in_workspace: Workspace) -> void:
	if get_workspace_context() == null:
		return
	if in_workspace == get_workspace_context().workspace:
		_force_gizmo_update()


func _on_workspace_context_selection_in_structures_changed(in_structure_contexts: Array[StructureContext]) -> void:
	_prepare_gizmo_for_structures(in_structure_contexts)


func _on_workspace_context_structure_about_to_remove(_in_removed_structure: NanoStructure) -> void:
	if not get_workspace_context().has_transformable_selection():
		GizmoRoot.disable_gizmo()
	_structure_context_2_initial_atom_selection_positions.erase(_in_removed_structure.get_int_guid())
	_structure_context_2_initial_object_transforms.erase(_in_removed_structure.get_int_guid())


func _prepare_gizmo_for_structures(in_structure_contexts: Array[StructureContext]) -> void:
	if in_structure_contexts.is_empty():
		return

	var viewport: WorkspaceEditorViewport = in_structure_contexts[0].get_edit_subviewport()
	if _helper.get_parent():
		_helper.get_parent().remove_child(_helper)
		
	viewport.add_child(_helper)
	_force_gizmo_update()


func _init_initial_positions_and_determine_center() -> Vector3:
	var selection_size: int = 0
	var center_pos: Vector3 = Vector3()
	
	_structure_context_2_initial_atom_selection_positions.clear()
	_structure_context_2_initial_object_transforms.clear()
	
	var structures_to_update: Array[StructureContext] = get_workspace_context().get_structure_contexts_with_transformable_selection()
	for context in structures_to_update:
		
		# Phase 1: Atoms
		_structure_context_2_initial_atom_selection_positions[context.get_int_guid()] = []
		var selection: PackedInt32Array = context.get_selected_atoms()
		selection_size += selection.size()
		for atom_id in selection:
			var atom_init_pos: Vector3 = context.nano_structure.atom_get_position(atom_id)
			_structure_context_2_initial_atom_selection_positions[context.get_int_guid()].append(AtomPosition.new(atom_id, atom_init_pos))
			center_pos += atom_init_pos
		
		# Phase 2: Transformable Objects
		if context.nano_structure.has_transform():
			if context.is_shape_selected() or context.is_motor_selected():
				selection_size += 1
				center_pos += context.nano_structure.get_transform().origin
				_structure_context_2_initial_object_transforms[context.get_int_guid()] = context.nano_structure.get_transform()
		elif context.is_anchor_selected():
			# Anchors has position but not rotation
			selection_size += 1
			center_pos += context.nano_structure.get_position()
			_structure_context_2_initial_object_transforms[context.get_int_guid()] = Transform3D(Basis(), context.nano_structure.get_position())
	
	assert(selection_size > 0, "selection is empty, gizmo should be disabled and this function should not be called")
	return center_pos / selection_size


## When _handles_state(context, edit_mode) is true this method will be
## called for every mouse move, click, key press, etc
## returns true if the input event was handled, avoiding other input handlers
## to continue
func forward_input(in_input_event: InputEvent, _in_camera: Camera3D, in_context: StructureContext) -> bool:
	if not get_workspace_context().has_transformable_selection():
		# Disable the gizmo if only bonds are selected
		if GizmoRoot.gizmo_state == GizmoRoot.GizmoState.ENABLED:
			GizmoRoot.disable_gizmo()
		return false
	if GizmoRoot.selected_node == _helper and \
		GizmoRoot.gizmo_state == GizmoRoot.GizmoState.DISABLED:
		# Input was ommited and gizmo was hidden, show it again
		GizmoRoot.enable_gizmo()
	if GizmoRoot.selected_node == _helper and \
		GizmoRoot.gizmo_state == GizmoRoot.GizmoState.ENABLED and \
		(GizmoRoot.grab_mode != GizmoRoot.GrabMode.NONE || \
		_previous_frame_grab_mode != GizmoRoot.GrabMode.NONE):
		if _previous_frame_grab_mode == GizmoRoot.GrabMode.NONE:
			_capturing_inputs = true
		_previous_frame_grab_mode = GizmoRoot.grab_mode
		if in_input_event is InputEventMouseButton:
			var just_grabbed: bool = in_input_event.is_pressed()
			if just_grabbed:
				_is_grabbed = true
				_prepare_gizmo_for_structures([in_context])
			
			var just_released: bool = not in_input_event.is_pressed() and _is_grabbed
			if just_released:
				_is_grabbed = false
				_apply_selection_transform()
		return true
	
	_previous_frame_grab_mode = GizmoRoot.grab_mode
	if in_input_event is InputEventMouse:
		if in_input_event.is_pressed():
			_stop_exclusivity = false
		else:
			_stop_exclusivity = true
			if _is_grabbed:
				_is_grabbed = false
				_apply_selection_transform()
		if GizmoRoot.gizmo_state == GizmoRoot.GizmoState.ENABLED \
		and GizmoRoot.grab_mode == GizmoRoot.GrabMode.NONE:
			for is_hovering: bool in GizmoRoot.mouse_hover_detected.values():
				if is_hovering:
					return true
	_capturing_inputs = false
	return false


func is_exclusive_input_consumer() -> bool:
	if _stop_exclusivity:
		return false
	if _capturing_inputs or _is_grabbed:
		return true
	for mouse_hover: bool in GizmoRoot.mouse_hover_detected.values():
		if mouse_hover && GizmoRoot.grab_mode != GizmoRoot.GrabMode.NONE:
			return true
	return false


func handle_inputs_end() -> void:
	if _is_grabbed:
		_is_grabbed = false
		_apply_selection_transform()
		GizmoRoot.grab_mode = GizmoRoot.GrabMode.NONE
	GizmoRoot.disable_gizmo()


## Hides the transform gizmo when creating atoms chains
func handle_input_served() -> void:
	var rendering: Rendering = get_workspace_context().get_rendering()
	if rendering.is_bond_preview_visible():
		GizmoRoot.disable_gizmo()


func get_priority() -> int:
	return BuiltinInputHandlerPriorities.TRANSFORM_SELECTION_HANDLER_PRIORITY


func _apply_selection_transform() -> void:
	var selected_structure_contexts: Array[StructureContext] = get_workspace_context().get_structure_contexts_with_transformable_selection()
	if selected_structure_contexts.is_empty():
		return
	
	var action_created: bool = false
	
	var rendering: Rendering = get_workspace_context().get_rendering()
	for context: StructureContext in selected_structure_contexts:
		var nano_structure: NanoStructure = context.nano_structure
		if nano_structure is AtomicStructure:
			rendering.set_atom_selection_position_delta(Vector3(), nano_structure)
			rendering.rotate_atom_selection_around_point(_helper.global_transform.origin, Basis(), nano_structure)
		
		var object_old_transform: Transform3D
		var object_new_transform: Transform3D
		if nano_structure.has_transform():
			assert(_structure_context_2_initial_object_transforms.has(context.get_int_guid()), "initial transform should be prepared in '_prepare_gizmo_for_structure()'")
			object_old_transform = nano_structure.get_transform()
			var initial_nano_struct_transform: Transform3D = _structure_context_2_initial_object_transforms[context.get_int_guid()]
			var helper_basis: Basis = _helper.global_transform.affine_inverse().basis.transposed()
			var transform := Transform3D(helper_basis, _helper.global_transform.origin)
			var relative_transform: Transform3D = transform * initial_nano_struct_transform
			var final_transform: Transform3D = Transform3D(relative_transform.basis, relative_transform.origin)
			var delta_pos: Vector3 = initial_nano_struct_transform.origin - _selection_initial_position
			var new_pos: Vector3 = _helper.global_position + _helper.global_transform.basis * delta_pos
			object_new_transform = Transform3D(final_transform.basis.orthonormalized(), new_pos)
			object_old_transform = nano_structure.get_transform()
		elif nano_structure is NanoVirtualAnchor:
			# Anchors have position but not rotation and scale
			assert(_structure_context_2_initial_object_transforms.has(context.get_int_guid()), "initial transform should be prepared in '_prepare_gizmo_for_structure()'")
			object_old_transform.origin = nano_structure.get_position()
			var initial_nano_struct_transform: Transform3D = _structure_context_2_initial_object_transforms[context.get_int_guid()]
			var delta_pos: Vector3 = initial_nano_struct_transform.origin - _selection_initial_position
			var new_pos: Vector3 = _helper.global_position + _helper.global_transform.basis * delta_pos
			object_new_transform = Transform3D(Basis(), new_pos)
		
		var atoms_to_move: PackedInt32Array = []
		var previous_positions: PackedVector3Array = []
		var target_positions: PackedVector3Array = []
		var nmb_of_moved_atoms: int = 0
		var remote_atom_transforms: Array = _structure_context_2_initial_atom_selection_positions[context.get_int_guid()]
		for atom_transform: AtomPosition in remote_atom_transforms:
			var atom_id: int = atom_transform.atom_id
			var old_pos: Vector3 = nano_structure.atom_get_position(atom_id)
			var delta_pos: Vector3 = atom_transform.atom_initial_position - _selection_initial_position
			var new_pos: Vector3 = _helper.global_position + _helper.global_transform.basis * delta_pos
			atoms_to_move.push_back(atom_id)
			target_positions.push_back(new_pos)
			previous_positions.push_back(old_pos)
			nmb_of_moved_atoms += 1
		
		# Phase 3: Flush
		var atoms_changed: bool = nmb_of_moved_atoms > 0
		var object_moved: bool = context.is_shape_selected() or context.is_motor_selected()
		var anchor_moved: bool = context.is_anchor_selected()
		if atoms_changed or object_moved or anchor_moved:
			if atoms_changed:
				nano_structure.start_edit()
				nano_structure.atoms_set_positions(atoms_to_move, target_positions)
				nano_structure.end_edit()
			if object_moved:
				nano_structure.set_transform(object_new_transform)
			if anchor_moved:
				nano_structure.set_position(object_new_transform.origin)
			
			if !action_created:
				action_created = true
	
	if action_created:
		_workspace_context.snapshot_moment("Move Selection")
		_force_gizmo_update()


func _get_gizmo_center_position() -> Vector3:
	if not GizmoRoot.is_active():
		return Vector3()
	
	var selection_size: int = 0
	var center_pos: Vector3 = Vector3()
	
	var structures_to_update: Array[StructureContext] = get_workspace_context().get_structure_contexts_with_transformable_selection()
	for context in structures_to_update:
		
		# Phase 1: Atoms
		var selection: PackedInt32Array = context.get_selected_atoms()
		selection_size += selection.size()
		for atom_id in selection:
			var atom_init_pos: Vector3 = context.nano_structure.atom_get_position(atom_id)
			center_pos += atom_init_pos
		
		# Phase 2: Objects with Transform3D
		if context.nano_structure.has_transform():
			if context.is_shape_selected() or context.is_motor_selected():
				selection_size += 1
				center_pos += context.nano_structure.get_transform().origin
		elif context.is_anchor_selected():
			selection_size += 1
			center_pos += context.nano_structure.get_position()
	
	assert(selection_size > 0, "selection is empty, gizmo should be disabled and this function should not be called")
	return center_pos / selection_size


func _reset_gizmo_pos(in_gizmo_pos: Vector3) -> void:
	_helper.global_transform.basis = Basis()
	_helper.global_position = in_gizmo_pos


func _on_helper_transform_changed(in_translation_changed: bool, in_rotation_changed: bool) -> void:
	if not _is_grabbed:
		return
	_set_tracking_transforms(false)
	var selected_structure_contexts: Array[StructureContext] = get_workspace_context().get_structure_contexts_with_transformable_selection()
	if selected_structure_contexts.is_empty():
		return
	
	var delta: Vector3 = _selection_initial_position - _helper.global_position
	var rendering: Rendering = get_workspace_context().get_rendering()
	for context in selected_structure_contexts:
		var nano_structure: NanoStructure = context.nano_structure
		if nano_structure.has_transform() or nano_structure is NanoVirtualAnchor:
			var initial_nano_struct_transform: Transform3D = _structure_context_2_initial_object_transforms[context.get_int_guid()]
			rendering.transform_object_by_external_transform(context.nano_structure, _selection_initial_position,
					initial_nano_struct_transform, _helper.global_transform)
		else:
			if in_translation_changed:
				rendering.set_atom_selection_position_delta(-delta, nano_structure)
			if in_rotation_changed:
				rendering.rotate_atom_selection_around_point(_helper.global_transform.origin,
						_helper.global_transform.basis, nano_structure)
	
	_set_tracking_transforms(true)


## Called when the atoms positions are modified, either because the user moved
## the gizmo, or because of an external modification (ex: the selection panel)
## Ensures the transform helper is at the right position
func _on_atoms_position_in_structure_changed(_structure_context: StructureContext, _in_atoms: PackedInt32Array) -> void:
	if _capturing_inputs or !get_workspace_context().has_transformable_selection():
		return
	_helper.position = _get_gizmo_center_position()


func _on_virtual_object_transform_changed(_structure_context: StructureContext) -> void:
	if _capturing_inputs or !get_workspace_context().has_transformable_selection():
		return
	_helper.position = _get_gizmo_center_position()


func _on_workspace_context_atoms_relaxation_finished(error: String) -> void:
	if not get_workspace_context().has_transformable_selection() or not error.is_empty():
		return
	
	_set_tracking_transforms(false)
	GizmoRoot.selected_node.global_position = _init_initial_positions_and_determine_center()
	await GizmoRoot.get_tree().process_frame
	_set_tracking_transforms(true)
	GizmoRoot.enable_gizmo()


func _on_workspace_context_atom_relaxation_started() -> void:
	if !get_workspace_context().has_transformable_selection():
		return
	
	GizmoRoot.disable_gizmo()


func _force_gizmo_update() -> void:
	if not GizmoRoot.is_active():
		return
	
	var structures_to_update: Array[StructureContext] = get_workspace_context().get_structure_contexts_with_transformable_selection()
	for ctx_id: int in _structure_context_2_initial_atom_selection_positions.keys():
		var structure_context: StructureContext = _workspace_context.get_structure_context(ctx_id)
		if !structures_to_update.has(structure_context):
			structures_to_update.push_back(structure_context)
	for ctx_id: int in _structure_context_2_initial_object_transforms.keys():
		var ctx: StructureContext = _workspace_context.get_structure_context(ctx_id)
		if !structures_to_update.has(ctx):
			structures_to_update.push_back(ctx)
	
	if not structures_to_update.is_empty():
		_set_tracking_transforms(false)
		GizmoRoot.setup_gizmo(_helper, structures_to_update.front().get_edit_subviewport())
		var selection_size: int = 0
		var has_transformable_objects_selected: bool = false
		for context in structures_to_update:
			var selection: PackedInt32Array = context.get_selected_atoms()
			selection_size += selection.size()
			if context.nano_structure.has_transform():
				if context.is_shape_selected() or context.is_motor_selected():
					selection_size += 1
					has_transformable_objects_selected = true
			elif context.is_anchor_selected():
				selection_size += 1
				# Anchors does not trigger `has_transformable_objects_selected = true` because they dont rotate
		
		if selection_size == 0:
			# Selection cannot be transformed
			_hide_gizmo()
			return
		
		_set_tracking_transforms(true)
		GizmoRoot.enable_gizmo()
		# Remove local transform setings
		GizmoRoot.remove_translation_axes()
		GizmoRoot.remove_rotation_arcs()
		GizmoRoot.remove_translation_surfaces()
		GizmoRoot.remove_center_drag()
		GizmoRoot.add_ortho_translation_axes()
		GizmoRoot.add_ortho_translation_surfaces()
		# Instead show global transform settings, except scale, makes not sense on Atoms
		if selection_size > 1 || has_transformable_objects_selected:
			GizmoRoot.add_ortho_rotation_arcs()
		else:
			GizmoRoot.remove_ortho_rotation_arcs()
	else:
		_hide_gizmo()
	
	if GizmoRoot.gizmo_state == GizmoRoot.GizmoState.ENABLED:
		_selection_initial_position = _init_initial_positions_and_determine_center()
		_helper.global_transform.basis = Basis()
		_helper.global_position = _selection_initial_position


func _hide_gizmo() -> void:
	GizmoRoot.disable_gizmo()
	_structure_context_2_initial_atom_selection_positions.clear()
	_structure_context_2_initial_object_transforms.clear()


func _set_tracking_transforms(in_enabled: bool) -> void:
	_helper.set_tracking_transforms(in_enabled)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"_stop_exclusivity" = _stop_exclusivity,
		"_previous_frame_grab_mode" = _previous_frame_grab_mode,
		"_helper.global_transform" = _helper.global_transform if _helper.is_inside_tree() else Transform3D(),
		"_capturing_inputs" = _capturing_inputs,
		"_structure_context_2_initial_atom_selection_positions" = _structure_context_2_initial_atom_selection_positions.duplicate(),
		"_structure_context_2_initial_object_transforms" = _structure_context_2_initial_object_transforms.duplicate(),
		"_selection_initial_position" = _selection_initial_position,
		"_is_grabbed" = _is_grabbed
	}
	return snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_stop_exclusivity = in_state_snapshot["_stop_exclusivity"]
	_previous_frame_grab_mode = in_state_snapshot["_previous_frame_grab_mode"]
	_helper.global_transform = in_state_snapshot["_helper.global_transform"]
	_capturing_inputs = in_state_snapshot["_capturing_inputs"]
	_structure_context_2_initial_atom_selection_positions = in_state_snapshot["_structure_context_2_initial_atom_selection_positions"].duplicate()
	_structure_context_2_initial_object_transforms = in_state_snapshot["_structure_context_2_initial_object_transforms"].duplicate()
	_selection_initial_position = in_state_snapshot["_selection_initial_position"]
	_is_grabbed = in_state_snapshot["_is_grabbed"]
	_force_gizmo_update()


class TransformHelper extends Node3D:
	signal transform_changed(in_translation_changed: bool, in_rotation_changed: bool)
	var last_known_transform := Transform3D()
	func _init() -> void:
		set_tracking_transforms(true)
	func _enter_tree() -> void:
		last_known_transform = global_transform
	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			if global_transform == last_known_transform:
				return
			if last_known_transform.origin != global_transform.origin:
				transform_changed.emit(true, false)
			if last_known_transform.basis != global_transform.basis:
				transform_changed.emit(false, true)
			last_known_transform = global_transform
	
	func set_tracking_transforms(in_enabled: bool) -> void:
		if in_enabled and is_inside_tree():
			last_known_transform = global_transform
		set_notify_transform(in_enabled)


class AtomPosition:
	var atom_id: int
	var atom_initial_position: Vector3 = Vector3()
	
	func _init(in_atom_id: int, in_atom_initial_position: Vector3) -> void:
		atom_id = in_atom_id
		atom_initial_position = in_atom_initial_position
		
