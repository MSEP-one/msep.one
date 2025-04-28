extends Node
# # # # # # # #
# This scene is used to force early material compilation
# It's doing it by displaying majority of materials which are used in the project

@onready var force_compilation_container: SubViewportContainer = $ForceCompilationContainer
@onready var sphere_representation_multimesh: MultiMeshInstance3D = $ForceCompilationContainer/ForceCompilationSubviewport/Atom/SphereRepresentationMultiMesh
@onready var camera: Camera3D = $ForceCompilationContainer/ForceCompilationSubviewport/Camera3D
@onready var gizmo: Node3D = $ForceCompilationContainer/ForceCompilationSubviewport/Atom/gizmo
@onready var bond_cylinder_single: MultiMeshInstance3D = $ForceCompilationContainer/ForceCompilationSubviewport/Bond/MultiMeshInstance3D
@onready var sticks_single: MultiMeshInstance3D = $ForceCompilationContainer/ForceCompilationSubviewport/Sticks/MultiMeshInstance3D
@onready var enhanced_sticks:MultiMeshInstance3D = $ForceCompilationContainer/ForceCompilationSubviewport/EnhancedSticks/MultiMeshInstance3D
@onready var single_atom: MultiMeshInstance3D = $ForceCompilationContainer/ForceCompilationSubviewport/SingleAtomBond/MultiMeshInstance3D
@onready var atom_labels: MultiMeshInstance3D = $ForceCompilationContainer/ForceCompilationSubviewport/AtomLabels/MultiMeshInstance3D
@onready var ring_menu_atom_icon: RingMenuAtomIcon = $ForceCompilationContainer/ForceCompilationSubviewport/RingMenuSubviewportContainer/SubViewport/RingMenu3D/buttons/Button9/RingMenuAtomIcon
@onready var hide_delayer: Timer = $HideDelayer


func _ready() -> void:
	assert(is_instance_valid(ring_menu_atom_icon))
	
	# Atom sphere material
	var theme: Theme3D = load("res://theme/theme_3d/available_themes/modern_theme/modern_theme.tres")
	var sphere_representation_material: ShaderMaterial = theme.create_ball_material()
	_ensure_atom_material_preprendered(sphere_representation_multimesh, sphere_representation_material)

	# Bond material
	_ensure_bond_multimesh_prerendered(bond_cylinder_single)
	
	# Sticks material
	_ensure_stick_material_prerendered(sticks_single)

	# Enhanced sticks material
	_ensure_stick_material_prerendered(enhanced_sticks)
	
	# Single stick atom material
	_ensure_atom_material_preprendered(single_atom, single_atom.material_override)
	
	# 3d atom labels material
	_ensure_atom_material_preprendered(atom_labels, atom_labels.material_override)
	

func _exit_tree() -> void:
	queue_free()


func _ensure_atom_material_preprendered(in_multimesh_instance: MultiMeshInstance3D, in_material: ShaderMaterial) -> void:
	var shader: ShaderMaterial = in_material.duplicate()
	in_multimesh_instance.multimesh.instance_count = 2
	in_multimesh_instance.multimesh.visible_instance_count = 2
	in_multimesh_instance.material_override = shader
	shader.set_shader_parameter("gizmo_origin", gizmo.global_transform.basis.y)
	shader.set_shader_parameter("gizmo_rotation", gizmo.global_transform.basis.x)
	shader.set_shader_parameter("scale", 1.0)
	var transform: Transform3D = Transform3D()
	transform = transform.scaled(Vector3(0.1,0.1,0.1))
	in_multimesh_instance.multimesh.set_instance_transform(0, transform)
	in_multimesh_instance.multimesh.set_instance_custom_data(0, Color(1.0,1.0,1.0,0.0))


func _ensure_stick_material_prerendered(in_multimesh_instance: MultiMeshInstance3D) -> void:
	in_multimesh_instance.multimesh.instance_count = 2
	in_multimesh_instance.multimesh.visible_instance_count = 2
	var shader_sticks_single: ShaderMaterial = in_multimesh_instance.multimesh.mesh.surface_get_material(0)
	in_multimesh_instance.material_override = shader_sticks_single
	var transform_sticks_single: Transform3D = Transform3D()
	transform_sticks_single = transform_sticks_single.scaled(Vector3(0.1,0.1,0.1))
	transform_sticks_single = transform_sticks_single.looking_at(Vector3(1,0,0), Vector3(0,1,0))
	in_multimesh_instance.multimesh.set_instance_transform(0, transform_sticks_single)
	in_multimesh_instance.multimesh.set_instance_custom_data(0, Color(1.0,1.0,1.0,1.0))
	

func _ensure_bond_multimesh_prerendered(in_multimesh_instance: MultiMeshInstance3D) -> void:
	in_multimesh_instance.multimesh.instance_count = 2
	in_multimesh_instance.multimesh.visible_instance_count = 2
	var shader: ShaderMaterial = in_multimesh_instance.material_override.duplicate()
	in_multimesh_instance.material_override = shader
	shader.set_shader_parameter("camera_forward_vector", camera.global_transform.basis.z)
	shader.set_shader_parameter("gizmo_origin", Vector3())#gizmo.global_transform.origin)
	shader.set_shader_parameter("gizmo_rotation", gizmo.global_transform.basis)
	var transform: Transform3D = Transform3D()
	transform = transform.scaled(Vector3(0.1,0.1,0.1))
	transform = transform.looking_at(Vector3(1,0,0), Vector3(0,1,0))
	in_multimesh_instance.multimesh.set_instance_transform(0, transform)
	in_multimesh_instance.multimesh.set_instance_custom_data(0, Color(1.0,1.0,1.0,1.0))


func _on_hide_delayer_timeout() -> void:
	# To consider: would be worth to remove this in favour of doing a check if there is any shader
	# which is still compiling. At the time of writting this the api for this has not been ported yet
	# from Godot 3.x to Godot 4.x
	force_compilation_container.hide()
