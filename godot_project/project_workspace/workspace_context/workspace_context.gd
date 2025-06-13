class_name WorkspaceContext extends Node

signal structure_added(struct: NanoStructure)
signal structure_about_to_remove(struct: NanoStructure)
signal structure_removed(struct: NanoStructure)
signal structure_renamed(struct: NanoStructure, new_name: String)
signal selection_in_structures_changed(structure_contexts: Array[StructureContext])
signal atoms_position_in_structure_changed(structure_context: StructureContext)
signal atoms_locking_in_structure_changed(structure_context: StructureContext, atoms_changed: PackedInt32Array)
signal structure_contents_changed(structure_context: StructureContext)
signal virtual_object_transform_changed(structure_context: StructureContext)
signal atoms_added_to_structure(structure_context: StructureContext, atom_ids: PackedInt32Array)
signal current_structure_context_changed(structure_context: StructureContext)
signal hovered_structure_context_changed(toplevel_hovered_structure_context: StructureContext,
		hovered_structure_context: StructureContext, atom_id: int, bond_id: int, spring_id: int)
signal editable_structure_context_list_changed(new_editable_structure_contexts: Array[StructureContext])
signal started_creating_object()
signal aborted_creating_object()
signal object_tree_visibility_changed()
signal atoms_relaxation_started()
signal atoms_relaxation_finished(error_description_or_empty: String)
signal simulation_started()
signal simulation_finished()

signal async_work_started()
signal async_work_finished()

signal hydrogen_atoms_count_corrected(added: int, removed: int)
signal bonds_auto_created(added: int)

signal object_visibility_changed()
signal alerts_panel_visibility_changed(is_visible: bool)

signal history_changed()
signal history_snapshot_created(snapshot_name: String)
signal history_snapshot_applied()
signal history_previous_snapshot_applied(undone_snapshot_name: String)
signal history_next_snapshot_applied(redone_snapshot_name: String)

const StructureContextScn = preload("res://project_workspace/workspace_context/structure_context/structure_context.tscn")
const WorkspaceMainViewScene = preload("res://editor/controls/workspace_view/WorkspaceMainView.tscn")
const NanostructureViewportScene = preload("res://editor/controls/editor_viewport_container/EditorViewportContainer.tscn")

const _META_CACHED_SELECTION_AABB = &"__CACHED_SELECTION_AABB__"


@export var dump_state_on_startup: bool = true

var _weak_workspace: WeakRef
var workspace: Workspace:
	get:
		return _weak_workspace.get_ref()
	set(_v):
		# Read Only
		pass

var ignored_warnings: Dictionary = {
	invalid_tetrahedral_structure = false,
	invalid_relaxed_tetrahedral_structure = false,
	abort_simulation = false,
	end_simulation = false,
	emitters_affected_by_motors = false,
}

var visible_object_tree: bool = false:
	set(v):
		if v == visible_object_tree:
			return
		visible_object_tree = v
		object_tree_visibility_changed.emit()
var workspace_main_view: WorkspaceMainView
var rendering_override: Rendering = null
var _last_saved_version: int = 0

var _structure_contexts: Dictionary #[id<int>, StructureContext]
var _current_structure_context_id: int

#TODO: this is redundant
var _modified_structure_contexts: Dictionary #[int, true]
var _selection_modified_structure_contexts: Dictionary #[int, true]
var _simulation: SimulationData = null
var _is_simulation_playback_running: bool = false
var _current_create_object_template: NanoStructure = null
var _current_create_object_structure_context: StructureContext = null
var _structure_contexts_holder: NodeHolder
var _editable_structure_contexts_ids: PackedInt32Array = PackedInt32Array()
var _history: History


# Editor Components
var create_object_parameters: CreateObjectParameters = load("res://project_workspace/workspace_context/create_object_parameters.tres").duplicate(true)

var action_delete: RingActionDelete = null
var action_undo: RingActionUndo = null
var action_redo: RingActionRedo = null
var action_copy: RingActionCopy = null
var action_cut: RingActionCut = null
var action_paste: RingActionPaste = null
var action_bonded_paste: RingActionBondedPaste = null
var action_import_file: RingActionImportFile = null
var action_import_from_library: RingActionImportFromLibrary = null
var action_load_fragment: RingActionLoadFragment = null
var action_auto_bonder: RingActionAutoBonder = null
var action_add_hydrogens: RingActionAddHydrogens = null
var action_invert_selection: RingActionInvertSelection = null
var action_select_all: RingActionSelectAll = null
var action_deselect_all: RingActionDeselectAll = null
var action_select_by_type: RingActionSelectByType = null
var action_select_connected: RingActionSelectConnected = null
var action_grow_selection: RingActionGrowSelection = null
var action_shrink_selection: RingActionShrinkSelection = null
var action_documentation: RingActionOpenDocumentation = null
var action_video_tutorials: RingActionVideoTutorials = null


var _hovered_structure_context: StructureContext
var _hovered_atom_id: int = AtomicStructure.INVALID_ATOM_ID
var _hovered_bond_id: int = AtomicStructure.INVALID_BOND_ID
var _hovered_spring_id: int = AtomicStructure.INVALID_SPRING_ID

var _preview_texture_viewport: SubViewport = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_structure_contexts_holder = get_node("StructureContextsHolder")
		create_object_parameters.set_create_mode_enabled(true)
		_preview_texture_viewport = %PreviewTextureSubViewport as SubViewport
		_history = $History
		_history.initialize(self)
		_history.register_snapshotable(self)
		_history.changed.connect(_on_history_changed)
		_history.snapshot_created.connect(_on_history_snapshot_created)
		_history.snapshot_applied.connect(_on_history_snapshot_applied)
		_history.previous_snapshot_applied.connect(_on_history_previous_snapshot_applied)
		_history.next_snapshot_applied.connect(_on_history_next_snapshot_applied)
	
	if what == NOTIFICATION_PREDELETE:
		create_object_parameters = null
	
		if is_instance_valid(workspace_main_view):
			if not workspace_main_view.is_inside_tree():
				workspace_main_view.free()


func initialize(in_workspace: Workspace) -> void:
	assert(is_instance_valid(in_workspace), "Invalid workspace")
	_weak_workspace = weakref(in_workspace)
	workspace.structure_reparented.connect(_on_workspace_structure_reparented)
	workspace_main_view = WorkspaceMainViewScene.instantiate()
	workspace_main_view.ready.connect(_on_workspace_main_view_ready)
	
	var nano_structures: Array = in_workspace.get_structures()
	for structure: NanoStructure in nano_structures:
		# ensure structure contexts are created
		get_nano_structure_context(structure)
	


func notify_activated() -> void:
	# Executed from MolecularEditorContext when the tab of this workspace becomes active
	PeriodicTable.load_schema(workspace.representation_settings.get_color_schema())
	var rendering: Rendering = get_rendering()
	if is_instance_valid(rendering):
		rendering.apply_theme(workspace.representation_settings.get_theme())


func _on_workspace_main_view_ready() -> void:
	var viewport_container: SubViewportContainer = get_editor_viewport_container()
	viewport_container.workspace_context = self
	get_rendering().initialize(self)
	_weak_workspace.get_ref().structure_added.connect(_on_weak_workspace_structure_added)
	_weak_workspace.get_ref().structure_about_to_remove.connect(_on_weak_workspace_structure_about_to_remove)
	_weak_workspace.get_ref().structure_removed.connect(_on_weak_workspace_structure_removed)
	_weak_workspace.get_ref().structure_renamed.connect(_on_weak_workspace_structure_renamed)
	var ring_menu: NanoRingMenu = viewport_container.get_ring_menu()
	action_delete = RingActionDelete.new(self, ring_menu)
	action_undo = RingActionUndo.new(self, ring_menu)
	action_redo = RingActionRedo.new(self, ring_menu)
	action_copy = RingActionCopy.new(self,ring_menu)
	action_cut = RingActionCut.new(self,ring_menu)
	action_paste = RingActionPaste.new(self,ring_menu)
	action_bonded_paste = RingActionBondedPaste.new(self,ring_menu)
	action_import_file = RingActionImportFile.new(self, ring_menu)
	action_import_from_library = RingActionImportFromLibrary.new(self, ring_menu)
	action_load_fragment = RingActionLoadFragment.new(self, ring_menu)
	action_auto_bonder = RingActionAutoBonder.new(self, ring_menu)
	action_add_hydrogens = RingActionAddHydrogens.new(self, ring_menu)
	action_add_hydrogens.hydrogen_atoms_count_changed.connect(_on_hydrogen_atom_count_change)
	action_invert_selection = RingActionInvertSelection.new(self, ring_menu)
	action_select_all = RingActionSelectAll.new(self, ring_menu)
	action_deselect_all = RingActionDeselectAll.new(self, ring_menu)
	action_select_by_type = RingActionSelectByType.new(self, ring_menu)
	action_select_connected = RingActionSelectConnected.new(self, ring_menu)
	action_grow_selection = RingActionGrowSelection.new(self, ring_menu)
	action_shrink_selection = RingActionShrinkSelection.new(self, ring_menu)
	action_documentation = RingActionOpenDocumentation.new(self, ring_menu)
	action_video_tutorials = RingActionVideoTutorials.new(self, ring_menu)
	
	var structures: Array = workspace.get_structures()
	for structure: NanoStructure in structures:
		add_nano_structure(structure)
	workspace.representation_settings_changed.connect(_on_workspace_representation_settings_changed)
	workspace.bond_settings_changed.connect(_on_workspace_bond_settings_changed)
	workspace.representation_settings.hydrogen_visibility_changed.connect(_on_hydrogen_visibility_changed)
	workspace_main_view.get_alerts_panel().visibility_changed.connect(_on_alerts_panel_visibility_changed)
	
	_initialize_history.call_deferred()


func _initialize_history() -> void:
	if dump_state_on_startup:
		_history.create_snapshot("")
	_last_saved_version = _history.get_version()


func _on_hydrogen_visibility_changed(_in_is_visible: bool = false) -> void:
	object_visibility_changed.emit()


func _on_alerts_panel_visibility_changed() -> void:
	alerts_panel_visibility_changed.emit(workspace_main_view.get_alerts_panel().is_visible_in_tree())


func notify_object_visibility_changed() -> void:
	object_visibility_changed.emit()


func notify_atoms_relaxation_started() -> void:
	atoms_relaxation_started.emit()


func notify_atoms_relaxation_finished(in_error_description_or_empty: String) -> void:
	atoms_relaxation_finished.emit(in_error_description_or_empty)


func notify_bonds_auto_created(in_count_added: int) -> void:
	bonds_auto_created.emit(in_count_added)


func _on_workspace_structure_reparented(_in_struct: NanoStructure, _in_new_parent: NanoStructure) -> void:
	_queue_emit_new_editable_structures()


func _on_weak_workspace_structure_added(in_structure: NanoStructure) -> void:
	add_nano_structure(in_structure)


func add_nano_structure(in_structure: NanoStructure) -> void:
	var rendering: Rendering = get_editor_viewport().get_rendering()
	assert(rendering, "Received structure_added signal before workspace " +
						"viewport UI was initialized")
	if in_structure is NanoVirtualAnchor:
		in_structure.initialize(self)
	var structure_context: StructureContext = get_nano_structure_context(in_structure)
	if in_structure is AtomicStructure and not get_editor_viewport().get_rendering().is_renderer_for_atomic_structure_built(in_structure):
		var current_representation: Rendering.Representation = workspace.representation_settings.get_rendering_representation()
		rendering.build_atomic_structure_rendering(structure_context, current_representation)
	
		if are_hydrogens_visualized():
			in_structure.enable_hydrogens_visibility()
		else:
			in_structure.disable_hydrogens_visibility()
	
	if in_structure is NanoShape:
		rendering.build_reference_shape_rendering(in_structure)
	if in_structure is NanoVirtualMotor:
		rendering.build_virtual_motor_rendering(in_structure)
	if in_structure is NanoParticleEmitter:
		rendering.build_particle_emitter_rendering(in_structure)
	if in_structure is NanoVirtualAnchor:
		rendering.build_virtual_anchor_rendering(in_structure)
	var _initialized_structure_context: StructureContext = get_nano_structure_context(in_structure)
	structure_added.emit(in_structure)
	
	if structure_context.is_editable():
		_queue_emit_new_editable_structures()


func _on_weak_workspace_structure_about_to_remove(in_structure: NanoStructure) -> void:
	var structure_context: StructureContext = _structure_contexts.get(in_structure.int_guid, null)
	assert(structure_context)
	structure_context.clear_selection()
	if _selection_modified_structure_contexts.has(in_structure.int_guid):
		_selection_modified_structure_contexts.erase(in_structure.int_guid)
	var rendering: Rendering = get_editor_viewport().get_rendering()
	assert(rendering, "Received structure_removed signal before workspace " +
						"viewport UI was initialized (or after destroyed?)")
	rendering.remove(in_structure)
	if in_structure is NanoVirtualAnchor:
		in_structure.deinitialize()
	structure_about_to_remove.emit(in_structure)
	_structure_contexts.erase(in_structure.int_guid)
	_emit_new_editable_structures()
	_check_for_empty_workspace()
	structure_context.queue_free()


func _on_weak_workspace_structure_removed(in_structure: NanoStructure) -> void:
	structure_removed.emit(in_structure)


func _on_weak_workspace_structure_renamed(in_structure: NanoStructure, in_new_name: String) -> void:
	structure_renamed.emit(in_structure, in_new_name)


func _on_workspace_representation_settings_changed() -> void:
	var rendering: Rendering = get_rendering()
	if rendering != null:
		if rendering.get_default_representation() != workspace.representation_settings.get_rendering_representation():
			rendering.change_default_representation(workspace.representation_settings.get_rendering_representation())
		else:
			rendering.refresh_atom_sizes()
			if are_hydrogens_visualized():
				rendering.enable_hydrogens()
			else:
				rendering.disable_hydrogens()


func _on_workspace_bond_settings_changed(in_representation_settings: RepresentationSettings) -> void:
	var rendering: Rendering = get_rendering()
	if rendering == null:
		return
	if in_representation_settings.get_display_bonds():
		rendering.ensure_bond_rendering_on()
	else:
		rendering.ensure_bond_rendering_off()


func _on_hydrogen_atom_count_change(in_added: int, in_removed: int) -> void:
	hydrogen_atoms_count_corrected.emit(in_added, in_removed)


func get_structure_context(in_id: int) -> StructureContext:
	return _structure_contexts[in_id]


func get_current_structure_context() -> StructureContext:
	if not _structure_contexts.has(_current_structure_context_id):
		return null
	return _structure_contexts[_current_structure_context_id]


func set_current_structure_context(in_structure_context: StructureContext) -> void:
	if in_structure_context.get_int_guid() == _current_structure_context_id:
		return
	# Activating an object cancels create mode
	abort_creating_object()
	workspace.active_structure_int_guid = in_structure_context.get_int_guid()
	_current_structure_context_id = in_structure_context.get_int_guid()
	current_structure_context_changed.emit(in_structure_context)
	_queue_emit_new_editable_structures()
	WorkspaceUtils.unselect_inactive_structure_contexts(self)


func pause_inputs(duration: float) -> void:
	get_editor_viewport().pause_inputs(duration)


## Returns true if there's at least 1 alert
func has_alerts() -> bool:
	return get_alerts_count() > 0


func is_alerts_panel_visible() -> bool:
	return workspace_main_view.get_alerts_panel().is_visible_in_tree()


## Returns the count of alerts listed in the Alerts panel
func get_alerts_count() -> int:
	return workspace_main_view.get_alerts_panel().get_alerts_count()


## Returns the selected TreeItem of the Alerts panel, if any
func get_alert_selected() -> int:
	return workspace_main_view.get_alerts_panel().get_alert_selected()


## Adds a Warning item to the Alerts panel, [code]in_selected_callback[/code] should
## take a [TreeItem] as  first argument
func push_warning_alert(
		in_message: String,
		in_selected_callback: Callable = Callable(),
		in_activated_callback: Callable = Callable()) -> int:
	return workspace_main_view.get_alerts_panel().add_warning(in_message, in_selected_callback, in_activated_callback)


## Adds an Error item to the Alerts panel, [code]in_selected_callback[/code] should
## take a [TreeItem] as  first argument
func push_error_alert(
		in_message: String,
		in_selected_callback: Callable = Callable(),
		in_activated_callback: Callable = Callable()) -> int:
	return workspace_main_view.get_alerts_panel().add_error(in_message, in_selected_callback, in_activated_callback)


## Makes the alerts panel visible (if there's at least one alert to show)
func show_alerts_panel() -> void:
	if has_alerts():
		workspace_main_view.get_alerts_panel().show()


## Clears the list of problems from the Alerts panel and hides the window if visible
func clear_alerts() -> void:
	workspace_main_view.get_alerts_panel().clear_and_close()


func mark_alert_as_fixed(in_alert_id: int) -> void:
	workspace_main_view.get_alerts_panel().mark_as_fixed(in_alert_id)


func mark_alert_as_invalid(in_alert_id: int) -> void:
	workspace_main_view.get_alerts_panel().mark_as_invalid(in_alert_id)


func start_async_work(
			in_with_message: String = "",
			in_cancel_callback: Callable = Callable(),
			in_stop_callback: Callable = Callable(),
			in_with_run_in_background: bool = false,
			in_progress_handler: Object = null) -> void:
	var center_gears_in_control: Control = null
	var workspace_viewport: WorkspaceEditorViewport = get_editor_viewport()
	if workspace_viewport:
		center_gears_in_control = workspace_viewport.workspace_tools_container
	BusyIndicator.activate(
		in_with_message, in_cancel_callback,
		in_stop_callback, in_with_run_in_background, center_gears_in_control, in_progress_handler)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_BUSY)
	async_work_started.emit()


func end_async_work() -> void:
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	BusyIndicator.deactivate()
	async_work_finished.emit()


func has_unsaved_changes() -> bool:
	return _last_saved_version != _history.get_version()


func mark_saved() -> void:
	_last_saved_version = _history.get_version()


func start_creating_object(in_template_structure: NanoStructure) -> void:
	assert(in_template_structure, "Invalid template to create")
	_current_create_object_template = in_template_structure
	_current_create_object_template.set_representation_settings(workspace.representation_settings)
	_current_create_object_structure_context = StructureContextScn.instantiate()
	_current_create_object_structure_context.initialize_as_template(self, in_template_structure)
	_structure_contexts_holder.add_child(_current_create_object_structure_context)
	started_creating_object.emit()


func finish_creating_object() -> StructureContext:
	if _current_create_object_template == null:
		return
	var structure: NanoStructure = _current_create_object_template
	_current_create_object_template = null
	_current_create_object_structure_context = null
	workspace.add_structure(structure, get_current_structure_context().nano_structure)
	get_current_structure_context().finalize_template()
	return get_nano_structure_context(structure)


func abort_creating_object() -> void:
	if _current_create_object_template != null:
		_current_create_object_template = null
		if is_instance_valid(_current_create_object_structure_context):
			_current_create_object_structure_context.queue_free()
		aborted_creating_object.emit()


func is_creating_object() -> bool:
	return is_instance_valid(_current_create_object_template)


func peek_object_being_created(in_callback: Callable) -> bool:
	if !is_creating_object():
		return false
	if !in_callback.is_valid():
		return false
	return in_callback.call(_current_create_object_template)


func peek_context_of_object_being_created(in_callback: Callable) -> bool:
	if !is_creating_object():
		return false
	if !in_callback.is_valid():
		return false
	return in_callback.call(_current_create_object_structure_context)


# # Simulation
# # # # # #

func start_simulating(in_simulation_data: SimulationData) -> void:
	assert(not is_simulating(), "I'm already being simulated, make sure to call " +
			"abort_simulation_if_running() when you are done with it")
	_simulation = in_simulation_data
	simulation_started.emit()


func get_simulation_boundaries() -> AABB:
	assert(is_simulating(), "There's not an active simulation")
	var aabb: AABB = _simulation.original_payload.calculated_aabb
	if workspace != null:
		var grow_factor: float = \
			workspace.simulation_settings_advanced_constrained_simulation_box_size_percentage / 100.0
		var grown_aabb := AABB()
		grown_aabb.size = aabb.size * grow_factor
		grown_aabb.position = aabb.get_center() - (grown_aabb.size * 0.5)
		aabb = grown_aabb
	return aabb


# Plaback means the simulation is currently advancing every frame, this operation is very intensive
# so some of the functionality is disabled during the playback and only refreshed after playback ends
func set_simulation_playback_running(in_is_playback_running: bool) -> void:
	assert((not in_is_playback_running) or is_simulating(), "Cannot set simulation playback state when there's not an active simulation")
	if _is_simulation_playback_running == in_is_playback_running:
		return
	_is_simulation_playback_running = in_is_playback_running
	if not _is_simulation_playback_running:
		# playback just paused, update internal state of the Octree
		update(Engine.get_main_loop().root.get_process_delta_time())


func is_simulating() -> bool:
	return _simulation != null


func seek_simulation(in_frame: float) -> void:
	assert(is_simulating(), "There's not an active simulation")
	var state: PackedVector3Array = _simulation.find_state(in_frame)
	var payload: OpenMMPayload = _simulation.original_payload
	for emitter: NanoParticleEmitter in get_particle_emitters():
		emitter.seek_simulation(in_frame)
	WorkspaceUtils.apply_simulation_state(self, payload, state)


func abort_simulation_if_running() -> void:
	if !is_simulating():
		return
	# Revert to original state and dispose
	OpenMM.request_abort_simulation(_simulation)
	seek_simulation(0.0)
	for emitter: NanoParticleEmitter in get_particle_emitters():
		emitter.destroy_instances()
	_simulation = null
	_is_simulation_playback_running = false
	simulation_finished.emit()


## Stops and discard the simulation on OpenMM's side, but keep the existing
## frames in memory on MSEP so they can be displayed and manipulated.
func end_simulation_if_running() -> void:
	if !is_simulating():
		return
	OpenMM.request_abort_simulation(_simulation)


## This method is automatically called when any code attempts
## to create a new action with `snapshot_moment()`
func apply_simulation_if_running() -> void:
	if !is_simulating():
		return
	for emitter: NanoParticleEmitter in get_particle_emitters():
		emitter.notify_apply_simulation()
	_history.create_snapshot(tr("Apply Simulation State"))
	_simulation = null
	simulation_finished.emit()

# # /Simulation
# # # # # #


func show_warning_dialog(in_message: String, in_accept_label: String, in_cancel_label := String(),
		in_warning_code := StringName(), in_accepted_when_ignored: bool = false) -> Promise:
	assert(in_warning_code == StringName() or in_warning_code in ignored_warnings.keys(), "Unexpected warning code '%s'" % in_warning_code)
	var warning_promise := Promise.new()
	var dialog := NanoAcceptDialog.new()
	dialog.dialog_text = in_message
	dialog.ok_button_text = in_accept_label
	if in_accept_label.is_empty():
		dialog.get_ok_button().hide()
	var right: bool = not OS.get_name().to_lower() == "macos"
	if not in_cancel_label.is_empty():
		dialog.add_cancel_button(in_cancel_label)
	if in_warning_code != StringName():
		dialog.add_button(tr("Don't Remind Me Again"), right, in_warning_code)
	dialog.closed.connect(_on_warning_dialog_closed.bind(warning_promise, dialog))
	dialog.custom_action.connect(_on_warning_dialog_custom_action.bind(dialog, in_accepted_when_ignored))
	add_child(dialog)
	dialog.popup_centered()
	return warning_promise


func _on_warning_dialog_closed(in_accepted: bool, out_warning_promise: Promise, out_warning_dialog: NanoAcceptDialog) -> void:
	out_warning_promise.fulfill(in_accepted)
	out_warning_dialog.queue_free()


func _on_warning_dialog_custom_action(in_warning_code: StringName, out_warning_dialog: NanoAcceptDialog, in_result_when_ignored: bool) -> void:
	# Custom Action is only used to don't remind again this warning
	ignored_warnings[in_warning_code] = true
	out_warning_dialog.closed.emit(in_result_when_ignored)


func activate_nano_structure(in_nano_structure: NanoStructure) -> void:
	var context: StructureContext = get_nano_structure_context(in_nano_structure)
	set_current_structure_context(context)


func get_nano_structure_context(in_nano_structure: NanoStructure) -> StructureContext:
	var guid: int = in_nano_structure.int_guid
	assert(workspace.has_structure(in_nano_structure))
	if !_structure_contexts.has(guid):
		var structure_context: StructureContext = StructureContextScn.instantiate() as StructureContext
		structure_context.initialize(self, guid, in_nano_structure)
		_structure_contexts_holder.add_child_with_name(structure_context, in_nano_structure.get_structure_name().to_snake_case())
		structure_context.selection_changed.connect(_on_structure_context_selection_changed.bind(structure_context.get_int_guid()))
		structure_context.virtual_object_selection_changed.connect(_on_structure_context_virtual_object_selection_changed.bind(structure_context.get_int_guid()))
		if structure_context.nano_structure is AtomicStructure \
				and not structure_context.nano_structure.atoms_moved.is_connected(_on_structure_context_atoms_moved):
			structure_context.nano_structure.atoms_moved.connect(_on_structure_context_atoms_moved.bind(structure_context.get_int_guid()))
			structure_context.nano_structure.atoms_added.connect(_on_structure_contents_modified_arg1.bind(structure_context.get_int_guid()))
			structure_context.nano_structure.atoms_added.connect(_on_structure_context_atoms_added.bind(structure_context.get_int_guid()))
			structure_context.nano_structure.atoms_removed.connect(_on_structure_contents_modified_arg1.bind(structure_context.get_int_guid()))
			structure_context.nano_structure.atoms_moved.connect(_on_structure_contents_modified_arg1.bind(structure_context.get_int_guid()))
			structure_context.nano_structure.atoms_atomic_number_changed.connect(_on_structure_contents_modified_arg1.bind(structure_context.get_int_guid()))
			structure_context.nano_structure.atoms_cleared.connect(_on_structure_contents_modified_arg0.bind(structure_context.get_int_guid()))
			structure_context.nano_structure.bonds_created.connect(_on_structure_contents_modified_arg1.bind(structure_context.get_int_guid()))
			structure_context.nano_structure.bonds_changed.connect(_on_structure_contents_modified_arg1.bind(structure_context.get_int_guid()))
			structure_context.nano_structure.atoms_locking_changed.connect(_on_nano_structure_atoms_locking_changed.bind(structure_context.get_int_guid()))
		if not structure_context.nano_structure.visibility_changed.is_connected(_on_nano_structure_visibility_changed):
			structure_context.nano_structure.visibility_changed.connect(_on_nano_structure_visibility_changed.bind(structure_context.get_int_guid()))
		if structure_context.nano_structure is NanoShape:
			structure_context.nano_structure.shape_properties_changed.connect(_on_structure_contents_modified_arg0.bind(structure_context.get_int_guid()))
		if structure_context.nano_structure.is_virtual_object():
			if structure_context.nano_structure is NanoVirtualAnchor:
				# Anchors only have position
				structure_context.nano_structure.position_changed.connect(_on_virtual_object_transform_changed.bind(structure_context.get_int_guid()))
			else:
				# Shapes, Motors, and Particle Emitters have transforms
				structure_context.nano_structure.transform_changed.connect(_on_virtual_object_transform_changed.bind(structure_context.get_int_guid()))
		_structure_contexts[guid] = structure_context
		if structure_context.has_selection():
			set_meta(_META_CACHED_SELECTION_AABB, null)
			_selection_modified_structure_contexts[structure_context.get_int_guid()] = true
	return _structure_contexts[guid]


func _on_structure_context_selection_changed(in_structure_context_id: int) -> void:
	if not workspace.has_structure_with_int_guid(in_structure_context_id):
		return
	var structure_context: StructureContext = get_structure_context(in_structure_context_id)
	if is_structure_context_valid(structure_context):
		set_meta(_META_CACHED_SELECTION_AABB, null)
		_selection_modified_structure_contexts[in_structure_context_id] = true


func _on_structure_context_atoms_moved(in_atoms: PackedInt32Array, in_structure_context_id: int) -> void:
	if not workspace.has_structure_with_int_guid(in_structure_context_id):
		return
	var structure_context: StructureContext = get_structure_context(in_structure_context_id)
	if is_structure_context_valid(structure_context):
		atoms_position_in_structure_changed.emit(structure_context, in_atoms)
		set_meta(_META_CACHED_SELECTION_AABB, null)


func _on_structure_context_atoms_added(in_atoms: PackedInt32Array, in_structure_context_id: int) -> void:
	if not workspace.has_structure_with_int_guid(in_structure_context_id):
		return
	var structure_context: StructureContext = get_structure_context(in_structure_context_id)
	if is_structure_context_valid(structure_context):
		atoms_added_to_structure.emit(structure_context, in_atoms)


func _on_structure_contents_modified_arg0(in_structure_context_id: int) -> void:
	if not workspace.has_structure_with_int_guid(in_structure_context_id):
		return
	var structure_context: StructureContext = get_structure_context(in_structure_context_id)
	if structure_context != null:
		_modified_structure_contexts[in_structure_context_id] = true
	_check_for_empty_workspace()


func _on_structure_contents_modified_arg1(_ignore_arg1: Variant, in_structure_context_id: int) -> void:
	if not workspace.has_structure_with_int_guid(in_structure_context_id):
		return
	var structure_context: StructureContext = get_structure_context(in_structure_context_id)
	if structure_context != null:
		_modified_structure_contexts[in_structure_context_id] = true
	_check_for_empty_workspace()


func _on_virtual_object_transform_changed(_ignore_arg1: Variant, in_structure_context_id: int) -> void:
	if not workspace.has_structure_with_int_guid(in_structure_context_id):
		return
	set_meta(_META_CACHED_SELECTION_AABB, null)
	var structure_context: StructureContext = get_structure_context(in_structure_context_id)
	if structure_context != null:
		virtual_object_transform_changed.emit(structure_context)


func _on_nano_structure_visibility_changed(_in_visible: bool, in_structure_context_id: int) -> void:
	if not workspace.has_structure_with_int_guid(in_structure_context_id):
		return
	var structure_context: StructureContext = get_structure_context(in_structure_context_id)
	structure_context.mark_is_editable_dirty()
	if structure_context.is_editable() and not _editable_structure_contexts_ids.has(in_structure_context_id):
		_queue_emit_new_editable_structures()
	elif not structure_context.is_editable() and _editable_structure_contexts_ids.has(in_structure_context_id):
		_queue_emit_new_editable_structures()


func _on_nano_structure_atoms_locking_changed(in_atoms_changed: PackedInt32Array, in_structure_context_id: int) -> void:
	if not workspace.has_structure_with_int_guid(in_structure_context_id):
		return
	var structure_context: StructureContext = get_structure_context(in_structure_context_id)
	if structure_context != null:
		atoms_locking_in_structure_changed.emit(structure_context, in_atoms_changed)


func _on_structure_context_virtual_object_selection_changed(_in_selected: bool, in_structure_context_id: int) -> void:
	if not workspace.has_structure_with_int_guid(in_structure_context_id):
		return
	var structure_context: StructureContext = get_structure_context(in_structure_context_id)
	if is_structure_context_valid(structure_context):
		set_meta(_META_CACHED_SELECTION_AABB, null)
		_selection_modified_structure_contexts[in_structure_context_id] = true


func _check_for_empty_workspace() -> void:
	if create_object_parameters.get_create_mode_enabled() == false and get_visible_structure_contexts().size() == 0:
		create_object_parameters.set_create_mode_enabled(true)


func _emit_selection_in_structures_changed() -> void:
	if _selection_modified_structure_contexts.is_empty():
		return
	for context_id: int in _selection_modified_structure_contexts.keys():
		if not _structure_contexts.has(context_id):
			continue
		var context: StructureContext = _structure_contexts[context_id]
		var parent_structure: NanoStructure = workspace.get_parent_structure(context.nano_structure)
		while parent_structure != null and (
				parent_structure == get_current_structure_context().nano_structure \
				or workspace.is_a_ancestor_of_b(get_current_structure_context().nano_structure, parent_structure)):
			_selection_modified_structure_contexts[get_nano_structure_context(parent_structure).get_int_guid()] = true
			parent_structure = workspace.get_parent_structure(parent_structure)
	
	var out_contextes: Array[StructureContext] = []
	for context_id: int in _selection_modified_structure_contexts:
		var structure_context: StructureContext = _structure_contexts[context_id]
		out_contextes.append(structure_context)
	_selection_modified_structure_contexts = {}
	selection_in_structures_changed.emit(out_contextes)


func has_nano_structure_context(in_nano_structure: NanoStructure) -> bool:
	var guid: int = in_nano_structure.int_guid
	return _structure_contexts.has(guid)


func has_nano_structure_context_id(in_nano_structure_id: int) -> bool:
	return _structure_contexts.has(in_nano_structure_id)


func get_nano_structure_context_from_id(in_nano_structure_id: int) -> StructureContext:
	return _structure_contexts[in_nano_structure_id]


func get_all_structure_contexts(in_include_empty_structures: bool = false) -> Array[StructureContext]:
	var result: Array[StructureContext] = []
	for context: StructureContext in _structure_contexts.values():
		var structure_has_data: bool = context.nano_structure.is_virtual_object() \
				or context.nano_structure.get_valid_atoms_count() > 0
		if structure_has_data or in_include_empty_structures:
			result.push_back(context)
	return result


func get_visible_structure_contexts(in_include_empty_structures: bool = false) -> Array[StructureContext]:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	var result: Array[StructureContext] = []
	for context: StructureContext in _structure_contexts.values():
		if context.nano_structure.get_visible():
			var structure_has_data: bool = context.nano_structure.is_virtual_object() \
					or context.nano_structure.get_valid_atoms_count() > 0
			if structure_has_data or in_include_empty_structures:
				result.push_back(context)
	return result


func get_editable_structure_contexts() -> Array[StructureContext]:
	if ScriptUtils.is_callable_queued(_emit_new_editable_structures):
		ScriptUtils.flush_now(_emit_new_editable_structures)
	var editable_structure_contexts: Array[StructureContext] = []
	for editable_id: int in _editable_structure_contexts_ids:
		editable_structure_contexts.append(_structure_contexts[editable_id])
	return editable_structure_contexts


func get_toplevel_editable_context(in_child_structure_context: StructureContext) -> StructureContext:
	assert(workspace.is_a_ancestor_of_b(
			get_current_structure_context().nano_structure, in_child_structure_context.nano_structure),
			"The requested structure context is not a child of active structure context")
	var top_level_context: StructureContext = in_child_structure_context
	while workspace.get_parent_structure(top_level_context.nano_structure) != get_current_structure_context().nano_structure:
		top_level_context = get_nano_structure_context(workspace.get_parent_structure(top_level_context.nano_structure))
	return top_level_context


func are_bonds_visualised() -> bool:
	return workspace.representation_settings.get_display_bonds()


func change_bond_visibility(in_is_bond_visible: bool) -> void:
	if in_is_bond_visible == are_bonds_visualised():
		return
	workspace.change_bond_visibility(in_is_bond_visible)
	var snapshot_name: String = "Show Bonds" if in_is_bond_visible else "Hide Bonds"
	snapshot_moment(snapshot_name)


func are_atom_labels_visualised() -> bool:
	var rendering: Rendering = get_editor_viewport().get_rendering()
	return rendering.are_labels_enabled()


func enable_atom_labels() -> void:
	if are_atom_labels_visualised():
		return
	var rendering: Rendering = get_editor_viewport().get_rendering()
	workspace.representation_settings.set_atom_labels_visibility_and_notify(true)
	rendering.enable_labels()
	snapshot_moment("Show Atom Labels")


func disable_atom_labels() -> void:
	var rendering: Rendering = get_editor_viewport().get_rendering()
	workspace.representation_settings.set_atom_labels_visibility_and_notify(false)
	rendering.disable_labels()
	snapshot_moment("Hide Atom Labels")


func are_hydrogens_visualized() -> bool:
	var structures: Array = workspace.get_structures()
	if structures.is_empty():
		return true
	
	for structure: NanoStructure in structures:
		if not structure is AtomicStructure:
			# Ignore virtual objects
			continue
		if structure.are_hydrogens_visible():
			return true
	return false


func enable_hydrogens_visualization(clear_selection: bool = true) -> void:
	if are_hydrogens_visualized():
		return
	
	var rendering: Rendering = get_editor_viewport().get_rendering()
	for context: StructureContext in _structure_contexts.values():
		if not context.nano_structure is AtomicStructure:
			# Ignore virtual objects
			continue
		context.nano_structure.enable_hydrogens_visibility()
		if clear_selection:
			context.clear_selection()
	
	rendering.enable_hydrogens()
	workspace.representation_settings.set_hydrogen_visibility_and_notify(true)


func disable_hydrogens_visualization(in_clear_hydrogen_selection: bool = false) -> void:
	if not are_hydrogens_visualized():
		return
	
	if create_object_parameters.get_new_atom_element() == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
		create_object_parameters.set_new_atom_element(PeriodicTable.ATOMIC_NUMBER_CARBON)
	
	var rendering: Rendering = get_editor_viewport().get_rendering()
	for context: StructureContext in _structure_contexts.values():
		if not context.nano_structure is AtomicStructure:
			# Ignore virtual objects
			continue
		context.nano_structure.disable_hydrogens_visibility()
		if in_clear_hydrogen_selection:
			_deselect_hydrogens(context)
		
	rendering.disable_hydrogens()
	workspace.representation_settings.set_hydrogen_visibility_and_notify(false)


func _deselect_hydrogens(out_structure_context: StructureContext) -> void:
	var atoms_to_deselect: PackedInt32Array = PackedInt32Array()
	var bonds_to_deselect: Dictionary = {
		#bond_id<int> : true <bool>
	}
	var selected_atoms: PackedInt32Array = out_structure_context.get_selected_atoms()
	var selected_bonds: PackedInt32Array = out_structure_context.get_selected_bonds()
	for atom_id: int in selected_atoms:
		var is_atom_hydrogen: bool = out_structure_context.nano_structure.atom_is_hydrogen(atom_id)
		if is_atom_hydrogen:
			atoms_to_deselect.append(atom_id)
			var related_h_bonds: PackedInt32Array = out_structure_context.nano_structure.atom_get_bonds(atom_id)
			for bond_id: int in related_h_bonds:
				bonds_to_deselect[bond_id] = true
	for bond_id: int in selected_bonds:
		var is_bond_related_to_hydrogen: bool = out_structure_context.nano_structure.bond_is_hydrogen_involved(bond_id)
		if is_bond_related_to_hydrogen:
			bonds_to_deselect[bond_id] = true
	out_structure_context.deselect_atoms(atoms_to_deselect)
	out_structure_context.deselect_bonds(bonds_to_deselect.keys())


func refresh_group_saturation() -> void:
	var all_structure_contexts: Array[StructureContext] = get_all_structure_contexts()
	var renderer: Rendering = get_rendering()
	for structure: StructureContext in all_structure_contexts:
		if not structure.nano_structure is AtomicStructure:
			continue
			
		if structure.is_editable():
			renderer.saturate_structure(structure.nano_structure)
		else:
			renderer.desaturate_structure(structure.nano_structure)


# # Selection
# # # # # #
func has_selection() -> bool:
	for context: StructureContext in _structure_contexts.values():
		if context.nano_structure.get_visible() and context.has_selection():
			return true
	return false


func has_transformable_selection() -> bool:
	for context: StructureContext in _structure_contexts.values():
		if context.has_transformable_selection():
			return true
	return false


func has_cached_selection_set() -> bool:
	var selected_structures: Array[StructureContext] = get_structure_contexts_with_selection()
	for structure in selected_structures:
		if structure.has_cached_selection_set():
			return true
	return false


func is_any_atom_selected() -> bool:
	for context: StructureContext in _structure_contexts.values():
		if context.is_any_atom_selected():
			return true
	return false


func get_selected_anchors_contexts() -> Array[StructureContext]:
	var selected_anchors: Array[StructureContext] = []
	var structure_contexts_with_selection: Array[StructureContext] = get_structure_contexts_with_selection()
	for structure_context: StructureContext in structure_contexts_with_selection:
		if structure_context.is_anchor_selected():
			selected_anchors.append(structure_context)
	return selected_anchors


func get_structure_contexts_with_selection(in_include_empty_groups_with_selected_subgroups: bool = false) -> Array[StructureContext]:
	var result: Array[StructureContext] = []
	var editable := get_editable_structure_contexts()
	for structure_context: StructureContext in editable:
		if structure_context.nano_structure.get_visible() and structure_context.has_selection(in_include_empty_groups_with_selected_subgroups):
			result.push_back(structure_context)
	return result


func get_atomic_structure_contexts_with_selection(in_include_empty_groups_with_selected_subgroups: bool = false) -> Array[StructureContext]:
	var result: Array[StructureContext] = []
	var editable := get_editable_structure_contexts()
	for structure_context: StructureContext in editable:
		if structure_context.nano_structure.is_virtual_object():
			continue
		if structure_context.nano_structure.get_visible() and structure_context.has_selection(in_include_empty_groups_with_selected_subgroups):
			result.push_back(structure_context)
	return result


func get_structure_contexts_with_transformable_selection() -> Array[StructureContext]:
	var result: Array[StructureContext] = []
	for context: StructureContext in _structure_contexts.values():
		if context.nano_structure.get_visible() and context.has_transformable_selection():
			result.push_back(context)
	return result


func get_selected_structure_contexts_child_of_current_structure() -> Array[StructureContext]:
	var result: Array[StructureContext] = []
	var current_id: int = 0 if not _structure_contexts.has(_current_structure_context_id) else _current_structure_context_id
	for context: StructureContext in _structure_contexts.values():
		if context.nano_structure.get_visible() and context.has_selection(true) and context.nano_structure.int_parent_guid == current_id:
			result.push_back(context)
	return result


func get_structure_contexts_with_hidden_objects() -> Array[StructureContext]:
	var result: Array[StructureContext] = []
	for context: StructureContext in _structure_contexts.values():
		if not context.nano_structure.get_visible() or context.has_hidden_atoms_bonds_springs_or_motor_links():
			result.push_back(context)
	return result


func clear_all_selection() -> void:
	for context: StructureContext in _structure_contexts.values():
		context.clear_selection()


func get_selection_aabb() -> AABB:
	assert(has_selection(), "Ensure there's a valid selection before calling this method")
	var aabb: AABB
	if has_meta(_META_CACHED_SELECTION_AABB):
		aabb = get_meta(_META_CACHED_SELECTION_AABB, null)
	else:
		aabb = WorkspaceUtils.get_selected_objects_aabb(self)
		set_meta(_META_CACHED_SELECTION_AABB, aabb)
	return aabb


# # Viewport and Input
# # # # # #
func get_editor_viewport_container() -> SubViewportContainer:
	if is_instance_valid(workspace_main_view):
		return workspace_main_view.editor_viewport_container
	return null


func get_editor_viewport() -> WorkspaceEditorViewport:
	if is_instance_valid(workspace_main_view) and is_instance_valid(workspace_main_view.editor_viewport_container):
		return workspace_main_view.editor_viewport_container.get_child(0)
	return null


func get_box_selection() -> BoxSelection:
	return workspace_main_view.get_box_selection()


func get_camera() -> Camera3D:
	return workspace_main_view.get_camera()


func set_camera_global_transform(in_transform: Transform3D) -> void:
	workspace_main_view.set_camera_global_transform(in_transform)


func get_camera_global_transform() -> Transform3D:
	return workspace_main_view.get_camera_global_transform()


func set_camera_orthogonal_size(in_orthogonal_size: float) -> void:
	workspace_main_view.set_camera_orthogonal_size(in_orthogonal_size)


func get_camera_orthogonal_size() -> float:
	return workspace_main_view.get_camera_orthogonal_size()


func get_rendering() -> Rendering:
	return rendering_override if rendering_override != null else get_editor_viewport().get_rendering()


func set_hovered_structure_context(in_structure_context: StructureContext, in_atom_id: int,
			in_bond_id: int, in_spring_id: int) -> void:
	if in_structure_context == _hovered_structure_context and _hovered_atom_id == in_atom_id and \
			_hovered_bond_id == in_bond_id and _hovered_spring_id == in_spring_id:
		return
	_hovered_structure_context = in_structure_context
	_hovered_atom_id = in_atom_id
	_hovered_bond_id = in_bond_id
	_hovered_spring_id = in_spring_id
	var informed_toplevel_structure_context: StructureContext = null
	if not in_structure_context in [null, get_current_structure_context()]:
		informed_toplevel_structure_context = get_toplevel_editable_context(in_structure_context)
	hovered_structure_context_changed.emit(informed_toplevel_structure_context, in_structure_context,
			_hovered_atom_id, _hovered_bond_id, _hovered_spring_id)


func change_current_structure_context(out_new_current_structure_context: StructureContext) -> void:
	var nano_structure: NanoStructure = out_new_current_structure_context.nano_structure
	if not nano_structure.get_visible():
		# Make the structure visible.
		# Why not assert when not visible? Assumption is this command could come from the
		# Groups Docker or the Group Selection Topbar
		nano_structure.set_visible(true)
	set_current_structure_context(out_new_current_structure_context)


func _queue_emit_new_editable_structures() -> void:
	ScriptUtils.call_deferred_once(_emit_new_editable_structures)


func _emit_new_editable_structures() -> void:
	_editable_structure_contexts_ids.clear()
	for context: StructureContext in _structure_contexts.values():
		context.mark_is_editable_dirty()
		if context.is_editable():
			_editable_structure_contexts_ids.push_back(context.get_int_guid())
	editable_structure_context_list_changed.emit(get_editable_structure_contexts())
	refresh_group_saturation()


func update(_delta: float) -> void:
	_emit_selection_in_structures_changed()
	_emit_structure_content_changed()


func _emit_structure_content_changed() -> void:
	if _is_simulation_playback_running:
		# Skip internal update of structures during simulation playback
		return
	for context_id: int in _modified_structure_contexts:
		assert(_structure_contexts.has(context_id))
		structure_contents_changed.emit(_structure_contexts[context_id])
	_modified_structure_contexts.clear()


func invert_selection() -> void:
	WorkspaceUtils.invert_selection(self)


func select_all() -> void:
	WorkspaceUtils.select_all(self)


func deselect_all() -> void:
	WorkspaceUtils.deselect_all(self)


func select_by_type(types: PackedInt32Array) -> void:
	WorkspaceUtils.select_by_type(self, types)


func select_connected(in_show_hidden_objects: bool = false) -> void:
	WorkspaceUtils.select_connected(self, in_show_hidden_objects)


func can_grow_selection() -> bool:
	for context: StructureContext in _structure_contexts.values():
		if context.can_grow_selection():
			return true
	return false

func grow_selection() -> void:
	WorkspaceUtils.grow_selection(self)


func shrink_selection() -> void:
	WorkspaceUtils.shrink_selection(self)


func has_visible_objects() -> bool:
	var visible_structure_contexts: Array[StructureContext] = get_visible_structure_contexts(false)
	return visible_structure_contexts.size() > 0


func has_hidden_objects() -> bool:
	for context: StructureContext in _structure_contexts.values():
		if not context.nano_structure.get_visible() or context.has_hidden_atoms_bonds_springs_or_motor_links():
			return true
	return false


func has_valid_atoms() -> bool:
	for context: StructureContext in get_visible_structure_contexts():
		if not context.nano_structure is AtomicStructure:
			continue
		var nano_structure: AtomicStructure = context.nano_structure
		if not nano_structure.get_valid_atoms().is_empty():
			return true
	return false


func has_motors() -> bool:
	for context: StructureContext in _structure_contexts.values():
		if context.nano_structure is NanoVirtualMotor:
			return true
	return false


func has_valid_particle_emitters() -> bool:
	for context: StructureContext in _structure_contexts.values():
		if context.nano_structure is NanoParticleEmitter:
			var emitter := context.nano_structure as NanoParticleEmitter
			var parameters: NanoParticleEmitterParameters = emitter.get_parameters()
			var template: AtomicStructure = null if parameters == null else parameters.get_molecule_template()
			var atoms_count: int = 0 if template == null else template.get_valid_atoms_count()
			if atoms_count > 0:
				return true
	return false


func get_motors() -> Array[NanoVirtualMotor]:
	var motors: Array[NanoVirtualMotor] = []
	for context: StructureContext in _structure_contexts.values():
		if context.nano_structure is NanoVirtualMotor:
			motors.push_back(context.nano_structure)
	return motors


func get_particle_emitters() -> Array[NanoParticleEmitter]:
	var emitters: Array[NanoParticleEmitter] = []
	for context: StructureContext in _structure_contexts.values():
		if context.nano_structure is NanoParticleEmitter:
			emitters.push_back(context.nano_structure)
	return emitters


## Returns false if the structure context is not part of the workspace.
func is_structure_context_valid(structure_context: StructureContext) -> bool:
	if is_instance_valid(structure_context):
		return workspace.has_structure(structure_context.nano_structure)
	return false


## Usage:
##  var promise: Promise = _workspace_context.request_generate_preview_picture(Vector2(4096, 4096), true)
##  await promise.wait_for_fulfill()
##  assert(promise.is_correct(), promise.get_error())
##  texture = promise.get_result() as Texture2D
func request_generate_preview_picture(in_texture_size: Vector2 = Vector2(1024, 1024), \
		in_is_transparent_background: bool = false) -> Promise:
	var promise := Promise.new()
	_generate_picture(promise, in_texture_size, in_is_transparent_background)
	return promise


func _generate_picture(out_promise: Promise, in_texture_size: Vector2, \
		in_is_transparent_background: bool) -> void:
	var active_viewport: WorkspaceEditorViewport = get_editor_viewport()
	assert(active_viewport, "Couldn't generate preview picture, active_viewport was not found.")
	assert(_preview_texture_viewport, "Couldn't generate preview picture, _preview_texture_viewport was not found.")
	
	_preview_texture_viewport.world_3d = active_viewport.find_world_3d()
	_preview_texture_viewport.size = in_texture_size
	_preview_texture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_preview_background(in_is_transparent_background)
	_set_remote_camera(active_viewport.get_camera_3d())
	
	await RenderingServer.frame_post_draw
	var frame_texture: Texture2D = _preview_texture_viewport.get_texture() as Texture2D
	out_promise.fulfill(frame_texture)


func _update_preview_background(in_is_transparent_background: bool) -> void:
	const _DEFAULT_ENVIRONMENT: Environment = preload("res://editor/rendering/resources/world_environment.tres")
	if !in_is_transparent_background:
		_preview_texture_viewport.transparent_bg = false
		_preview_texture_viewport.get_camera_3d().environment = _DEFAULT_ENVIRONMENT
	else:
		_preview_texture_viewport.transparent_bg = true
		_preview_texture_viewport.get_camera_3d().environment = null


func _set_remote_camera(in_camera_3d: Camera3D) -> void:
	assert(in_camera_3d)
	var camera_properties: Array[Dictionary] = in_camera_3d.get_property_list()
	var camera: Camera3D = _preview_texture_viewport.get_camera_3d()
	for property in camera_properties:
		if property.name in [&"script", &"name", &"owner", &"environment", &"cull_mask"]:
			continue
		var value: Variant = in_camera_3d.get(property.name)
		camera.set(property.name, value)


# # # # #
# # Snapshots
func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["workspace"] = workspace.create_state_snapshot()
	var structure_contexts: Dictionary = {}
	for structure_context_id: int in _structure_contexts:
		var structure_context: StructureContext = _structure_contexts[structure_context_id]
		var structure_snapshot: Dictionary = structure_context.create_state_snapshot()
		structure_contexts[structure_context_id] = structure_snapshot
	
	snapshot["structure_contexts"] = structure_contexts
	snapshot["_current_structure_context_id"] = _current_structure_context_id
	snapshot["_editable_structure_contexts_ids"] = _editable_structure_contexts_ids.duplicate()
	snapshot["rendering_snapshot"] = get_rendering().create_state_snapshot()
	
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	workspace.apply_state_snapshot(in_snapshot["workspace"])
	_editable_structure_contexts_ids = in_snapshot["_editable_structure_contexts_ids"].duplicate()
	
	var snapshot_structure_contexts: Dictionary = in_snapshot["structure_contexts"]
	
	for snapshot_structure_id: int in snapshot_structure_contexts:
		if not _structure_contexts.has(snapshot_structure_id):
			# Structure was restored but context is missing, this recreates the StructureContext
			var structure: NanoStructure = workspace.get_structure_by_int_guid(snapshot_structure_id)
			get_nano_structure_context(structure)
		
		var structure_context: StructureContext = _structure_contexts[snapshot_structure_id]
		var state_snapshot: Dictionary = snapshot_structure_contexts[snapshot_structure_id]
		structure_context.apply_state_snapshot(state_snapshot)
	
	# delete redundant StructureContextes
	for structure_context_id: int in _structure_contexts.keys():
		if snapshot_structure_contexts.has(structure_context_id):
			continue
		_structure_contexts[structure_context_id].queue_free()
		_structure_contexts.erase(structure_context_id)
		_modified_structure_contexts.erase(structure_context_id)
		_selection_modified_structure_contexts.erase(structure_context_id)
	
	_current_structure_context_id = in_snapshot["_current_structure_context_id"]
	
	get_rendering().apply_state_snapshot(in_snapshot["rendering_snapshot"])


# # # # #
# # History
func snapshot_moment(in_operation_name: String) -> void:
	# workaround for part of the state for this workspace_context being inside ScriptUtils (this will apply that state)
	get_editable_structure_contexts()
	
	# apply overdue signals, ensure snapshots contain up to date state
	_emit_selection_in_structures_changed()
	_emit_structure_content_changed()
	
	# Apply simulation if the operation modified the structure of the project
	if is_simulating() and not History.is_operation_whitelisted_during_simulation(in_operation_name):
		# We need to split the next snapshot in two separate steps:
		# + Applying the simulation
		# + Applying the user operation
		# If we don't, hitting undo will revert the user action and the simulation at the same time.
		
		end_simulation_if_running()
		
		# Store the final snapshot containing both the applied state and the last action
		var final_snapshot: Dictionary = _history.create_snapshot(in_operation_name)
		var current_simulation_time: float = _simulation.get_last_seeked_time()
		
		var emitter_states: Dictionary
		const STATES_WITH_INSTANCES = true
		for emitter: NanoParticleEmitter in get_particle_emitters():
			emitter_states[emitter.int_guid] = emitter.create_state_snapshot(STATES_WITH_INSTANCES)
		
		# Go back just before starting the simulation
		await _history.apply_previous_snapshot()
		
		# HACK: Apply the state of emitters will ensure atoms are created before
		# seek_simulation is called, but seek_simulation update them as corresponds
		if not emitter_states.is_empty():
			for emitter: NanoParticleEmitter in get_particle_emitters():
				var previous_state: Dictionary = emitter_states.get(emitter.int_guid, {})
				if previous_state.is_empty():
					continue
				emitter.apply_state_snapshot(previous_state, STATES_WITH_INSTANCES)
			await get_tree().process_frame
		
		# Rewind simulation to the latest point and create a snapshot.
		# This will drop the user operation (final_snapshot) from history. 
		seek_simulation(current_simulation_time)
		apply_simulation_if_running()
		
		# Add the user operation back to the history stack
		_history.push_and_apply_snapshot(final_snapshot, in_operation_name)
		return
	
	if not is_simulating():
		_history.create_snapshot(in_operation_name)
		return
	
	# Simulation in progress and the operation is whitelisted.
	#
	# Revert the atoms position before taking a snapshot and restore the positions to continue
	# the simulation. When the simulation is stopped, undo / redo won't reapply
	# positions coming from the simulation this way.
	var current_simulation_time: float = _simulation.get_last_seeked_time()
	seek_simulation(0.0)
	_history.create_snapshot(in_operation_name)
	seek_simulation(current_simulation_time)


func register_snapshotable(in_system: Object) -> void:
	_history.register_snapshotable(in_system)


## Apply the previous state snapshot.
##
## If a simulation is running and a whitelisted action is applied, restoring a
## snapshot will override the atoms positions from the simulation.
## To avoid that, we restore the simulation state after restoring the snapshot.
func apply_previous_snapshot() -> void:
	if not History.is_operation_whitelisted_during_simulation(_history.get_undo_name()):
		abort_simulation_if_running()
	_history.apply_previous_snapshot()
	if is_simulating():
		var current_simulation_time: float = _simulation.get_last_seeked_time()
		seek_simulation(current_simulation_time)


## Apply the next state snapshot. See `apply_previous_snapshot()` for more info.
func apply_next_snapshot() -> void:
	if not History.is_operation_whitelisted_during_simulation(_history.get_redo_name()):
		abort_simulation_if_running()
	_history.apply_next_snapshot()
	if is_simulating():
		var current_simulation_time: float = _simulation.get_last_seeked_time()
		seek_simulation(current_simulation_time)


func get_undo_name() -> String:
	return _history.get_undo_name()


func get_redo_name() -> String:
	return _history.get_redo_name()


func can_redo() -> bool:
	return _history.can_redo()


func can_undo() -> bool:
	return _history.can_undo()


func _on_history_changed() -> void:
	history_changed.emit()


func _on_history_snapshot_applied() -> void:
	history_snapshot_applied.emit()
	set_meta(_META_CACHED_SELECTION_AABB, null)


func _on_history_snapshot_created(in_snapshot_name: String) -> void:
	history_snapshot_created.emit(in_snapshot_name)


func _on_history_previous_snapshot_applied(in_snapshot_name: String) -> void:
	history_previous_snapshot_applied.emit(in_snapshot_name)


func _on_history_next_snapshot_applied(in_snapshot_name: String) -> void:
	history_next_snapshot_applied.emit(in_snapshot_name)
