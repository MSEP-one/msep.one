extends Control

var rendering: Rendering
var editor_viewport: WorkspaceEditorViewport
var workspace_context: WorkspaceContext: set = _set_workspace_context

var _ring_menu: NanoRingMenu
var _message_bar: MessageBar
var _canvas_layer: CanvasLayer
var _editor_widgets_container: EditorWidgetsContainer
var _camera_widget: CameraWidget
var _axes_widget: AxesWidget
var _orientation_widget: OrientationWidget


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		rendering = $EditorViewport/Rendering
		editor_viewport = $EditorViewport
		_ring_menu = %NanoRingMenu
		_editor_widgets_container = %EditorWidgetsContainer
		_camera_widget = %CameraWidget
		_message_bar = %MessageBar as MessageBar
		_canvas_layer = $CanvasLayer
		_axes_widget = %AxesWidget
		_orientation_widget = %OrientationWidget
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)


func _ready() -> void:
	assert(editor_viewport.workspace_tools_container, "workspace_tools_container is not assigned to main_view!")
	var main_view: WorkspaceMainView = editor_viewport.workspace_tools_container.owner as WorkspaceMainView
	_editor_widgets_container.set_workspace_tools_reference(editor_viewport.workspace_tools_container)
	_orientation_widget.set_workspace_tools_reference(editor_viewport.workspace_tools_container)
	_axes_widget.set_working_area_rect_control(main_view.get_working_area_rect_control())
	get_box_selection().region_changed.connect(_on_box_selection_region_changed)
	visibility_changed.connect(_on_visibility_changed)
	GizmoRoot.rotation_changing.connect(_on_show_transform_rotation_message)
	GizmoRoot.rotation_ended.connect(_on_transform_rotation_ended)


func _set_workspace_context(in_workspace_context: WorkspaceContext) -> void:
	if workspace_context == in_workspace_context:
		return
	if workspace_context != null:
		workspace_context.selection_in_structures_changed.disconnect(
				_on_workspace_context_selection_in_structures_changed)
		workspace_context.structure_removed.disconnect(
			_on_workspace_context_structure_about_to_remove)
		workspace_context.hydrogen_atoms_count_corrected.disconnect(
				_on_object_hydrogen_atoms_count_change)
		workspace_context.bonds_auto_created.disconnect(
				_on_workspace_context_bonds_auto_created)
		workspace_context.atoms_added_to_structure.disconnect(
				_on_workspace_context_atoms_added_to_structure)
		workspace_context.history_snapshot_created.disconnect(
				_on_history_snapshot_created)
		workspace_context.history_previous_snapshot_applied.disconnect(
				_on_history_previous_snapshot_applied)
		workspace_context.history_next_snapshot_applied.disconnect(
				_on_history_next_snapshot_applied)
		workspace_context.history_changed.disconnect(
				_on_history_changed)
	
	workspace_context = in_workspace_context
	editor_viewport._workspace_context = in_workspace_context
	workspace_context.selection_in_structures_changed.connect(
			_on_workspace_context_selection_in_structures_changed)
	workspace_context.structure_about_to_remove.connect(
		_on_workspace_context_structure_about_to_remove)
	workspace_context.hydrogen_atoms_count_corrected.connect(
			_on_object_hydrogen_atoms_count_change)
	workspace_context.bonds_auto_created.connect(
			_on_workspace_context_bonds_auto_created)
	workspace_context.atoms_added_to_structure.connect(
			_on_workspace_context_atoms_added_to_structure)
	workspace_context.history_snapshot_created.connect(
			_on_history_snapshot_created)
	workspace_context.history_previous_snapshot_applied.connect(
			_on_history_previous_snapshot_applied)
	workspace_context.history_next_snapshot_applied.connect(
			_on_history_next_snapshot_applied)
	workspace_context.history_changed.connect(
			_on_history_changed)


func get_rendering() -> Rendering:
	return rendering


func get_box_selection() -> BoxSelection:
	return editor_viewport.get_box_selection()


func get_ring_menu() -> NanoRingMenu:
	return _ring_menu


func get_camera_widget() -> CameraWidget:
	return _camera_widget


func show_warning_in_message_bar(in_message: String) -> void:
	_message_bar.show_warning(in_message)


func bottom_bar_update_distance(in_message_text: String, in_distance: float) -> void:
	_message_bar.update_distance(in_message_text, in_distance)


func _on_show_transform_rotation_message(_in_dir_vec: Vector3, _in_degrees: float, \
		_in_degrees_formatted_string: String) -> void:
	if !is_visible_in_tree():
		return
	_message_bar.show_message(_in_degrees_formatted_string)


func _on_transform_rotation_ended() -> void:
	if !is_visible_in_tree():
		return
	_message_bar.clear()


# region: internal

func _on_mouse_entered() -> void:
	editor_viewport.set_input_forwarding_enabled(true)


func _on_mouse_exited() -> void:
	if not is_instance_valid(workspace_context):
		# Dont process this if workspace just closed
		# This can happen if the workspace was closed with shortcuts commands while
		# the mouse pointer was over the viewport
		return
	if Input.get_mouse_button_mask() != 0:
		# Do not interrupt input if a drag gesture is happening.
		return
	editor_viewport.set_input_forwarding_enabled(false)


func _on_workspace_context_selection_in_structures_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	_message_bar.show_message(_create_selection_description_message())


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure) -> void:
	_message_bar.show_message(_create_selection_description_message())


func _create_selection_description_message() -> String:
	var contexts_with_selection: Array[StructureContext] = \
		workspace_context.get_structure_contexts_with_selection()
	var selection_count: int = _get_selected_atoms_count(contexts_with_selection)
	if selection_count in [0, 1]:
		if _get_selected_bonds_count(contexts_with_selection) == 1:
			for structure_context: StructureContext in contexts_with_selection:
				var selected_bonds: PackedInt32Array = structure_context.get_selected_bonds()
				if selected_bonds.is_empty():
					continue
				assert(selected_bonds.size() == 1)
				var atomic_structure: AtomicStructure = structure_context.nano_structure
				var bond: Vector3i = atomic_structure.get_bond(selected_bonds[0])
				var atom1: int = bond.x
				var atom2: int = bond.y
				var bond_length: float = atomic_structure.atom_get_position(atom1).distance_to(
						atomic_structure.atom_get_position(atom2))
				return "Bond Length: %.5f %s" % [bond_length * Units.get_distance_conversion_factor(),
						Units.get_distance_unit_string()]
		return ""
	if selection_count == 2:
		var selected_objects_positions: Array[Vector3] = []
		for structure_context: StructureContext in contexts_with_selection:
			var selected_atoms: PackedInt32Array = structure_context.get_selected_atoms()
			for atom in selected_atoms:
				selected_objects_positions.append(structure_context.nano_structure.atom_get_position(atom))
		assert(selected_objects_positions.size() == 2, "There should be exactly 2 atoms selected")
		return "Distance: %.5f %s" % \
			[selected_objects_positions[0].distance_to(selected_objects_positions[1])
			* Units.get_distance_conversion_factor(),
			Units.get_distance_unit_string()]
	# Atom selection count is 3 or more
	var selection_aabb: AABB = workspace_context.get_selection_aabb()
	var selection_aabb_size: Vector3 = selection_aabb.size.abs()
	return "Width: %.5f %s Height: %.5f %s Depth: %.5f %s" % [
		selection_aabb_size.x * Units.get_distance_conversion_factor(),
		Units.get_distance_unit_string(),
		selection_aabb_size.y * Units.get_distance_conversion_factor(),
		Units.get_distance_unit_string(),
		selection_aabb_size.z * Units.get_distance_conversion_factor(),
		Units.get_distance_unit_string()
	]


func _get_selected_atoms_count(in_contexts_with_selection: Array[StructureContext]) -> int:
	var selected_objects_count: int = 0
	for context in in_contexts_with_selection:
		var structure_context: StructureContext = context
		selected_objects_count += structure_context.get_selected_atoms().size()
	return selected_objects_count


func _get_selected_bonds_count(in_contexts_with_selection: Array[StructureContext]) -> int:
	var selected_objects_count: int = 0
	for context in in_contexts_with_selection:
		var structure_context: StructureContext = context
		selected_objects_count += structure_context.get_selected_bonds().size()
	return selected_objects_count


func _on_box_selection_region_changed(in_new_region: Rect2) -> void:
	if in_new_region.size == Vector2.ZERO:
		_message_bar.show_message(_create_selection_description_message())
		return
	_message_bar.show_message(_create_selection_message(in_new_region))
	

func _create_selection_message(in_new_region: Rect2) -> String:
	return "Start position: [%d, %d] - Size [%dpx, %dpx] - Distance: %.2fpx" % [
		in_new_region.position.x,
		in_new_region.position.y,
		in_new_region.size.abs().x,
		in_new_region.size.abs().y,
		in_new_region.position.distance_to(in_new_region.end)
	]


func _on_object_hydrogen_atoms_count_change(in_added: int, in_removed: int) -> void:
	_message_bar.show_message(_describe_hydrogen_atoms_correction_action(in_added, in_removed))


func _on_workspace_context_bonds_auto_created(in_added: int) -> void:
	_message_bar.show_message("%s Bond%s created." % [in_added, "" if in_added == 1 else "s"])


func _on_workspace_context_atoms_added_to_structure(
		in_structure_context: StructureContext,
		in_atom_ids: PackedInt32Array) -> void:
	
	# 1. "Grow" the list of atoms to include R1 atoms connected to this atoms
	var atoms_to_test: Dictionary = {
	#	atom_id<int> = true<bool>
	}
	for atom_id: int in in_atom_ids:
		atoms_to_test[atom_id] = true
		for bond_id: int in in_structure_context.nano_structure.atom_get_bonds(atom_id):
			var other_atom_id: int = in_structure_context.nano_structure.atom_get_bond_target(atom_id, bond_id)
			atoms_to_test[other_atom_id] = true
	# 2. Check of those atoms performs a bad tetrahedral configuration
	var has_bad_structure: bool = WorkspaceUtils.structure_context_has_drastically_invalid_tetrahedral_structure(
			in_structure_context, PackedInt32Array(atoms_to_test.keys()))
	# 2.1. Early return if there are no problems
	if not has_bad_structure:
		return
	# 3. Show warning to the user in message bar
	var validate_callback: Callable = func (in_self: Control) -> void:
		in_self.workspace_context.create_object_parameters.set_simulation_type(CreateObjectParameters.SimulationType.VALIDATION)
		MolecularEditorContext.request_workspace_docker_focus(SimulationsDocker.UNIQUE_DOCKER_NAME, &"Validate Model")
		# Describe selection or clear message bar if selection is empty when clicking "Validate"
		in_self._message_bar.show_message(in_self._create_selection_description_message())
	var meta_callbacks: Dictionary = {
		validate = validate_callback.bind(self)
	}
	_message_bar.show_warning("Operation produced an invalid tetrahedral structure distribution. " + \
			"Running a [url=validate]Validation[/url] is recommended", meta_callbacks)


func _describe_hydrogen_atoms_correction_action(in_added: int, in_removed: int) -> String:
	return "%d Hydrogen Atom%s created. %d Hydrogen Atom%s removed." % [
		in_added,
		"" if in_added == 1 else "s",
		in_removed,
		"" if in_removed == 1 else "s"
	]


func _on_visibility_changed() -> void:
	_canvas_layer.visible = is_visible_in_tree()


func _gui_input(event: InputEvent) -> void:
	if InitialInfoScreen.was_closed:
		editor_viewport.forward_viewport_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		# those events are handled by _gui_input
		# added in order to prevent bugs due to ocasional leakage of the event into viewport (eg when opening a file through FileDialog)
		return
	if !is_visible_in_tree():
		return
	if InitialInfoScreen.was_closed:
		editor_viewport.forward_viewport_input(event)


func _process(delta: float) -> void:
	if workspace_context == null or not is_visible_in_tree():
		if editor_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			editor_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if editor_viewport.render_target_update_mode != SubViewport.CLEAR_MODE_NEVER:
			editor_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		return
	
	if editor_viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		editor_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if editor_viewport.render_target_update_mode != SubViewport.CLEAR_MODE_ALWAYS:
		editor_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	
	editor_viewport.update(delta)
	_axes_widget.update(delta)
	_ring_menu.update(delta)


func _on_history_snapshot_created(in_snapshot_name: String) -> void:
	_message_bar.show_message(in_snapshot_name)


func _on_history_previous_snapshot_applied(in_snapshot_name: String) -> void:
	_message_bar.show_message("Undo: " + in_snapshot_name)


func _on_history_next_snapshot_applied(in_snapshot_name: String) -> void:
	_message_bar.show_message("Redo: " + in_snapshot_name)


func _on_history_changed() -> void:
	if is_instance_valid(_ring_menu) and _ring_menu.is_active():
		_ring_menu.refresh_button_availability()
