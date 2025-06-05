class_name VirtualMotorRenderer extends Node3D


var parameters: NanoVirtualMotorParameters:
	set = _set_parameters

var _motor_id: int
var _workspace_context: WorkspaceContext
var _gear_model: MeshInstance3D
var _motor_model: MeshInstance3D

var _rotary_polarity: Sprite3D
var _rotary_axle: MeshInstance3D
var _linear_polarity: Sprite3D
var _materials: Array[ShaderMaterial]
var _animate_polarity: AnimationPlayer
var _camera: Camera3D


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_rotary_polarity = $RotaryPolarity as Sprite3D
		_rotary_axle = $RotaryPolarity/Axle as MeshInstance3D
		_linear_polarity = $LinearPolarity as Sprite3D
		_animate_polarity = $AnimatePolarity as AnimationPlayer
		# Initialize Materials
		_materials = []
		var model_root: Node = $motor3D_Gears00
		_gear_model = $motor3D_Gears00/Gear
		_motor_model = $motor3D_Gears00/Motor
		_seek_materials_recursively(model_root)


func _seek_materials_recursively(out_node: Node) -> void:
	var mesh_instance: MeshInstance3D = out_node as MeshInstance3D
	if is_instance_valid(mesh_instance) and is_instance_valid(mesh_instance.mesh):
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


func build(in_workspace_context: WorkspaceContext, in_motor: NanoVirtualMotor) -> void:
	assert(parameters == null, "Renderer can only by built once")
	_motor_id = in_motor.get_int_guid()
	_workspace_context = in_workspace_context
	parameters = in_motor.get_parameters()
	global_transform = in_motor.get_transform()
	in_motor.transform_changed.connect(_on_virtual_motor_transform_changed)
	in_motor.visibility_changed.connect(_on_virtual_motor_visibility_changed)
	self.visible = in_motor.get_visible()


func update(_in_delta: float) -> void:
	if not is_instance_valid(_camera) or not _camera.current:
		_camera = get_viewport().get_camera_3d()
		if _camera == null: return
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_rotary_axle.set_instance_shader_parameter(&"distance_to_camera", _camera.size * 5.0)
	else:
		_rotary_axle.set_instance_shader_parameter(&"distance_to_camera", _rotary_axle.global_position.distance_to(_camera.global_position))


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


func _set_parameters(in_parameters: NanoVirtualMotorParameters) -> void:
	if parameters != null:
		parameters.changed.disconnect(_on_parameters_changed)
	parameters = in_parameters
	parameters.changed.connect(_on_parameters_changed)
	if not is_node_ready():
		await ready
	_update_type_and_polarity()


func _on_parameters_changed() -> void:
	_update_type_and_polarity()


func _update_type_and_polarity() -> void:
	match parameters.motor_type:
		NanoVirtualMotorParameters.Type.ROTARY:
			var rotary_parameters: NanoRotaryMotorParameters = parameters as NanoRotaryMotorParameters
			_rotary_polarity.show()
			_linear_polarity.hide()
			if rotary_parameters.polarity == NanoRotaryMotorParameters.Polarity.CLOCKWISE:
				_rotary_polarity.flip_v = true
				_animate_polarity.play("idle")
			else:
				_rotary_polarity.flip_v = false
				_animate_polarity.play_backwards("idle")
		NanoVirtualMotorParameters.Type.LINEAR:
			var linear_parameters: NanoLinearMotorParameters = parameters as NanoLinearMotorParameters
			_linear_polarity.show()
			_rotary_polarity.hide()
			_animate_polarity.play("idle")
			if linear_parameters.polarity == NanoLinearMotorParameters.Polarity.FORWARD:
				_linear_polarity.flip_h = false
			else:
				_linear_polarity.flip_h = true


func _on_virtual_motor_transform_changed(in_transform: Transform3D) -> void:
	global_transform = in_transform


func _on_virtual_motor_visibility_changed(in_visible: bool) -> void:
	self.visible = in_visible


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


func _on_workspace_context_hovered_structure_context_changed(
			toplevel_hovered_structure_context: StructureContext,
			in_hovered_structure_context: StructureContext,
			_in_atom_id: int, _in_bond_id: int, _in_spring_id: int) -> void:
	var motor: NanoVirtualMotor = _workspace_context.workspace.get_structure_by_int_guid(_motor_id)
	var is_motor_hovered: bool = false
	if is_instance_valid(toplevel_hovered_structure_context) and is_instance_valid(motor) and \
			_workspace_context.workspace.is_a_ancestor_of_b(toplevel_hovered_structure_context.nano_structure, motor):
		is_motor_hovered = true
	else:
		is_motor_hovered = is_instance_valid(in_hovered_structure_context) \
			and in_hovered_structure_context.nano_structure is NanoVirtualMotor \
			and in_hovered_structure_context.nano_structure.get_parameters() == parameters
	const HOVERED_VALUE: float = 1.0
	const UNHOVERED_VALUE: float = 0.0
	_set_shader_uniform(&"is_hovered", HOVERED_VALUE if is_motor_hovered else UNHOVERED_VALUE)


func _on_workspace_context_editable_structure_context_list_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	var this_motor_found: bool = false
	for context: StructureContext in in_new_editable_structure_contexts:
		if context.nano_structure is NanoVirtualMotor and context.nano_structure.get_parameters() == parameters:
			this_motor_found = true
			break
	const SELECTABLE_VALUE: float = 1.0
	const UNSELECTABLE_VALUE: float = 0.0
	_set_shader_uniform(&"is_selectable", SELECTABLE_VALUE if this_motor_found else UNSELECTABLE_VALUE)


func _on_workspace_context_selection_in_structures_changed(out_structure_contexts: Array[StructureContext]) -> void:
	for context: StructureContext in out_structure_contexts:
		var is_this_motor: bool = context.nano_structure is NanoVirtualMotor and \
				context.nano_structure.get_parameters() == parameters
		if is_this_motor:
			const SELECTED_VALUE: float = 1.0
			const UNSELECTED_VALUE: float = 0.0
			var is_selected: bool = context.is_motor_selected()
			_set_shader_uniform(&"is_selected",SELECTED_VALUE if is_selected else UNSELECTED_VALUE)
			_refresh_selection_preview(is_selected)
			return


func _set_shader_uniform(in_uniform: StringName, in_value: Variant) -> void:
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter(in_uniform, in_value)


func _get_shader_uniform(in_uniform: StringName) -> Variant:
	return _materials[0].get_shader_parameter(in_uniform)


func _refresh_selection_preview(in_is_selected: bool) -> void:
	_gear_model.set_layer_mask_value(Rendering.SELECTION_PREVIEW_LAYER_BIT, in_is_selected)
	_motor_model.set_layer_mask_value(Rendering.SELECTION_PREVIEW_LAYER_BIT, in_is_selected)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_workspace_context"] = _workspace_context
	snapshot["global_transform"] = global_transform
	snapshot["material_selected"] = _get_shader_uniform(&"is_selected")
	snapshot["material_selectable"] = _get_shader_uniform(&"is_selectable")
	snapshot["_motor_id"] = _motor_id
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_workspace_context = in_snapshot["_workspace_context"]
	global_transform = in_snapshot["global_transform"]
	_motor_id = in_snapshot["_motor_id"]
	var motor: NanoVirtualMotor = _workspace_context.workspace.get_structure_by_int_guid(_motor_id) as NanoVirtualMotor
	self.visible = motor.get_visible()
	parameters = motor.get_parameters()
	_set_shader_uniform(&"is_selected", in_snapshot["material_selected"])
	_refresh_selection_preview(in_snapshot["material_selected"])
	_set_shader_uniform(&"is_selectable", in_snapshot["material_selectable"])
	_update_type_and_polarity()

