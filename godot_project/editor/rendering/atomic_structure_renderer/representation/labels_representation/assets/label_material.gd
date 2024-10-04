class_name LabelMaterial extends StructureRepresentationMaterial


const UNIFORM_CAMERA_FORWARD_VECTOR := &"camera_forward_vector"
const UNIFORM_CAMERA_UP_VECTOR := &"camera_up_vector"
const UNIFORM_CAMERA_RIGHT_VECTOR := &"camera_right_vector"
const UNIFORM_CAMERA_SIZE := &"camera_size"
const UNIFORM_SCALE := &"scale"
const UNIFORM_GIZMO_ORIGIN = &"gizmo_origin"
const UNIFORM_GIZMO_ROTATION = &"gizmo_rotation"
const UNIFORM_SELECTION_DELTA = &"selection_delta"


func _init() -> void:
	RenderingUtils.has_uniforms(self, [UNIFORM_CAMERA_UP_VECTOR, UNIFORM_CAMERA_RIGHT_VECTOR,
			UNIFORM_SHOW_HYDROGENS, UNIFORM_SCALE, UNIFORM_GIZMO_ORIGIN, UNIFORM_GIZMO_ROTATION,
			UNIFORM_SELECTION_DELTA])


func set_selectable(in_is_selectable: bool) -> LabelMaterial:
	const SELECTABLE = 1.0
	const NON_SELECTABLE = 1.0
	var value_to_apply: float = SELECTABLE if in_is_selectable else NON_SELECTABLE
	set_shader_parameter(UNIFORM_IS_SELECTABLE, value_to_apply)
	return self


func set_scale_factor(new_scale_factor: float) -> LabelMaterial:
	set_shader_parameter(UNIFORM_SCALE, new_scale_factor)
	return self


func update_camera(in_camera_forward_vector: Vector3, in_camera_up_vector: Vector3,
			in_camera_right_vector: Vector3, in_camera_size: float) -> LabelMaterial:
	set_shader_parameter(UNIFORM_CAMERA_FORWARD_VECTOR, in_camera_forward_vector)
	set_shader_parameter(UNIFORM_CAMERA_UP_VECTOR, in_camera_up_vector)
	set_shader_parameter(UNIFORM_CAMERA_RIGHT_VECTOR, in_camera_right_vector)
	set_shader_parameter(UNIFORM_CAMERA_SIZE, in_camera_size)
	return self


func update_gizmo(in_gizmo_origin: Vector3, in_gizmo_rotation: Basis) -> void:
	set_shader_parameter(UNIFORM_GIZMO_ORIGIN, in_gizmo_origin)
	set_shader_parameter(UNIFORM_GIZMO_ROTATION, in_gizmo_rotation)


func update_selection_delta(in_selection_movement_delta: Vector3) -> void:
	set_shader_parameter(UNIFORM_SELECTION_DELTA, in_selection_movement_delta)


func copy_state_from(in_from_material: ShaderMaterial) -> void:
	RenderingUtils.copy_selected_uniforms_from(in_from_material, self, [UNIFORM_CAMERA_UP_VECTOR, 
			UNIFORM_CAMERA_RIGHT_VECTOR, UNIFORM_SHOW_HYDROGENS, UNIFORM_SCALE, UNIFORM_GIZMO_ORIGIN, 
			UNIFORM_GIZMO_ROTATION, UNIFORM_SELECTION_DELTA])
