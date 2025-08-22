class_name ParticleEmitterRenderer extends Node3D


@export_group("Scene Setup")
@export var _spin_axle: MeshInstance3D

var _emitter_id: int
var _molecule_instance_count: int = 1
var _workspace_context: WorkspaceContext
var _structure_previews: Array[StructurePreview]


var _materials: Array[ShaderMaterial]
var _meshes: Array[MeshInstance3D]


var _should_hide_in_simulation: bool = false
var _is_simulating: bool = false
var _object_visible: bool = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		# Setting top_level = true will prevent the preview from rotating
		_seek_materials_recursively($ParticleEmitterModel)


func _enter_tree() -> void:
	var editor_viewport: WorkspaceEditorViewport = get_viewport() as WorkspaceEditorViewport
	if not is_instance_valid(editor_viewport):
		return
	var workspace_context: WorkspaceContext = editor_viewport.get_workspace_context()
	if is_instance_valid(workspace_context) and not workspace_context.hovered_structure_context_changed.is_connected(
					_on_workspace_context_hovered_structure_context_changed):
		workspace_context.hovered_structure_context_changed.connect(_on_workspace_context_hovered_structure_context_changed)
		workspace_context.editable_structure_context_list_changed.connect(_on_workspace_context_editable_structure_context_list_changed)
		workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)


func _seek_materials_recursively(out_node: Node) -> void:
	var mesh_instance: MeshInstance3D = out_node as MeshInstance3D
	if is_instance_valid(mesh_instance) and is_instance_valid(mesh_instance.mesh):
		_meshes.push_back(mesh_instance)
		for i: int in mesh_instance.mesh.get_surface_count():
			var mat: Material = mesh_instance.mesh.surface_get_material(i)
			assert(mat is ShaderMaterial, "Did not replace material of %s:material[%d]" % [get_path_to(mesh_instance), i])
			var shader_mat: ShaderMaterial = mat.duplicate() as ShaderMaterial
			assert(RenderingUtils.has_uniform(shader_mat, "is_hovered"),
					"Missing uniform 'is_hovered' in %s:material[%d]" % [get_path_to(mesh_instance), i])
			assert(RenderingUtils.has_uniform(shader_mat, "is_selected"),
					"Missing uniform 'is_selected' in %s:material[%d]" % [get_path_to(mesh_instance), i])
			mesh_instance.set_surface_override_material(i, shader_mat)
			_materials.push_back(shader_mat)
	# recursively seek
	for child: Node in out_node.get_children():
		_seek_materials_recursively(child)


func build(in_workspace_context: WorkspaceContext, in_emitter: NanoParticleEmitter) -> void:
	_emitter_id = in_emitter.get_int_guid()
	_workspace_context = in_workspace_context
	
	_ensure_emitter_signal_connections(in_emitter)
	
	var template: NanoStructure = in_emitter.get_parameters().get_molecule_template()
	if not template.get_representation_settings():
		template.set_representation_settings(in_emitter.get_representation_settings())
	var parameters: NanoParticleEmitterParameters = in_emitter.get_parameters()
	
	_on_emitter_parameters_changed(parameters)
	_on_emitter_transform_changed(in_emitter.get_transform())
	_on_emitter_visibility_changed(in_emitter.get_visible())


func _ensure_emitter_signal_connections(in_emitter_or_null: NanoParticleEmitter = null) -> void:
	if in_emitter_or_null == null:
		# This assumes workspace is active.
		# Should only be happening because of undo/redo from apply_state_snapshot()
		# If asserts ever happens check if this callback is comming from a different source
		var workspace: Workspace = MolecularEditorContext.get_current_workspace()
		assert(workspace.has_structure_with_int_guid(_emitter_id), "Particle emitter not present in active workspace")
		in_emitter_or_null = workspace.get_structure_by_int_guid(_emitter_id) as NanoParticleEmitter
		assert(in_emitter_or_null != null, "NanoStructure with id %d in current workspace is not a NanoParticleEmitter!")
	if not in_emitter_or_null.transform_changed.is_connected(_on_emitter_transform_changed):
		in_emitter_or_null.transform_changed.connect(_on_emitter_transform_changed)
		in_emitter_or_null.visibility_changed.connect(_on_emitter_visibility_changed)
		var parameters: NanoParticleEmitterParameters = in_emitter_or_null.get_parameters()
		parameters.changed.connect(_on_emitter_parameters_changed.bind(parameters))
		var workspace: Workspace = MolecularEditorContext.find_workspace_possessing_structure(in_emitter_or_null)
		var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(workspace)
		workspace.representation_settings \
			.should_hide_virtual_object_during_simulation_changed \
			.connect(_on_should_hide_virtual_object_during_simulation_changed)
		workspace_context.simulation_started.connect(_on_simulation_started_or_finished.bind(true))
		workspace_context.simulation_finished.connect(_on_simulation_started_or_finished.bind(false))
		_is_simulating = workspace_context.is_simulating()
		_should_hide_in_simulation = workspace_context.workspace.representation_settings \
				.get_should_hide_virtual_object_during_simulation(NanoParticleEmitter)
		_update_visibility()


func disable_hover() -> void:
	# This is used to ensure the hover effect is never used in the 3D preview of the DynamicContextDocker
	var editor_viewport: SubViewport = get_viewport()
	var workspace_context: WorkspaceContext = editor_viewport.get_workspace_context()
	if workspace_context and workspace_context.hovered_structure_context_changed.is_connected(_on_workspace_context_hovered_structure_context_changed):
		workspace_context.hovered_structure_context_changed.disconnect(_on_workspace_context_hovered_structure_context_changed)
		const NOT_HOVERED = 0
		_set_shader_uniform(&"is_hovered", NOT_HOVERED)


func transform_by_external_transform(in_selection_initial_pos: Vector3, in_initial_nano_struct_transform: Transform3D,
			in_external_transform: Transform3D) -> void:
	var inverse_gizmo_basis: Basis = in_external_transform.affine_inverse().basis.transposed()
	var local_transform := Transform3D(inverse_gizmo_basis, in_external_transform.origin)
	var relative_transform: Transform3D = local_transform * in_initial_nano_struct_transform
	var final_rotation: Transform3D = Transform3D(relative_transform.basis, relative_transform.origin)
	var delta_pos: Vector3 = in_initial_nano_struct_transform.origin - in_selection_initial_pos
	var new_pos: Vector3 = in_external_transform.origin + in_external_transform.basis * delta_pos
	global_transform = Transform3D(final_rotation.basis.orthonormalized(), new_pos)
	var emitter: NanoParticleEmitter = _workspace_context.workspace.get_structure_by_int_guid(_emitter_id)
	for i: int in _structure_previews.size():
		var preview: StructurePreview = _structure_previews[i]
		preview.global_position = global_transform.origin + emitter.calculate_instance_offset(i)


func _set_structure_preview_count(in_count: int) -> void:
	const STRUCTURE_PREVIEW_SCN: PackedScene = preload("uid://dtf1gkl710hh8")
	while in_count < _structure_previews.size():
		var to_delete: StructurePreview = _structure_previews.pop_back()
		to_delete.queue_free()
	if in_count > _structure_previews.size():
		var emitter: NanoParticleEmitter = _workspace_context.workspace.get_structure_by_int_guid(_emitter_id)
		var template: AtomicStructure = emitter.get_parameters().get_molecule_template()
		while in_count > _structure_previews.size():
			var instance: StructurePreview = STRUCTURE_PREVIEW_SCN.instantiate() as StructurePreview
			var index: int = _structure_previews.size()
			instance.name = "Instance_%d" % index
			instance.top_level = true
			add_child(instance)
			instance.set_structure(template)
			instance.set_auto_update(false)
			instance.global_position = global_position + emitter.calculate_instance_offset(index)
			instance.visible = self.visible
			_structure_previews.push_back(instance)


func _on_emitter_transform_changed(in_transform: Transform3D) -> void:
	global_transform = in_transform
	var emitter: NanoParticleEmitter = _workspace_context.workspace.get_structure_by_int_guid(_emitter_id)
	for i: int in _structure_previews.size():
		var preview: StructurePreview = _structure_previews[i]
		preview.global_position = in_transform.origin + emitter.calculate_instance_offset(i)


func update(delta: float) -> void:
	for preview: StructurePreview in _structure_previews:
		preview.update(delta)


func _on_emitter_visibility_changed(in_visible: bool) -> void:
	_object_visible = in_visible
	_update_visibility()


func _on_should_hide_virtual_object_during_simulation_changed(in_type: StringName, in_should_hide: bool) -> void:
	if in_type == RepresentationSettings.script_to_virtual_object_key(NanoParticleEmitter):
		_should_hide_in_simulation = in_should_hide
		_update_visibility()


func _on_simulation_started_or_finished(in_is_simulating: bool) -> void:
	_is_simulating = in_is_simulating
	_update_visibility()


func _update_visibility() -> void:
	visible = _object_visible and ((not _is_simulating) or (not _should_hide_in_simulation))
	for preview: StructurePreview in _structure_previews:
		preview.visible = visible


func _on_emitter_parameters_changed(in_parameters: NanoParticleEmitterParameters) -> void:
	_molecule_instance_count = in_parameters.get_molecules_per_instance()
	_set_structure_preview_count(_molecule_instance_count)
	var spin_speed: float = in_parameters.get_instance_spin_revolutions_per_nanosecond()
	if is_equal_approx(spin_speed, .0):
		_spin_axle.hide()
	else:
		_spin_axle.show()
		_spin_axle.scale.x = sign(spin_speed)


func _on_workspace_context_hovered_structure_context_changed(
			toplevel_hovered_structure_context: StructureContext,
			in_hovered_structure_context: StructureContext,
			_in_atom_id: int, _in_bond_id: int, _in_spring_id: int) -> void:
	var emitter: NanoParticleEmitter = _workspace_context.workspace.get_structure_by_int_guid(_emitter_id)
	var is_emitter_hovered: bool = false
	if is_instance_valid(toplevel_hovered_structure_context) and is_instance_valid(emitter) and \
			_workspace_context.workspace.is_a_ancestor_of_b(toplevel_hovered_structure_context.nano_structure, emitter):
		is_emitter_hovered = true
	else:
		is_emitter_hovered = is_instance_valid(in_hovered_structure_context) \
			and in_hovered_structure_context.nano_structure is NanoParticleEmitter \
			and in_hovered_structure_context.nano_structure.get_int_guid() == _emitter_id
	const HOVERED_VALUE: float = 1.0
	const UNHOVERED_VALUE: float = 0.0
	_set_shader_uniform(&"is_hovered", HOVERED_VALUE if is_emitter_hovered else UNHOVERED_VALUE)


func _on_workspace_context_editable_structure_context_list_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	var this_emitter_found: bool = false
	for context: StructureContext in in_new_editable_structure_contexts:
		if context.nano_structure.int_guid == _emitter_id:
			this_emitter_found = true
			break
	const SELECTABLE_VALUE: float = 1.0
	const UNSELECTABLE_VALUE: float = 0.0
	_set_shader_uniform(&"is_selectable", SELECTABLE_VALUE if this_emitter_found else UNSELECTABLE_VALUE)


func _on_workspace_context_selection_in_structures_changed(out_structure_contexts: Array[StructureContext]) -> void:
	for context: StructureContext in out_structure_contexts:
		var is_this_emitter: bool = context.nano_structure.int_guid == _emitter_id
		if is_this_emitter:
			const SELECTED_VALUE: float = 1.0
			const UNSELECTED_VALUE: float = 0.0
			var is_selected: bool = context.is_particle_emitter_selected()
			_set_shader_uniform(&"is_selected",SELECTED_VALUE if is_selected else UNSELECTED_VALUE)
			_set_selection_preview_flag(is_selected)
			return


func _set_selection_preview_flag(in_is_selected: bool) -> void:
	for mesh: MeshInstance3D in _meshes:
		mesh.set_layer_mask_value(Rendering.SELECTION_PREVIEW_LAYER_BIT, in_is_selected)


func _set_shader_uniform(in_uniform: StringName, in_value: Variant) -> void:
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter(in_uniform, in_value)


func _get_shader_uniform(in_uniform: StringName) -> Variant:
	return _materials[0].get_shader_parameter(in_uniform)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_molecule_instance_count"] = _molecule_instance_count
	snapshot["global_transform"] = global_transform
	snapshot["_object_visible"] = _object_visible
	snapshot["_should_hide_in_simulation"] = _should_hide_in_simulation
	snapshot["_spin_axle.visible"] = _spin_axle.visible
	snapshot["_spin_axle.scale"] = _spin_axle.scale
	snapshot["material_selected"] = _get_shader_uniform(&"is_selected")
	snapshot["material_selectable"] = _get_shader_uniform(&"is_selectable")
	snapshot["_emitter_id"] = _emitter_id
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_workspace_context = in_snapshot["_workspace_context"]
	_emitter_id = in_snapshot["_emitter_id"]
	_spin_axle.visible = in_snapshot["_spin_axle.visible"]
	_spin_axle.scale = in_snapshot["_spin_axle.scale"]
	_ensure_emitter_signal_connections()
	_on_emitter_transform_changed(in_snapshot["global_transform"])
	_object_visible = in_snapshot["_object_visible"]
	_should_hide_in_simulation = in_snapshot["_should_hide_in_simulation"]
	# assume _is_simulating is up to date since this is not changed by undo history
	_update_visibility()
	_set_structure_preview_count(in_snapshot["_molecule_instance_count"])
	_set_shader_uniform(&"is_selected", in_snapshot["material_selected"])
	_set_selection_preview_flag(in_snapshot["material_selected"])
	_set_shader_uniform(&"is_selectable", in_snapshot["material_selectable"])
