class_name CylinderStickMaterial extends StructureRepresentationMaterial

const INSTANCE_UNIFORM_BASE_SCALE: StringName = &"base_scale"
const UNIFORM_ATOM_SCALE: StringName = &"atom_scale"
const UNIFORM_GIZMO_ORIGIN = &"gizmo_origin"
const UNIFORM_GIZMO_ROTATION = &"gizmo_rotation"
const UNIFORM_SELECTION_DELTA = &"selection_delta"
const UNIFORM_OUTLINE_THICKNESS = &"outline_thickness"
const UNIFORM_IS_HOVERED = &"is_hovered"
const UNIFORM_SATURATION = &"saturation"
const UNIFORM_VALUE = &"value_correction"

const LOW_SATURATION = 0.5;
const NORMAL_SATURATION = 1.0;
const LOW_VALUE = 0.4;
const NORMAL_VALUE = 1.0;


func _init() -> void:
	RenderingUtils.has_uniforms(self, [UNIFORM_ATOM_SCALE, UNIFORM_SHOW_HYDROGENS, UNIFORM_IS_SELECTABLE,
			UNIFORM_GIZMO_ROTATION, UNIFORM_GIZMO_ORIGIN,UNIFORM_OUTLINE_THICKNESS, UNIFORM_IS_HOVERED,
			UNIFORM_SATURATION])


func set_atom_scale(new_scale: float) -> CylinderStickMaterial:
	set_shader_parameter(UNIFORM_ATOM_SCALE, new_scale)
	return self


func set_selectable(in_is_selectable: bool) -> CylinderStickMaterial:
	const SELECTABLE = 1.0
	const NON_SELECTABLE = 1.0
	var value_to_apply: float = SELECTABLE if in_is_selectable else NON_SELECTABLE
	set_shader_parameter(UNIFORM_IS_SELECTABLE, value_to_apply)
	return self


func set_hovered(in_is_hovered: bool) -> CylinderStickMaterial:
	const HOVERED_VALUE = 1.0
	const NON_HOVERED_VALUE = 0.0
	var value_to_apply: float = HOVERED_VALUE if in_is_hovered else NON_HOVERED_VALUE
	set_shader_parameter(UNIFORM_IS_HOVERED, value_to_apply)
	return self


func set_gizmo_origin(in_origin_position: Vector3) -> CylinderStickMaterial:
	set_shader_parameter(UNIFORM_GIZMO_ORIGIN, in_origin_position)
	return self


func set_gizmo_rotation(in_gizmo_rotation: Basis) -> CylinderStickMaterial:
	set_shader_parameter(UNIFORM_GIZMO_ROTATION, in_gizmo_rotation)
	return self;


func set_selection_delta(in_selection_delta: Vector3) -> CylinderStickMaterial:
	set_shader_parameter(UNIFORM_SELECTION_DELTA, in_selection_delta)
	return self


func desaturate() -> void:
	set_shader_parameter(UNIFORM_SATURATION, LOW_SATURATION)
	set_shader_parameter(UNIFORM_VALUE, LOW_VALUE)


func saturate() -> void:
	set_shader_parameter(UNIFORM_SATURATION, NORMAL_SATURATION)
	set_shader_parameter(UNIFORM_VALUE, NORMAL_VALUE)


func copy_state_from(in_from_material: ShaderMaterial) -> void:
	RenderingUtils.copy_selected_uniforms_from(in_from_material, self, [UNIFORM_ATOM_SCALE,
			UNIFORM_GIZMO_ORIGIN, UNIFORM_GIZMO_ROTATION, UNIFORM_SELECTION_DELTA,
			UNIFORM_OUTLINE_THICKNESS])


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.create_state_snapshot()
	snapshot[UNIFORM_SATURATION] = get_shader_parameter(UNIFORM_SATURATION)
	snapshot[UNIFORM_VALUE] = get_shader_parameter(UNIFORM_VALUE)
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_snapshot)
	set_shader_parameter(UNIFORM_SATURATION, in_snapshot[UNIFORM_SATURATION])
	set_shader_parameter(UNIFORM_VALUE, in_snapshot[UNIFORM_VALUE])
	
