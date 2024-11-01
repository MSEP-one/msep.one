extends "res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/3d_preview.gd"
## The goal of this scene is to be used by ShaderPrecompiler to ensure 3DPreview is not compiling
## shaders when seen for the first time


var _representation_settings: RepresentationSettings = RepresentationSettings.new()
var _preview_structure: NanoMolecularStructure = NanoMolecularStructure.new()


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
	if _preview_structure.get_structure_name().is_empty():
		var structure_name: String = str(_preview_structure.get_int_guid())
		_preview_structure.set_structure_name(structure_name)


func _on_switch_rendering_delayer_timeout() -> void:
	assert(is_visible_in_tree(), "needs to be rendered for the precompilation to happen")
	hide()
