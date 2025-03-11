class_name SphereMaterial extends StructureRepresentationMaterial

const UNIFORM_SCALE := &"scale"
const UNIFORM_IS_HOVERED := &"is_hovered"
const UNIFORM_OUTLINE_THICKNESS = &"outline_thickness"
const UNIFORM_GIZMO_ORIGIN = &"gizmo_origin"
const UNIFORM_GIZMO_ROTATION = &"gizmo_rotation"
const UNIFORM_SELECTION_DELTA = &"selection_delta"
const UNIFORM_SATURATION = &"saturation"
const UNIFORM_VALUE = &"value_correction"

const LOW_SATURATION = 0.5;
const NORMAL_SATURATION = 1.0;
const LOW_VALUE = 0.4;
const NORMAL_VALUE = 1.0;


func _init() -> void:
	RenderingUtils.has_uniforms(self, [UNIFORM_SCALE, UNIFORM_IS_SELECTABLE, UNIFORM_IS_HOVERED, UNIFORM_SHOW_HYDROGENS,
			UNIFORM_GIZMO_ORIGIN, UNIFORM_GIZMO_ROTATION, UNIFORM_SELECTION_DELTA, UNIFORM_OUTLINE_THICKNESS,
			UNIFORM_SATURATION, UNIFORM_VALUE])


func set_selectable(in_is_selectable: bool) -> SphereMaterial:
	const SELECTABLE = 1.0
	const NON_SELECTABLE = 1.0
	var value_to_apply: float = SELECTABLE if in_is_selectable else NON_SELECTABLE
	set_shader_parameter(UNIFORM_IS_SELECTABLE, value_to_apply)
	return self


func set_hovered(in_is_hovered: bool) -> SphereMaterial:
	const HOVERED_VALUE = 1.0
	const NON_HOVERED_VALUE = 0.0
	var value_to_apply: float = HOVERED_VALUE if in_is_hovered else NON_HOVERED_VALUE
	set_shader_parameter(UNIFORM_IS_HOVERED, value_to_apply)
	return self


func set_scale_factor(new_scale_factor: float) -> SphereMaterial:
	set_shader_parameter(UNIFORM_SCALE, new_scale_factor)
	return self


func update_gizmo(in_gizmo_origin: Vector3, in_gizmo_rotation: Basis) -> void:
	set_shader_parameter(UNIFORM_GIZMO_ORIGIN, in_gizmo_origin)
	set_shader_parameter(UNIFORM_GIZMO_ROTATION, in_gizmo_rotation)


func update_selection_delta(in_selection_movement_delta: Vector3) -> void:
	set_shader_parameter(UNIFORM_SELECTION_DELTA, in_selection_movement_delta)


func desaturate() -> void:
	set_shader_parameter(UNIFORM_SATURATION, LOW_SATURATION)
	set_shader_parameter(UNIFORM_VALUE, LOW_VALUE)


func saturate() -> void:
	set_shader_parameter(UNIFORM_SATURATION, NORMAL_SATURATION)
	set_shader_parameter(UNIFORM_VALUE, NORMAL_VALUE)


func reset() -> void:
	set_shader_parameter(UNIFORM_GIZMO_ROTATION, Basis())
	set_shader_parameter(UNIFORM_GIZMO_ORIGIN, Vector3())


func copy_state_from(in_from_material: ShaderMaterial) -> void:
	RenderingUtils.copy_selected_uniforms_from(in_from_material, self, [UNIFORM_SCALE, UNIFORM_IS_HOVERED,
			 UNIFORM_GIZMO_ORIGIN, UNIFORM_GIZMO_ROTATION, UNIFORM_SELECTION_DELTA])
