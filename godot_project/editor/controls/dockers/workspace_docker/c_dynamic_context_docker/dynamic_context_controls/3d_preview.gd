extends DynamicContextControl

const WorkspaceContextScn: PackedScene = preload("res://project_workspace/workspace_context/workspace_context.tscn")
const StructureContextScn = preload("res://project_workspace/workspace_context/structure_context/structure_context.tscn")
const MIN_CAMERA_DISTANCE_TO_PIVOT: float = 0.55


@onready var _3d_preview_viewport: PreviewViewport3D = %"3DPreviewViewport"
@onready var three_d_preview_container: SubViewportContainer = $"3DPreviewContainer"
@onready var preview_camera_pivot: Node3D = _3d_preview_viewport.get_node("%PreviewCameraPivot")
@onready var camera_3d: Camera3D = _3d_preview_viewport.get_camera_3d()

var _workspace_context: WorkspaceContext = null
var _structures_to_update: Dictionary = {
#	context<int> = true<bool>
}
var _preview_structure: NanoMolecularStructure = NanoMolecularStructure.new()
var _dummy_workspace: Workspace = null
var _dummy_workspace_context: WorkspaceContext = null
var _dummy_structure_context: StructureContext = null


func _ready() -> void:
	three_d_preview_container.gui_input.connect(_on_three_d_preview_container_gui_input)


func _on_three_d_preview_container_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseMotion and in_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		preview_camera_pivot.rotation.y += deg_to_rad(-in_event.relative.x)
		_3d_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _process(delta: float) -> void:
	# workaround to godot #23729 issue (it's impossible to set Subviewport update mode reliably
	# when it's inside SubViewport container)
	var stop_preview_rerendering: bool = _3d_preview_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS
	if stop_preview_rerendering:
		_3d_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	if is_visible_in_tree():
		_3d_preview_viewport.update(delta)


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		_3d_preview_viewport.set_workspace_context(in_workspace_context)
		in_workspace_context.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)
		in_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		in_workspace_context.structure_contents_changed.connect(_on_workspace_context_structure_contents_changed)
		in_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
	var selected_atoms_count: int = 0
	var contexts_with_selection: Array[StructureContext] = in_workspace_context.get_structure_contexts_with_selection()
	for context in contexts_with_selection:
		# Check what is selected, return as soon as possible
		if context.nano_structure.is_virtual_object() and context.is_virtual_object_selected():
			return true
		if context.get_selected_bonds().size():
			return true
		selected_atoms_count += context.get_selected_atoms().size()
		if selected_atoms_count > 1:
			return true
	return selected_atoms_count > 1


func _on_workspace_context_structure_contents_changed(in_structure_context: StructureContext) -> void:
	_structures_to_update[in_structure_context.get_int_guid()] = true
	ScriptUtils.call_deferred_once(_internal_update)


func _on_workspace_context_selection_in_structures_changed(in_structure_contexts: Array[StructureContext]) -> void:
	for context: StructureContext in in_structure_contexts:
		_structures_to_update[context.get_int_guid()] = true
	ScriptUtils.call_deferred_once(_internal_update)


func _on_workspace_context_structure_about_to_remove(in_nano_structure: NanoStructure) -> void:
	var preview_rendering: Rendering = _3d_preview_viewport.get_rendering()
	
	if in_nano_structure.is_virtual_object():
		preview_rendering.remove(in_nano_structure)
	
	if in_nano_structure is AtomicStructure:
		_structures_to_update[_workspace_context.get_current_structure_context().get_int_guid()] = true
		ScriptUtils.call_deferred_once(_internal_update)


func _internal_update() -> void:
	assert(not _structures_to_update.is_empty())
	if _3d_preview_viewport == null:
		await ready
	var representation_settings: RepresentationSettings = null
	for context_id: int in _structures_to_update.keys():
		if not _workspace_context.has_nano_structure_context_id(context_id):
			# structure has been removed in meantime
			_3d_preview_viewport.get_rendering().remove_with_id(context_id)
			continue
		var context: StructureContext = _workspace_context.get_structure_context(context_id)
		if context.nano_structure.is_virtual_object():
			if !context.is_virtual_object_selected():
				# Virtual Object just unselected, remove it
				_3d_preview_viewport.get_rendering().remove(context.nano_structure)
		if not is_instance_valid(representation_settings):
			representation_settings = context.nano_structure.get_representation_settings()
	if not is_instance_valid(representation_settings):
		var context: StructureContext = _workspace_context.get_structure_context(_structures_to_update.keys()[0])
		representation_settings = context.workspace_context.workspace.representation_settings
	_preview_structure.start_edit()
	_preview_structure.set_representation_settings(representation_settings)
	_preview_structure.clear()
	_3d_preview_viewport.get_rendering().spring_preview_hide()
	_3d_preview_viewport.get_spring_selection_preview().clear()
	var preview_atoms_to_hide: PackedInt32Array = PackedInt32Array()
	var contexts_with_selection: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
	var all_items_aabb := AABB()
	for context in contexts_with_selection:
		var structure: NanoStructure = context.nano_structure
		if structure is NanoShape and structure.get_shape() != null:
			# Add shape to preview viewport
			var shape_aabb: AABB = structure.get_shape_aabb()
			if !all_items_aabb.has_surface():
				all_items_aabb = shape_aabb
			else:
				all_items_aabb = all_items_aabb.merge(shape_aabb)
			var is_renderer_initialized: bool = _3d_preview_viewport.get_rendering().is_renderer_for_nano_shape_built(structure)
			if not is_renderer_initialized:
				_3d_preview_viewport.get_rendering().build_reference_shape_rendering(structure)
		if structure is NanoVirtualMotor:
			# Add motor to preview viewport
			var motor_aabb: AABB = structure.get_aabb()
			if !all_items_aabb.has_surface():
				all_items_aabb = motor_aabb
			else:
				all_items_aabb = all_items_aabb.merge(motor_aabb)
			var is_renderer_initialized: bool = _3d_preview_viewport.get_rendering().is_renderer_for_motor_built(structure)
			if not is_renderer_initialized:
				_3d_preview_viewport.get_rendering().build_virtual_motor_rendering(structure)
		elif structure is NanoVirtualAnchor:
			# Add anchor to preview viewport
			var anchor_aabb: AABB = structure.get_aabb()
			if !all_items_aabb.has_surface():
				all_items_aabb = anchor_aabb
			else:
				all_items_aabb = all_items_aabb.merge(anchor_aabb)
			var is_renderer_initialized: bool = _3d_preview_viewport.get_rendering().is_renderer_for_anchor_built(structure)
			if not is_renderer_initialized:
				_3d_preview_viewport.get_rendering().build_virtual_anchor_rendering(structure)
		var real_structure_to_preview_structure_id_map: Dictionary = {}
		var selected_atoms: PackedInt32Array = context.get_selected_atoms()
		if !selected_atoms.is_empty():
			for i in range(selected_atoms.size()):
				var selected_atom_id: int = selected_atoms[i]
				if not structure.is_atom_valid(selected_atom_id):
					push_error("Invalid selection, was the atom recently removed?")
					continue
				_try_add_atom_to_preview_structure(structure, selected_atom_id, real_structure_to_preview_structure_id_map)

		var selected_bonds: PackedInt32Array = context.get_selected_bonds()
		for bond_id in selected_bonds:
			var bond: Vector3i = structure.get_bond(bond_id)
			var added_first_atom: bool = _try_add_atom_to_preview_structure(structure, bond.x, real_structure_to_preview_structure_id_map)
			var added_second_atom: bool = _try_add_atom_to_preview_structure(structure, bond.y, real_structure_to_preview_structure_id_map)
			var bond_first_preview_atom: int = real_structure_to_preview_structure_id_map[bond.x]
			var bond_second_preview_atom: int  = real_structure_to_preview_structure_id_map[bond.y]
			_preview_structure.add_bond(bond_first_preview_atom, bond_second_preview_atom, bond.z)
			if added_first_atom:
				preview_atoms_to_hide.push_back(bond_first_preview_atom)
			if added_second_atom:
				preview_atoms_to_hide.push_back(bond_second_preview_atom)
		
		var selected_springs: PackedInt32Array = context.get_selected_springs()
		var atom_positions: PackedVector3Array = PackedVector3Array()
		var anchor_positions: PackedVector3Array = PackedVector3Array()
		var any_spring_selected: bool = not selected_springs.is_empty()
		if any_spring_selected:
			for spring_id: int in selected_springs:
				assert(structure.spring_has(spring_id), "Selected spring is invalid, ensure invalid
						springs are not selected")
				atom_positions.append(structure.spring_get_atom_position(spring_id))
				anchor_positions.append(structure.spring_get_anchor_position(spring_id, context))
			_3d_preview_viewport.get_spring_selection_preview().add(atom_positions, anchor_positions)
	_3d_preview_viewport.get_spring_selection_preview().render()
	
	if !all_items_aabb.has_volume():
		all_items_aabb = _preview_structure.get_aabb()
	else:
		if _preview_structure.get_valid_atoms_count() > 0:
			all_items_aabb = all_items_aabb.merge(_preview_structure.get_aabb())
	
	var distance_to_pivot: float = max(all_items_aabb.get_longest_axis_size() * 3.0, MIN_CAMERA_DISTANCE_TO_PIVOT)
	_3d_preview_viewport.set_preview_camera_pivot_position(all_items_aabb.get_center())
	_3d_preview_viewport.set_preview_camera_distance_to_pivot(distance_to_pivot)
	_preview_structure.end_edit()
	_preview_structure.set_atoms_visibility(preview_atoms_to_hide, false, false)
	
	var is_renderer_initialized: bool = _3d_preview_viewport.get_rendering().is_renderer_for_atomic_structure_built(_preview_structure)
	if not is_renderer_initialized:
		_dummy_workspace_context = WorkspaceContextScn.instantiate()
		_dummy_workspace = Workspace.new()
		add_child(_dummy_workspace_context)
		_dummy_workspace_context.initialize(_dummy_workspace)
		_dummy_workspace.add_structure(_preview_structure)
		_dummy_workspace_context.rendering_override = _3d_preview_viewport.get_rendering()
		_dummy_structure_context = StructureContextScn.instantiate()
		_dummy_structure_context.initialize(_dummy_workspace_context, _preview_structure.int_guid, _preview_structure)
		add_child(_dummy_structure_context)
		_dummy_workspace_context._structure_contexts[_preview_structure.int_guid] = _dummy_structure_context
		_dummy_structure_context.get_collision_engine().disable_pernamently()
		_dummy_workspace_context.set_current_structure_context(_dummy_structure_context)
		if is_instance_valid(representation_settings):
			# Share representation settings
			_dummy_workspace.representation_settings = representation_settings
		_3d_preview_viewport.get_rendering().initialize(_dummy_workspace_context)
		_3d_preview_viewport.get_rendering().build_atomic_structure_rendering(_dummy_structure_context, representation_settings.get_rendering_representation())
		_3d_preview_viewport.get_rendering().disable_labels()
		_3d_preview_viewport.get_rendering().refresh_atom_sizes()
	
	if is_instance_valid(representation_settings) and representation_settings.get_rendering_representation() \
			!= _3d_preview_viewport.get_rendering().get_default_representation():
		_3d_preview_viewport.get_rendering().change_default_representation(representation_settings.get_rendering_representation())
	
	_3d_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	_structures_to_update.clear()


## Returns true if this function added a new atom to the preview.
## Returns false if the atom was already part of the preview.
func _try_add_atom_to_preview_structure(in_structure: NanoStructure, in_atom_id: int, out_real_structure_to_preview_structure_id_map: Dictionary) -> bool:
	if out_real_structure_to_preview_structure_id_map.has(in_atom_id):
		return false
	var atomic_number: int = in_structure.atom_get_atomic_number(in_atom_id)
	var atom_pos: Vector3 = in_structure.atom_get_position(in_atom_id)
	var params := AtomicStructure.AddAtomParameters.new(atomic_number, atom_pos)
	var preview_atom_id: int = _preview_structure.add_atom(params)
	out_real_structure_to_preview_structure_id_map[in_atom_id] = preview_atom_id
	return true


func _on_workspace_context_history_snapshot_applied() -> void:
	# TODO: this is painfully slow, like the rest of this class. We should rework it completelly
	var contexts_with_selection: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
	for context: StructureContext in contexts_with_selection:
		_structures_to_update[context.get_int_guid()] = true
	
	var renderer: Rendering = _workspace_context.get_rendering()
	var rendered_structures: PackedInt32Array = renderer.get_rendered_structures()
	for structure_id: int in rendered_structures:
		var is_structure_part_of_preview: bool = _structures_to_update.get(structure_id, false)
		var structure_needs_to_be_removed_from_preview_renderer: bool = not is_structure_part_of_preview
		if structure_needs_to_be_removed_from_preview_renderer:
			_structures_to_update[structure_id] = true
	
	var current_theme: Theme3D = _workspace_context.workspace.representation_settings.get_theme()
	_3d_preview_viewport.get_rendering().apply_theme(current_theme)
	
	if _structures_to_update.size() > 0:
		ScriptUtils.call_deferred_once(_internal_update)
	
