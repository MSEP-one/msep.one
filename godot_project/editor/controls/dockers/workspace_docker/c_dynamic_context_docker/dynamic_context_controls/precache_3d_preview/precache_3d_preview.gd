extends "res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/3d_preview.gd"
## The goal of this scene is to be used by ShaderPrecompiler to ensure 3DPreview is not compiling
## shaders when seen for the first time


var _representation_settings: RepresentationSettings = RepresentationSettings.new()


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_READY:
		_init_for_shader_precompiler()


func _init_for_shader_precompiler() -> void:
	_preview_structure.set_structure_name("dummy")
	_preview_structure.start_edit()
	_preview_structure.set_representation_settings(_representation_settings)
	var first_add_atom_param := AtomicStructure.AddAtomParameters.new(
			PeriodicTable.ATOMIC_NUMBER_CARBON, Vector3(0.1,0,0))
	var second_add_atom_param := AtomicStructure.AddAtomParameters.new(
			PeriodicTable.ATOMIC_NUMBER_CARBON, Vector3(-0.1,0,0))
	var third_add_atom_param := AtomicStructure.AddAtomParameters.new(
			PeriodicTable.ATOMIC_NUMBER_CARBON, Vector3(0.1,0,0.1))
	var fourth_add_atom_param := AtomicStructure.AddAtomParameters.new(
			PeriodicTable.ATOMIC_NUMBER_CARBON, Vector3(-0.1,0,-0.1))
	var atom1_id: int = _preview_structure.add_atom(first_add_atom_param)
	var atom2_id: int = _preview_structure.add_atom(second_add_atom_param)
	var atom3_id: int = _preview_structure.add_atom(third_add_atom_param)
	var atom4_id: int = _preview_structure.add_atom(fourth_add_atom_param)
	_preview_structure.add_bond(atom1_id, atom2_id, 1)
	_preview_structure.add_bond(atom2_id, atom3_id, 2)
	_preview_structure.add_bond(atom3_id, atom4_id, 3)
	_preview_structure.end_edit()
	_preview_structure.set_representation_settings(_representation_settings)
	var dummy_workspace_context: WorkspaceContext = WorkspaceContextScn.instantiate()
	_dummy_workspace = Workspace.new()
	_dummy_workspace.add_structure(_preview_structure)
	dummy_workspace_context.initialize(_dummy_workspace)
	add_child(dummy_workspace_context)
	if _preview_structure.get_structure_name().is_empty():
		var structure_name: String = str(_preview_structure.get_int_guid())
		_preview_structure.set_structure_name(structure_name)
	_dummy_structure_context = dummy_workspace_context.get_nano_structure_context(_preview_structure)
	_dummy_structure_context.initialize(dummy_workspace_context, _preview_structure.int_guid, _preview_structure)
	assert(_dummy_workspace.has_structure_with_int_guid(_dummy_structure_context.get_int_guid()))
	_dummy_structure_context.get_collision_engine().disable_pernamently()
	_3d_preview_viewport.get_rendering().initialize(dummy_workspace_context)
	_3d_preview_viewport.get_rendering().build_atomic_structure_rendering(_dummy_structure_context,
			_representation_settings.get_rendering_representation())
	_3d_preview_viewport.get_rendering().disable_labels()
	_3d_preview_viewport.get_rendering().refresh_atom_sizes()
	_3d_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _on_switch_rendering_delayer_timeout() -> void:
	assert(is_visible_in_tree(), "needs to be rendered for the precompilation to happen")
	var rendering: Rendering = _3d_preview_viewport.get_rendering()
	rendering.change_default_representation(Rendering.Representation.ENHANCED_STICKS_AND_BALLS)
	_3d_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	hide()
